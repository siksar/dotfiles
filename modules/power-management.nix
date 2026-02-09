{ config, pkgs, lib, ... }:
{
  # ========================================================================
  # LAPTOP POWER MANAGEMENT & UNDERVOLT TOOLS
  # Gigabyte Aero X16 1VH (AMD Ryzen + NVIDIA) için optimize edilmiş
  # ========================================================================

  environment.systemPackages = with pkgs; [
    # ─────────────────────────────────────────────────────────────────────
    # AMD RYZEN SPECIFIC TOOLS
    # ─────────────────────────────────────────────────────────────────────
    
    # RyzenAdj - AMD Ryzen mobile processor tuning (TDP, power limits, temps)
    # BIOS'a erişim olmadan undervolt ve TDP ayarı yapabilirsiniz
    ryzenadj
    
    # System76 Power - Alternative power management
    system76-power
    
    # ─────────────────────────────────────────────────────────────────────
    # GENERAL POWER MANAGEMENT
    # ─────────────────────────────────────────────────────────────────────
    
    # PowerTop - Intel/AMD power consumption analyzer
    powertop
    
    # auto-cpufreq - Automatic CPU power management for laptops
    # auto-cpufreq
    
    # s-tui - Terminal UI for monitoring CPU temp, freq, power
    s-tui
    
    # stress-ng - CPU stress testing (s-tui ile birlikte kullanılır)
    stress-ng
    
    # cpupower - CPU frequency scaling utilities
    linuxPackages_latest.cpupower
    
    # ─────────────────────────────────────────────────────────────────────
    # GPU & DISPLAY CONTROL
    # ─────────────────────────────────────────────────────────────────────
    
    # EnvyControl not in nixpkgs - install via pip if needed: pip install envycontrol
    # Alternative: use nvidia-offload wrapper or prime-run
    
    # glxinfo/glxgears - OpenGL testing (part of mesa-demos)
    mesa-demos
    
    # nvtop full - GPU monitoring (RTX 5060 support)
    nvtopPackages.full
    
    # Nvidia GPU Tools
    gwe # GreenWithEnvy - NOTE: X11 only, Wayland'da çalışmaz
    
    # LACT - Linux AMDGPU Controller (Wayland destekli, AMD+NVIDIA)
    lact
    
    # ─────────────────────────────────────────────────────────────────────
    # FAN & PERIPHERAL CONTROL
    # ─────────────────────────────────────────────────────────────────────
    
    # NBFC-Linux - Notebook Fan Control (Gigabyte profiles)
    nbfc-linux
    
    # OpenRGB - Keyboard and system RGB lighting control
    openrgb
    
    # ─────────────────────────────────────────────────────────────────────
    # THERMAL MANAGEMENT
    # ─────────────────────────────────────────────────────────────────────
    
    # lm_sensors - Hardware monitoring (fan speed, temps, voltages)
    lm_sensors
    
    # acpi - Battery and thermal info
    acpi
    
    # thermald - Thermal daemon (Intel/AMD thermal management)
    thermald
    
    # ─────────────────────────────────────────────────────────────────────
    # LAPTOP SPECIFIC
    # ─────────────────────────────────────────────────────────────────────
    
    # brightnessctl - Display brightness control
    brightnessctl
    
    # light - Alternative brightness controller
    light
    
    # acpilight - xbacklight replacement using ACPI
    acpilight
    
    # ─────────────────────────────────────────────────────────────────────
    # SYSTEM MONITORING & HARDWARE UTILS
    # ─────────────────────────────────────────────────────────────────────
    
    # btop - Modern resource monitor
    btop
    
    # iotop - I/O monitoring
    iotop
    
    # perf - Linux performance tools
    linuxPackages_latest.perf
    
    # pciutils - lspci command for hardware inspection
    pciutils
    
    # usbutils - lsusb command for USB device inspection
    usbutils
    
    # ─────────────────────────────────────────────────────────────────────
    # BIOS/FIRMWARE TOOLS
    # ─────────────────────────────────────────────────────────────────────
    
    # fwupd - Firmware updates via Linux (LVFS)
    fwupd
    
    # efibootmgr - EFI boot manager
    efibootmgr
    
    (pkgs.writeShellScriptBin "power-control" ''
      #!/usr/bin/env bash

      # Power Control Script - 30W Optimized Edition
      # Optimized for: Gigabyte Aero X16 (Ryzen + RTX) locked at 30W
      
      export DISPLAY=:0
      export XAUTHORITY=/home/zixar/.Xauthority

      check_root() {
          if [ "$EUID" -ne 0 ]; then
              echo "Please run as root"
              exit 1
          fi
      }

      get_power_source() {
          for ps in /sys/class/power_supply/*; do
              if [ -f "$ps/type" ] && [ "$(cat "$ps/type")" = "Mains" ]; then
                  if [ "$(cat "$ps/online")" = "1" ]; then
                      echo "AC"
                      return
                  fi
              fi
          done
          echo "BAT"
      }

      set_profile() {
          if command -v powerprofilesctl &> /dev/null; then
              powerprofilesctl set "$1" || true
          elif [ -f /sys/firmware/acpi/platform_profile ]; then
              echo "$1" > /sys/firmware/acpi/platform_profile || true
          fi
      }

      set_epp() {
          if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
              echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
          fi
      }

      apply_gpu_clocks() {
          CORE=$1
          MEM=$2
          echo "Applying GPU Clocks: Core +$CORE MHz, Mem +$MEM MHz..."
          if command -v nvidia-settings &> /dev/null; then
             # Try forcing performance level 3 (max 3D) and setting offsets
             nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=$CORE" \
                             -a "[gpu:0]/GPUMemoryTransferRateOffset[3]=$MEM" || echo "Failed to apply GPU clocks via nvidia-settings"
          else
             echo "nvidia-settings not found, skipping clocks."
          fi
      }

      # 30W OPTIMIZED MODES
      # Constraint: GPU is locked at ~30W by firmware/hardware.
      # Strategy: Maximize Frequency at that 30W limit (Undervolt/Overclock).

      apply_gaming() {
          echo "Applying GAMING mode (30W Optimized)..."
          set_profile "performance"
          set_epp "performance"
          
          # GPU: 30W Limit, Moderate OC
          nvidia-smi -pl 30
          # +100 Core, +300 Memory - Safe boost
          apply_gpu_clocks 100 300
          
          # CPU: High Performance
          # Lower tctl slightly to keep heat down since GPU fan curve might be linked
          ryzenadj --stapm-limit=45000 --fast-limit=50000 --slow-limit=45000 --tctl-temp=85
          # AMD P-State active mode prefers 'powersave' governor with 'performance' EPP
          cpupower frequency-set -g powersave
      }

      apply_turbo() {
          echo "Applying TURBO mode (30W Aggressive)..."
          set_profile "performance"
          set_epp "performance"
          
          # GPU: 30W Limit, High OC
          nvidia-smi -pl 30
          # +150 Core, +600 Memory - Aggressive
          apply_gpu_clocks 150 600
          
          # CPU: Max Performance within reasonable thermals
          ryzenadj --stapm-limit=55000 --fast-limit=65000 --slow-limit=55000 --tctl-temp=90
          cpupower frequency-set -g powersave
      }

      apply_extreme() {
          echo "Applying EXTREME mode (30W Max Limits)..."
          set_profile "performance"
          set_epp "performance"
          
          # GPU: 30W Limit, Very High OC
          nvidia-smi -pl 30
          # +200 Core, +1000 Memory - Pushing silicon limits at low voltage
          apply_gpu_clocks 200 1000
          
          # CPU: Max Performance
          ryzenadj --stapm-limit=65000 --fast-limit=75000 --slow-limit=65000 --tctl-temp=95
          cpupower frequency-set -g powersave
      }

      apply_normal() {
          echo "Applying NORMAL mode..."
          set_profile "balanced"
          set_epp "balance_performance"
          
          # GPU: 30W, Stock Clocks
          nvidia-smi -pl 30
          apply_gpu_clocks 0 0
          
          # CPU: Balanced
          ryzenadj --stapm-limit=35000 --fast-limit=40000 --slow-limit=35000 --tctl-temp=85
          cpupower frequency-set -g powersave
      }

      apply_saver() {
          echo "Applying SAVER mode..."
          set_profile "power-saver"
          set_epp "power"
          
          # GPU: Min Power (likely <30W if possible, else 30W)
          nvidia-smi -pl 25 || nvidia-smi -pl 30
          apply_gpu_clocks 0 0
          
          # CPU: Power Save
          ryzenadj --stapm-limit=15000 --fast-limit=20000 --slow-limit=15000 --tctl-temp=75
          cpupower frequency-set -g powersave
      }

      check_root
      MODE=$1
      case "$MODE" in
          "gaming") apply_gaming ;;
          "turbo") apply_turbo ;;
          "extreme") apply_extreme ;;
          "normal") apply_normal ;;
          "saver"|"tasarruf") apply_saver ;;
          "auto")
              if [ "$(get_power_source)" = "AC" ]; then apply_normal; else apply_saver; fi
              ;;
          *)
              echo "Usage: $0 {gaming|turbo|extreme|normal|saver|auto}"
              exit 1
              ;;
      esac
    '')
    
    # Ultra düşük güç modu - idle için
    (pkgs.writeShellScriptBin "idle-optimize" ''
      #!/usr/bin/env bash
      # Idle Power Optimization Script
      # Ultra düşük güç tüketimi ve sıcaklık için
      
      check_root() {
          if [ "$EUID" -ne 0 ]; then
              echo "Please run as root: sudo idle-optimize"
              exit 1
          fi
      }
      
      apply_idle() {
          echo "Applying IDLE optimization mode..."
          
          # CPU: Ultra düşük güç
          ryzenadj --stapm-limit=6000 --fast-limit=8000 --slow-limit=6000 --tctl-temp=65 2>/dev/null || echo "ryzenadj not available"
          
          # Frekans sınırla
          cpupower frequency-set --max 2000MHz 2>/dev/null || echo "cpupower not available"
          
          # EPP ayarla
          if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
              echo "power" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
          fi
          
          # Platform profile
          if [ -f /sys/firmware/acpi/platform_profile ]; then
              echo "low-power" > /sys/firmware/acpi/platform_profile || true
          fi
          
          echo "✓ Idle optimization applied"
          echo "  CPU limit: 6W STAPM, 8W Fast"
          echo "  Max freq: 2000MHz"
          echo "  EPP: power"
      }
      
      restore_normal() {
          echo "Restoring NORMAL mode..."
          
          ryzenadj --stapm-limit=35000 --fast-limit=40000 --slow-limit=35000 --tctl-temp=85 2>/dev/null || echo "ryzenadj not available"
          cpupower frequency-set --max 5000MHz 2>/dev/null || echo "cpupower not available"
          
          if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
              echo "balance_performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference > /dev/null
          fi
          
          if [ -f /sys/firmware/acpi/platform_profile ]; then
              echo "balanced" > /sys/firmware/acpi/platform_profile || true
          fi
          
          echo "✓ Normal mode restored"
      }
      
      check_root
      case "$1" in
          "on"|"idle") apply_idle ;;
          "off"|"normal") restore_normal ;;
          *)
              echo "Usage: sudo idle-optimize {on|off}"
              echo "  on/idle  - Ultra low power mode (6W)"
              echo "  off/normal - Restore normal operation"
              ;;
      esac
    '')
  ];

  # ========================================================================
  # NOTE: thermald.enable is also in cpu-scheduling.nix, using mkDefault to allow override
  services.thermald.enable = lib.mkDefault true;

  # ========================================================================
  # POWER PROFILES DAEMON
  # ========================================================================
  services.power-profiles-daemon.enable = false;
  # Accelerometer vb. sensörler

  # ========================================================================
  # UDEV RULES - RyzenAdj ve diğer araçlar için gerekli izinler
  # ========================================================================
  # ========================================================================
  # CUSTOM POWER CONTROL SCRIPT
  # ========================================================================

  # ========================================================================
  # UDEV RULES - Auto Power Switching
  # ========================================================================
  services.udev.extraRules = ''
    # RyzenAdj ...
    KERNEL=="msr", MODE="0660", GROUP="wheel"
    SUBSYSTEM=="cpu", MODE="0660", GROUP="wheel"

    # Auto Power Control on AC/Battery Switch
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.bash}/bin/bash /run/current-system/sw/bin/power-control saver"
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.bash}/bin/bash /run/current-system/sw/bin/power-control normal"
    
    # Backlight ...
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    
    # NVIDIA GPU ...
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
  '';

  # ========================================================================
  # SUDO RULES FOR POWER CONTROL
  # ========================================================================
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        { command = "/run/current-system/sw/bin/power-control"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.linuxPackages_latest.cpupower}/bin/cpupower"; options = [ "NOPASSWD" ]; }
        { command = "${pkgs.ryzenadj}/bin/ryzenadj"; options = [ "NOPASSWD" ]; }
        # Note: nvidia-smi might need to be explicitly added if not covered
      ];
    }
  ];

  # ========================================================================
  # LACT DAEMON SERVICE
  # ========================================================================
  systemd.services.lactd = {
    description = "AMDGPU Control Daemon";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      ExecStart = "${pkgs.lact}/bin/lact daemon";
    };
    enable = true;
  };
}
