{ config, pkgs, lib, ... }:

let
  # Zen 5 (Performance cores) - CPU 0-3 (SMT: 8-11)
  # Zen 5c (Efficiency cores) - CPU 4-7 (SMT: 12-15)
  # Strix Point: 4x Zen5 + 4x Zen5c
  
  zen5Cores = "0-3,8-11";      # Performance cores
  zen5cCores = "4-7,12-15";    # Efficiency cores
  allCores = "0-15";           # All cores
  
  # Cgroup slice definitions
  highPerfSlice = "high-performance";
  backgroundSlice = "background";
  
  # Wrapper script for CPU affinity
  cpuAffinityWrapper = pkgs.writeShellScriptBin "with-cores" ''
    #!${pkgs.runtimeShell}
    usage() {
      echo "Usage: with-cores [perf|eff|all] <command> [args...]"
      echo "  perf - Use Zen 5 performance cores (0-3,8-11)"
      echo "  eff  - Use Zen 5c efficiency cores (4-7,12-15)"
      echo "  all  - Use all cores (0-15)"
      exit 1
    }
    
    [ $# -lt 2 ] && usage
    
    MODE="$1"
    shift
    
    case "$MODE" in
      perf)
        exec taskset -c ${zen5Cores} "$@"
        ;;
      eff)
        exec taskset -c ${zen5cCores} "$@"
        ;;
      all)
        exec taskset -c ${allCores} "$@"
        ;;
      *)
        usage
        ;;
    esac
  '';

  # Auto-cpufreq optimized config for Zen 5
  autoCpufreqConfig = pkgs.writeText "auto-cpufreq.conf" ''
    # Charger settings - Performance
    [charger]
    governor = performance
    energy_performance_preference = performance
    scaling_min_freq = 800000
    scaling_max_freq = 5100000
    turbo = auto
    
    # Battery settings - Power save
    [battery]
    governor = powersave
    energy_performance_preference = power
    scaling_min_freq = 400000
    scaling_max_freq = 2000000
    turbo = auto
    
    # Enable thresholds for battery health
    [battery]
    enable_thresholds = true
    start_threshold = 40
    stop_threshold = 80
  '';

in
{
  # =============================================================================
  # CPU SCHEDULING - Zen 5 / Zen 5c Core Management
  # =============================================================================
  
  # Install required packages
  environment.systemPackages = with pkgs; [
    cpuAffinityWrapper
    schedtool        # Scheduler control
    cpuset           # CPU set management
    linuxKernel.packages.linux_latest_libre.cpupower  # CPU power management
    powerstat        # Power consumption monitoring
    s-tui            # Stress test + monitoring
    stress-ng        # CPU stress testing
  ];

  # =============================================================================
  # SYSTEMD SLICES - Cgroup-based CPU Management
  # =============================================================================
  
  # High Performance Slice (Zen 5 cores only)
  systemd.slices.${highPerfSlice} = {
    description = "High Performance Applications (Zen 5 cores)";
    sliceConfig = {
      # CPU affinity to Zen 5 cores only
      AllowedCPUs = zen5Cores;
      # Higher CPU weight for priority
      CPUWeight = 900;
      # Memory priority
      MemoryWeight = 900;
      # IO priority
      IOWeight = 900;
    };
  };

  # Background Slice (Zen 5c cores only)
  systemd.slices.${backgroundSlice} = {
    description = "Background Applications (Zen 5c cores)";
    sliceConfig = {
      # CPU affinity to Zen 5c cores
      AllowedCPUs = zen5cCores;
      # Lower CPU weight
      CPUWeight = 100;
      # Memory priority
      MemoryWeight = 100;
      # IO priority
      IOWeight = 100;
      # CPU quota limit (optional - prevent background tasks from consuming all)
      CPUQuota = "80%";
    };
  };

  # =============================================================================
  # SERVICE OVERRIDES - Assign specific services to slices
  # =============================================================================
  
  # Background services -> Zen 5c cores
  systemd.services = {
    # System services
    "nix-daemon".serviceConfig.Slice = "${backgroundSlice}.slice";
    "nix-gc".serviceConfig.Slice = "${backgroundSlice}.slice";
    "nix-optimise".serviceConfig.Slice = "${backgroundSlice}.slice";
    "auto-cpufreq".serviceConfig.Slice = "${backgroundSlice}.slice";
    "powertop".serviceConfig.Slice = "${backgroundSlice}.slice";
    "thermald".serviceConfig.Slice = "${backgroundSlice}.slice";
    "updatedb".serviceConfig.Slice = "${backgroundSlice}.slice";
    "fstrim".serviceConfig.Slice = "${backgroundSlice}.slice";
    
    # Docker/Podman background tasks
    "docker".serviceConfig.Slice = "${backgroundSlice}.slice";
    "podman".serviceConfig.Slice = "${backgroundSlice}.slice";
    "containerd".serviceConfig.Slice = "${backgroundSlice}.slice";
    
    # User background services
    "pipewire".serviceConfig.Slice = "${backgroundSlice}.slice";
    "wireplumber".serviceConfig.Slice = "${backgroundSlice}.slice";
  };

  # =============================================================================
  # USER SERVICES - Desktop applications
  # =============================================================================
  
  systemd.user.services = {
    # Background apps -> Zen 5c
    "discord".serviceConfig = {
      Slice = "${backgroundSlice}.slice";
      CPUAffinity = zen5cCores;
      Nice = 10;
    };
    "telegram-desktop".serviceConfig = {
      Slice = "${backgroundSlice}.slice";
      CPUAffinity = zen5cCores;
      Nice = 10;
    };
    "slack".serviceConfig = {
      Slice = "${backgroundSlice}.slice";
      CPUAffinity = zen5cCores;
      Nice = 10;
    };
    "spotify".serviceConfig = {
      Slice = "${backgroundSlice}.slice";
      CPUAffinity = zen5cCores;
      Nice = 10;
    };
    "thunderbird".serviceConfig = {
      Slice = "${backgroundSlice}.slice";
      CPUAffinity = zen5cCores;
      Nice = 10;
    };
  };

  # =============================================================================
  # AUTO-CPUFREQ - Optimized for Zen 5
  # =============================================================================
  
  services.auto-cpufreq = {
    enable = true;
    settings = {
      charger = {
        governor = "performance";
        energy_performance_preference = "performance";
        scaling_min_freq = 800000;
        scaling_max_freq = 5100000;
        turbo = "auto";
      };
      battery = {
        governor = "powersave";
        energy_performance_preference = "power";
        scaling_min_freq = 400000;
        scaling_max_freq = 2000000;
        turbo = "auto";
        enable_thresholds = true;
        start_threshold = 40;
        stop_threshold = 80;
      };
    };
  };

  # Disable conflicting services
  services.power-profiles-daemon.enable = false;
  services.tlp.enable = lib.mkForce false;

  # =============================================================================
  # THERMAL MANAGEMENT
  # =============================================================================
  
  services.thermald = {
    enable = true;
    # Custom config for Strix Point if needed
    configFile = lib.mkDefault null;
  };

  # =============================================================================
  # KERNEL SCHEDULER OPTIMIZATIONS
  # =============================================================================
  
  boot.kernel.sysctl = {
    # Scheduler optimizations for heterogeneous cores
    "kernel.sched_migration_cost_ns" = 500000;
    "kernel.sched_nr_migrate" = 32;
    "kernel.sched_latency_ns" = 10000000;
    "kernel.sched_min_granularity_ns" = 1250000;
    "kernel.sched_wakeup_granularity_ns" = 1500000;
    
    # CPU load balancing
    "kernel.sched_domain.x86_64" = 1;
    
    # Process scheduler
    "kernel.sched_child_runs_first" = 0;
    "kernel.sched_autogroup_enabled" = 1;
    
    # Timer frequency
    "kernel.timer_migration" = 1;
    
    # Workqueue
    "kernel.workqueue.power_efficient" = 1;
  };

  # =============================================================================
  # UDEV RULES - Automatic CPU affinity for applications
  # =============================================================================
  
  services.udev.extraRules = ''
    # Zen Browser - Background slice (Zen 5c cores)
    SUBSYSTEM=="misc", KERNEL=="uinput", TAG+="uaccess"
    
    # Gaming controllers - High priority
    SUBSYSTEM=="input", ATTRS{name}=="*Controller*", TAG+="uaccess", ATTR{power/control}="on"
    SUBSYSTEM=="input", ATTRS{name}=="*Gamepad*", TAG+="uaccess", ATTR{power/control}="on"
    SUBSYSTEM=="input", ATTRS{name}=="*Xbox*", TAG+="uaccess", ATTR{power/control}="on"
    SUBSYSTEM=="input", ATTRS{name}=="*DualSense*", TAG+="uaccess", ATTR{power/control}="on"
    SUBSYSTEM=="input", ATTRS{name}=="*DualShock*", TAG+="uaccess", ATTR{power/control}="on"
    
    # USB devices - Power management
    SUBSYSTEM=="usb", ATTR{power/control}="auto"
    SUBSYSTEM=="usb", ATTR{power/autosuspend}="-1"
    
    # NVMe SSD - Performance
    SUBSYSTEM=="nvme", ATTR{queue/scheduler}="kyber"
    SUBSYSTEM=="nvme", ATTR{queue/nr_requests}="1024"
    SUBSYSTEM=="nvme", ATTR{queue/read_ahead_kb}="128"
  '';

  # =============================================================================
  # GAMEMODE - Gaming performance mode
  # =============================================================================
  
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        # Renice games
        renice = 10;
        # Disable screensaver
        screensaver_inhibit = true;
        # Default governor
        defaultgov = "performance";
        # Desired governor
        desiredgov = "performance";
      };
      
      custom = {
        # Start script - switch to performance mode
        start = "${pkgs.writeShellScript "gamemode-start" ''
          # Set CPU governor to performance
          echo performance | ${pkgs.coreutils}/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
          
          # Disable CPU boost limit (if applicable)
          echo 0 | ${pkgs.coreutils}/bin/tee /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null || true
          
          # Increase GPU performance level
          echo high | ${pkgs.coreutils}/bin/tee /sys/class/drm/card*/device/power_dpm_force_performance_level 2>/dev/null || true
          
          # Disable NMI watchdog
          echo 0 | ${pkgs.coreutils}/bin/tee /proc/sys/kernel/nmi_watchdog
          
          # Increase vm swappiness temporarily
          echo 10 | ${pkgs.coreutils}/bin/tee /proc/sys/vm/swappiness
          
          # Notify user
          ${pkgs.libnotify}/bin/notify-send -i applications-games "GameMode" "Performance mode activated" -t 2000
        ''}";
        
        # End script - restore settings
        end = "${pkgs.writeShellScript "gamemode-end" ''
          # Restore CPU governor
          echo powersave | ${pkgs.coreutils}/bin/tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
          
          # Restore NMI watchdog
          echo 1 | ${pkgs.coreutils}/bin/tee /proc/sys/kernel/nmi_watchdog
          
          # Restore vm swappiness
          echo 60 | ${pkgs.coreutils}/bin/tee /proc/sys/vm/swappiness
          
          # Notify user
          ${pkgs.libnotify}/bin/notify-send -i applications-games "GameMode" "Performance mode deactivated" -t 2000
        ''}";
      };
      
      gpu = {
        # GPU optimizations (if using AMD iGPU)
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
      };
      
      cpu = {
        # CPU pinning for games (use all cores for maximum performance)
        pin_cores = "no";
      };
    };
  };

  # =============================================================================
  # WRAPPER SCRIPTS - Easy CPU affinity
  # =============================================================================
  
  environment.etc."cpu-affinity/zen-browser.sh".source = pkgs.writeShellScript "zen-browser-cpu" ''
    #!/bin/sh
    exec taskset -c ${zen5cCores} zen "$@"
  '';

  environment.etc."cpu-affinity/discord.sh".source = pkgs.writeShellScript "discord-cpu" ''
    #!/bin/sh
    exec taskset -c ${zen5cCores} discord "$@"
  '';

  # =============================================================================
  # SHELL ALIASES
  # =============================================================================
  
  environment.shellAliases = {
    # CPU affinity shortcuts
    "perf-run" = "with-cores perf";
    "eff-run" = "with-cores eff";
    "all-run" = "with-cores all";
    
    # Monitor CPU
    "cpu-info" = "cpupower frequency-info";
    "cpu-mon" = "watch -n 1 'cpupower frequency-info | grep -E \"current policy|current CPU\"'";
    "cpu-top" = "s-tui";
    
    # Cgroup info
    "cg-info" = "systemd-cgls";
    "cg-top" = "systemd-cgtop";
  };

  # =============================================================================
  # DOCUMENTATION
  # =============================================================================
  
  environment.etc."cpu-scheduling/README.md".text = ''
    # CPU Scheduling Configuration
    
    ## Core Topology (Strix Point - Ryzen AI 9 HX 370)
    - **Zen 5 Performance Cores**: CPUs 0-3, 8-11 (4 cores + 4 SMT)
    - **Zen 5c Efficiency Cores**: CPUs 4-7, 12-15 (4 cores + 4 SMT)
    
    ## Usage
    
    ### Command Line
    ```bash
    # Run on performance cores (Zen 5)
    with-cores perf steam
    with-cores perf make -j16
    
    # Run on efficiency cores (Zen 5c)
    with-cores eff discord
    with-cores eff zen
    
    # Run on all cores
    with-cores all blender
    ```
    
    ### Systemd Services
    Services are automatically assigned to slices:
    - **high-performance.slice**: Gaming, compilation (Zen 5 cores)
    - **background.slice**: Discord, browsers, background tasks (Zen 5c cores)
    
    ### Gamemode
    Games launched with gamemode automatically get performance optimizations:
    ```bash
    gamemoderun ./game
    ```
    
    ### Monitoring
    ```bash
    s-tui              # Interactive CPU monitor
    cpupower frequency-info  # CPU frequency info
    systemd-cgtop      # Cgroup resource usage
    ```
  '';
}
