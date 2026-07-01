{ pkgs, ... }:

let
  # --- Sistem servisi: sysfs brightness (root) ---
  # ACAD = AC adapter cihazı; BAT: %40, AC: %80
  powerDisplayScript = pkgs.writeShellScript "power-display" ''
    BL=/sys/class/backlight/amdgpu_bl1
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)
    MAX=$(cat "$BL/max_brightness")

    if [ "$AC" = "0" ]; then
      echo $((MAX * 40 / 100)) > "$BL/brightness"
    else
      echo $((MAX * 80 / 100)) > "$BL/brightness"
    fi

    # Kullanıcı oturumu varsa Hyprland refresh rate servisini tetikle
    systemctl --user -M zixar@.host start power-display-user.service 2>/dev/null || true
  '';

  # --- Kullanıcı servisi: Hyprland refresh rate ---
  # Phase 4'e kadar no-op; Hyprland kurulunca otomatik devreye girer.
  powerDisplayUserScript = pkgs.writeShellScript "power-display-user" ''
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)

    # Hyprland çalışmıyorsa sessizce çık
    HYPR_SIG=$(ls "$XDG_RUNTIME_DIR/hypr/" 2>/dev/null | head -1)
    [ -z "$HYPR_SIG" ] && exit 0

    # hyprctl'ı nix profil + sistem yollarında ara
    HYPRCTL=$(command -v hyprctl \
              || ls /etc/profiles/per-user/zixar/bin/hyprctl \
              || ls /run/current-system/sw/bin/hyprctl \
              2>/dev/null | head -1)
    [ -z "$HYPRCTL" ] && exit 0

    export HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG"

    if [ "$AC" = "0" ]; then
      "$HYPRCTL" keyword monitor "eDP-1,2560x1600@60,0x0,1"
    else
      "$HYPRCTL" keyword monitor "eDP-1,2560x1600@165,0x0,1"
    fi
  '';
in
{
  # TLP — AC/BAT-aware pil yöneticisi; power-profiles-daemon ile çakışır
  services.power-profiles-daemon.enable = false;

  services.tlp = {
    enable = true;
    settings = {
      # --- CPU (AMD amd-pstate=active + EPP hintleri) ---
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

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

  # udev: AC adaptör bağlantısı değişince sistem servisini tetikle
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", \
      RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-display.service"
  '';

  # Sistem servisi — sysfs backlight yazar (root, compositor bağımsız)
  systemd.services.power-display = {
    description = "AC/BAT display brightness adaptation";
    serviceConfig = {
      Type        = "oneshot";
      ExecStart   = powerDisplayScript;
    };
  };

  # Kullanıcı servisi — Hyprland refresh rate (Phase 4'ten itibaren aktif)
  systemd.user.services.power-display-user = {
    description = "AC/BAT Hyprland refresh rate adaptation";
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayUserScript;
    };
  };
}
