{ config, pkgs, lib, inputs, ... }:

let
  # CPU cores for gaming (Zen 5 performance cores)
  gamingCores = "0-3,8-11";
  
  # Gaming performance script
  gamingPerf = pkgs.writeShellScriptBin "gaming-perf" ''
    #!${pkgs.runtimeShell}
    
    ACTION="$1"
    
    case "$ACTION" in
      on|start|enable)
        echo "🎮 Enabling gaming performance mode..."
        
        # CPU governor
        echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
        
        # Disable CPU boost limit
        echo 0 | tee /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
        
        # GPU performance
        echo high | tee /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null || true
        
        # NVIDIA settings
        if command -v nvidia-settings &> /dev/null; then
          nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" 2>/dev/null || true
          nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=200" 2>/dev/null || true
          nvidia-settings -a "[gpu:0]/GPUMemoryTransferRateOffset[3]=500" 2>/dev/null || true
        fi
        
        # Disable NMI watchdog
        echo 0 | tee /proc/sys/kernel/nmi_watchdog
        
        # Reduce swappiness
        echo 10 | tee /proc/sys/vm/swappiness
        
        # Disable transparent hugepages compaction
        echo never | tee /sys/kernel/mm/transparent_hugepage/defrag
        
        # IRQ affinity (move to efficiency cores)
        for irq in /proc/irq/*/smp_affinity; do
          echo f0f0 | tee "$irq" 2>/dev/null || true
        done
        
        # Notify
        ${pkgs.libnotify}/bin/notify-send -i applications-games "Gaming Mode" "Performance mode enabled" -t 2000
        echo "✅ Gaming mode enabled"
        ;;
        
      off|stop|disable)
        echo "🛑 Disabling gaming performance mode..."
        
        # Restore CPU governor
        echo schedutil | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
        
        # Restore GPU
        echo auto | tee /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null || true
        
        # Restore NVIDIA
        if command -v nvidia-settings &> /dev/null; then
          nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=0" 2>/dev/null || true
          nvidia-settings -a "[gpu:0]/GPUGraphicsClockOffset[3]=0" 2>/dev/null || true
          nvidia-settings -a "[gpu:0]/GPUMemoryTransferRateOffset[3]=0" 2>/dev/null || true
        fi
        
        # Restore watchdog
        echo 1 | tee /proc/sys/kernel/nmi_watchdog
        
        # Restore swappiness
        echo 60 | tee /proc/sys/vm/swappiness
        
        # Restore hugepages
        echo madvise | tee /sys/kernel/mm/transparent_hugepage/defrag
        
        # Notify
        ${pkgs.libnotify}/bin/notify-send -i applications-games "Gaming Mode" "Performance mode disabled" -t 2000
        echo "✅ Gaming mode disabled"
        ;;
        
      status)
        echo "=== Gaming Mode Status ==="
        echo "CPU Governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
        echo "NMI Watchdog: $(cat /proc/sys/kernel/nmi_watchdog)"
        echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
        if [ -f /sys/class/drm/card0/device/power_dpm_force_performance_level ]; then
          echo "GPU Performance: $(cat /sys/class/drm/card0/device/power_dpm_force_performance_level)"
        fi
        ;;
        
      *)
        echo "Usage: gaming-perf [on|off|status]"
        exit 1
        ;;
    esac
  '';

  # Game launcher with optimizations
  gameLaunch = pkgs.writeShellScriptBin "game-launch" ''
    #!${pkgs.runtimeShell}
    
    GAME="$1"
    shift
    
    # Enable performance mode
    gaming-perf on 2>/dev/null || true
    
    # Launch with optimizations
    export DXVK_HUD=0
    export DXVK_ASYNC=1
    export MANGOHUD=1
    export ENABLE_VKBASALT=1
    export PROTON_USE_WINED3D=0
    export PROTON_NO_ESYNC=0
    export PROTON_NO_FSYNC=0
    export PROTON_ENABLE_NVAPI=1
    
    # CPU affinity to performance cores
    exec taskset -c ${gamingCores} gamemoderun "$GAME" "$@"
  '';

in
{
  # =============================================================================
  # GAMING PACKAGES
  # =============================================================================
  
  environment.systemPackages = with pkgs; [
    # Gaming platforms
    steam
    lutris
    heroic
    bottles
    
    # Proton/Compatibility
    protonup-qt
    protontricks
    winetricks
    
    # Performance tools
    mangohud          # Performance overlay
    goverlay          # Mangohud configurator
    vkbasalt          # Post-processing
    libstrangle       # FPS limiter
    
    # Custom scripts
    gamingPerf
    gameLaunch
    
    # Monitoring
   # nvtop             # GPU monitor
    radeontop         # AMD GPU monitor
    
    # Utilities
    gamescope         # Micro-compositor
    gamemode          # Performance daemon
    
    
    # Anti-cheat support
    # Already handled by NixOS steam module
  ] ++ lib.optionals (pkgs.stdenv.isx86_64) [
    # x86_64 specific
  ];

  # =============================================================================
  # STEAM CONFIGURATION
  # =============================================================================
  
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    
    # ProtonGE support
    protontricks.enable = true;
    
    # Extra packages for Steam environment
    extraPackages = with pkgs; [
      gamemode
      mangohud
      vkbasalt
    ];
    
};
  # =============================================================================
  # GAMEMODE - Performance daemon
  # =============================================================================
  
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        screensaver_inhibit = true;
        defaultgov = "performance";
        desiredgov = "performance";
      };
      
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
        nv_powermizer_mode = 1;
      };
      
      cpu = {
        pin_cores = "no";  # Let scheduler handle heterogeneous cores
      };
      
    };
  };

  # =============================================================================
  # GAMESCOPE - SteamOS compositor
  # =============================================================================
  
  programs.gamescope = {
    enable = true;
    args = [
      "--rt"
      "--prefer-vk-device"
      "--adaptive-sync"
    ];
    env = {
      DXVK_ASYNC = "1";
      MANGOHUD = "1";
    };
  };

  # =============================================================================
  # MANGOHUD - Performance overlay
  # =============================================================================
  
  environment.etc."MangoHud/MangoHud.conf".text = ''
    # Position
    position=top-left
    
    # Metrics
    fps
    frametime
    cpu_stats
    cpu_temp
    cpu_power
    gpu_stats
    gpu_temp
    gpu_power
    vram
    ram
    battery
    
    # Display
    font_size=18
    background_alpha=0.3
    toggle_hud=Shift_R+F12
    
    # Logging
    log_duration=30
    autostart_log=0
    
    # Extras
    show_fps_limit
    resolution
    vulkan_driver
    wine
    arch
    
    # Color scheme
    text_color=FFFFFF
    gpu_color=2E9762
    cpu_color=2E97CB
    vram_color=AD64C1
    ram_color=C26693
    engine_color=EB5B5B
  '';

  # =============================================================================
  # CONTROLLER SUPPORT
  # =============================================================================
  
  services.udev.packages = with pkgs; [
    game-devices-udev-rules
    steam-devices-udev-rules
  ];

  # =============================================================================
  # KERNEL MODULES FOR GAMING
  # =============================================================================
  
  boot.kernelModules = [
    "uinput"            # Controller input
    "joydev"            # Joystick
    "evdev"             # Event device
  ];

  # =============================================================================
  # SYSTEMD SERVICES
  # =============================================================================
  
  # Gaming performance service
  systemd.services.gaming-performance = {
    description = "Gaming Performance Mode";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${gamingPerf}/bin/gaming-perf on";
      ExecStop = "${gamingPerf}/bin/gaming-perf off";
    };
  };

  # =============================================================================
  # SHELL ALIASES
  # =============================================================================
  
  environment.shellAliases = {
    "gaming-on" = "gaming-perf on";
    "gaming-off" = "gaming-perf off";
    "gaming-status" = "gaming-perf status";
    "steam-opt" = "gamemoderun steam";
    "mango" = "mangohud --dlsym";
  };

  # =============================================================================
  # DOCUMENTATION
  # =============================================================================
  
  environment.etc."gaming/README.md".text = ''
    # Gaming Configuration
    
    ## Quick Start
    
    ### Launch Games with Optimizations
    ```bash
    # Using gamemode (recommended)
    gamemoderun ./game
    
    # Using game-launch wrapper
    game-launch ./game
    
    # Steam with optimizations
    steam-opt
    ```
    
    ### Performance Mode
    ```bash
    gaming-perf on      # Enable performance mode
    gaming-perf off     # Disable performance mode
    gaming-perf status  # Check status
    ```
    
    ## Tools
    
    ### Mangohud
    - Toggle: `Shift_R + F12`
    - Config: `/etc/MangoHud/MangoHud.conf`
    
    ### Gamescope
    ```bash
    gamescope -W 1920 -H 1080 -r 144 -- ./game
    ```
    
    ### ProtonGE
    ```bash
    protonup-qt  # GUI installer
    protontricks  # Winetricks for Proton
    ```
    
    ## Controller Support
    - Xbox controllers: Plug and play
    - DualSense: Full support with haptics
    - Steam Input: Available in Steam
    
    ## Troubleshooting
    
    ### Performance Issues
    1. Check CPU affinity: `taskset -pc $$`
    2. Monitor resources: `nvtop`, `btop`
    3. Check thermals: `sensors`
    
    ### Controller Not Working
    ```bash
    # Check detection
    evtest
    
    # Check permissions
    ls -la /dev/input/js*
    ```
    
    ### Game Won't Launch
    1. Try different Proton version
    2. Check ProtonDB for compatibility
    3. Use `protontricks` for dependencies
  '';

  # =============================================================================
  # NOTES
  # =============================================================================
  
  # For best gaming performance:
  # 1. Use gamemoderun for all games
  # 2. Enable MangoHud for monitoring
  # 3. Use Gamescope for problematic games
  # 4. Check ProtonDB for compatibility tips
}
