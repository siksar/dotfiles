{ pkgs, ... }:

let
  # --- Sistem servisi: sysfs brightness + webcam (root) ---
  # ACAD = AC adapter cihazı; BAT: %40 parlaklık + webcam kapalı, AC: %80 + webcam açık
  powerDisplayScript = pkgs.writeShellScript "power-display" ''
    BL=/sys/class/backlight/amdgpu_bl1
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)
    MAX=$(cat "$BL/max_brightness")

    if [ "$AC" = "0" ]; then
      echo $((MAX * 40 / 100)) > "$BL/brightness"
      # Webcam pilde hard-off (autosuspend yetmez, enumerate bile olmasın)
      echo 0 > /sys/bus/usb/devices/1-1/authorized 2>/dev/null || true
    else
      echo $((MAX * 80 / 100)) > "$BL/brightness"
      echo 1 > /sys/bus/usb/devices/1-1/authorized 2>/dev/null || true
    fi

    # Kullanıcı oturumu varsa Hyprland adaptasyon servisini tetikle
    systemctl --user -M zixar@.host start power-display-user.service 2>/dev/null || true
  '';

  # --- Kullanıcı servisi: Hyprland refresh rate + pil render profili ---
  powerDisplayUserScript = pkgs.writeShellScript "power-display-user" ''
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)

    # Hyprland çalışmıyorsa sessizce çık
    HYPR_SIG=$(ls "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)
    [ -z "$HYPR_SIG" ] && exit 0

    HYPRCTL=$(command -v hyprctl \
              || ls /etc/profiles/per-user/zixar/bin/hyprctl \
                    /run/current-system/sw/bin/hyprctl \
              2>/dev/null | head -1)
    [ -z "$HYPRCTL" ] && exit 0

    export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"

    if [ "$AC" = "0" ]; then
      # Pil: 60Hz + render yükünü azalt + VRR kapalı (PSR çakışması) → residency artar
      "$HYPRCTL" --batch "\
        keyword monitor eDP-1,2560x1600@60,0x0,1 ; \
        keyword misc:vrr 0 ; \
        keyword decoration:blur:enabled false ; \
        keyword decoration:shadow:enabled false ; \
        keyword animations:enabled false"
    else
      # AC: 165Hz + tam görsel kalite + VRR yalnız tam ekran (oyun; panel 48-165Hz)
      "$HYPRCTL" --batch "\
        keyword monitor eDP-1,2560x1600@165,0x0,1 ; \
        keyword misc:vrr 2 ; \
        keyword decoration:blur:enabled true ; \
        keyword decoration:shadow:enabled true ; \
        keyword animations:enabled true"
    fi
  '';
in
{
  # TLP — AC/BAT-aware pil yöneticisi; power-profiles-daemon ile çakışır
  services.power-profiles-daemon.enable = false;

  # UPower — batarya telemetrisini D-Bus'a sunar (Caelestia bar/dashboard buradan okur)
  # TLP ile çakışmaz: sadece okuyucu; idle maliyeti ihmal edilebilir
  services.upower.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      # --- CPU (AMD amd-pstate=active + EPP hintleri) ---
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # --- CPU Boost (AMD Core Performance Boost) — pilde kapalı ---
      CPU_BOOST_ON_AC  = 1;
      CPU_BOOST_ON_BAT = 0;

      # --- Pilde frekans tavanı: tuş basımı spike'larını törpüler ---
      CPU_SCALING_MAX_FREQ_ON_BAT = 2000000;

      # --- iGPU DPM: pilde en düşük saat kademesine kilitle ---
      RADEON_DPM_PERF_LEVEL_ON_AC  = "auto";
      RADEON_DPM_PERF_LEVEL_ON_BAT = "low";

      # --- ACPI Platform Profili ---
      PLATFORM_PROFILE_ON_AC  = "performance";
      PLATFORM_PROFILE_ON_BAT = "low-power";

      # --- PCIe ASPM (kernel param pcie_aspm.policy=powersupersave ile tutarlı) ---
      PCIE_ASPM_ON_AC  = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";

      # --- PCI Runtime PM (dGPU RTX 5060 D3cold için kritik) ---
      RUNTIME_PM_ON_AC  = "on";
      RUNTIME_PM_ON_BAT = "auto";

      # --- WiFi (Realtek RTL8852CE — rtw89_core power_save=Y destekler) ---
      WIFI_PWR_ON_AC  = "off";
      WIFI_PWR_ON_BAT = "on";

      # --- USB Autosuspend (kamera dahil; telefon şarjı korunur) ---
      USB_AUTOSUSPEND     = 1;
      USB_BLACKLIST_PHONE = 1;

      # --- Bluetooth: pilde rfkill-block, AC'de aç ---
      DEVICES_TO_DISABLE_ON_BAT = "bluetooth";
      DEVICES_TO_ENABLE_ON_AC   = "bluetooth";
    };
  };

  # tlp-sleep.service yalnızca Before=sleep.target ile sıralı geliyor — bu da
  # systemd-suspend/hibernate ile PARALEL çalışabildiği anlamına geliyor.
  # `tlp suspend` bir PCI cihazının power/control sysfs yazısında kernel
  # mutex'inde bloke olabiliyor (task:tlp state:D, control_store), tam da
  # kernel freezer'ın userspace'i dondurmaya çalıştığı anda — freezer 20sn
  # bekleyip vazgeçiyor, 2 denemeden sonra suspend-then-hibernate tamamen
  # "Failed" oluyor (ölçüldü: journalctl, 2026-07-11/12, "refusing to freeze"
  # → task:tlp, 32/40 olay). Fix: tlp-sleep'i asıl uyku servislerinden KESİN
  # ÖNCE bitmeye zorla, race'i systemd ordering'de yok et.
  systemd.services.tlp-sleep.unitConfig.Before = [
    "systemd-suspend.service"
    "systemd-hibernate.service"
    "systemd-hybrid-sleep.service"
    "systemd-suspend-then-hibernate.service"
  ];

  # udev: AC adaptör bağlantısı değişince sistem servisini tetikle
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", \
      RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-display.service"
  '';

  # Sistem servisi — boot'ta VE udev'de koşar (pille boot edilirse de uygulanır)
  systemd.services.power-display = {
    description = "AC/BAT display brightness + webcam adaptation";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayScript;
    };
  };

  # Kullanıcı servisi — Hyprland oturumu açılınca otomatik koşar (UWSM graphical-session)
  systemd.user.services.power-display-user = {
    description = "AC/BAT Hyprland refresh rate + render profile adaptation";
    wantedBy = [ "graphical-session.target" ];
    after    = [ "graphical-session.target" ];
    partOf   = [ "graphical-session.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayUserScript;
    };
  };
}
