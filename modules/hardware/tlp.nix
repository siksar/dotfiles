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

    # Kullanıcı oturumu varsa GNOME adaptasyon servisini tetikle
    systemctl --user -M zixar@.host start power-display-user.service 2>/dev/null || true
  '';

  # --- Kullanıcı servisi: GNOME refresh rate + pil render profili ---
  # gnome-randr mutter'ın org.gnome.Mutter.DisplayConfig D-Bus API'sini kullanır;
  # oturum yoksa sorgu düşer, sessizce çıkılır. Gerçek mod adları (59.994 vb.)
  # panele göre değiştiğinden regex ile sorgu çıktısından seçilir.
  powerDisplayUserScript = pkgs.writeShellScript "power-display-user" ''
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)

    GR=${pkgs.gnome-randr}/bin/gnome-randr
    MODES=$("$GR" 2>/dev/null) || exit 0

    if [ "$AC" = "0" ]; then
      # Pil: 60Hz + animasyonlar kapalı → residency artar
      MODE=$(printf '%s\n' "$MODES" | grep -oE '2560x1600@(59|60)(\.[0-9]+)?' | head -1)
      ANIM=false
    else
      # AC: 165Hz + animasyonlar açık (VRR mutter experimental; yalnız tam ekran)
      MODE=$(printf '%s\n' "$MODES" | grep -oE '2560x1600@16[45](\.[0-9]+)?' | head -1)
      ANIM=true
    fi

    [ -n "$MODE" ] && "$GR" modify eDP-1 --mode "$MODE" || true
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface \
      enable-animations "$ANIM" 2>/dev/null || true
  '';
in
{
  # TLP — AC/BAT-aware pil yöneticisi; power-profiles-daemon ile çakışır
  services.power-profiles-daemon.enable = false;

  # UPower — batarya telemetrisini D-Bus'a sunar (GNOME kabuğu buradan okur)
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

  # Kullanıcı servisi — GNOME oturumu açılınca otomatik koşar (graphical-session.target)
  systemd.user.services.power-display-user = {
    description = "AC/BAT GNOME refresh rate + render profile adaptation";
    wantedBy = [ "graphical-session.target" ];
    after    = [ "graphical-session.target" ];
    partOf   = [ "graphical-session.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayUserScript;
    };
  };
}
