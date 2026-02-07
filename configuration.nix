{ config, pkgs, lib, inputs, ... }:

{
  # ========================================================================
  # IMPORTS - Modular Configuration Structure
  # ========================================================================
  imports = [ 
    ./hardware-configuration.nix
    
    # Hardware optimizations
    inputs.nixos-hardware.nixosModules.common-cpu-amd
    inputs.nixos-hardware.nixosModules.common-gpu-amd
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    
    # System modules - Optimized for Gigabyte Aero X16
    ./modules/kernel.nix
    ./modules/cpu-scheduling.nix      # Zen 5/5c core management
    ./modules/npu.nix                 # AMD XDNA NPU support
    ./modules/nix-optimizations.nix   # Parallel build/download
    ./modules/nvidia.nix
    ./modules/gaming.nix
    ./modules/desktop.nix
    ./modules/hyprland.nix 
    ./modules/flstudio.nix
    ./modules/audio.nix
    ./modules/networking.nix
    ./modules/packages.nix
    ./modules/zapret.nix
    ./modules/power-management.nix
    ./wrapped-programs/prism.nix
  ];

  # ========================================================================
  # BOOT CONFIGURATION
  # ========================================================================
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        consoleMode = "max";
        editor = false;
      };
      timeout = 2;
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
    };
    
    # Use systemd in initrd for better error handling
    initrd.systemd.enable = true;
    
    # Plymouth for smooth boot
    plymouth = {
      enable = true;
      theme = "breeze";
    };
  };
  
  # Global systemd timeout
  systemd.watchdog.rebootTime = "10s";
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
    DefaultTimeoutStartSec = "30s";
  };

  # ========================================================================
  # BOOT OPTIMIZATION
  # ========================================================================
  systemd.services.NetworkManager-wait-online.enable = false;
  
  # NVIDIA Coolbits
  services.xserver.deviceSection = ''
    Option "Coolbits" "28"
  '';

  # ========================================================================
  # LOCALIZATION
  # ========================================================================
  time.timeZone = "Europe/Istanbul";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "tr_TR.UTF-8";
      LC_IDENTIFICATION = "tr_TR.UTF-8";
      LC_MEASUREMENT = "tr_TR.UTF-8";
      LC_MONETARY = "tr_TR.UTF-8";
      LC_NAME = "tr_TR.UTF-8";
      LC_NUMERIC = "tr_TR.UTF-8";
      LC_PAPER = "tr_TR.UTF-8";
      LC_TELEPHONE = "tr_TR.UTF-8";
      LC_TIME = "tr_TR.UTF-8";
    };
  };
  
  # Keyboard
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  console.keyMap = "us";

  # ========================================================================
  # VIRTUALIZATION
  # ========================================================================
  virtualisation.libvirtd = {
    enable = true;
  };
  
  programs.virt-manager.enable = true;
  
  security.unprivilegedUsernsClone = true;
  
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  
  virtualisation.containers = {
    enable = true;
    storage.settings = {
      storage = {
        driver = "overlay2";
        runroot = "/run/containers/storage";
        graphroot = "/var/lib/containers/storage";
      };
    };
  };

  # ========================================================================
  # USER MANAGEMENT
  # ========================================================================
  users.users.zixar = {
    isNormalUser = true;
    description = "zixar";
    shell = pkgs.zsh;
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "video" 
      "audio"
      "podman"
      "docker"
      "libvirtd"
      "kvm"
      "input"
      "accel"
      "render"
      "gamemode"
    ];
    openssh.authorizedKeys.keys = [];
  };
 
  # /etc/nixos dizinine sudo'suz yazma yetkisi
  systemd.tmpfiles.rules = [
    "d /etc/nixos 0755 zixar users -"
    "d /var/cache/ccache 0755 root nixbld -"
    "d /tmp/nix-build 0755 root root -"
  ];
 
  programs.zsh.enable = true;

  # ========================================================================
  # FONTS
  # ========================================================================
  fonts = {
    packages = with pkgs; [
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      font-awesome
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      roboto
      open-sans
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" "JetBrains Mono" ];
        sansSerif = [ "Noto Sans" "Roboto" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
      };
      subpixel = {
        lcdfilter = "default";
        rgba = "rgb";
      };
    };
    enableDefaultPackages = true;
  };

  # ========================================================================
  # NIX CONFIGURATION - Optimized
  # ========================================================================
  nix = {
    settings = {
      # Parallel builds (8 cores for Strix Point)
      max-jobs = 8;
      cores = 4;
      
      # Parallel downloads
      download-buffer-size = 512 * 1024 * 1024;
      
      # Binary caches
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://chaotic-nyx.cachix.org"
        "https://cuda-maintainers.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vFcUsQ="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rNqbDBO8NpdgaQcpGuPvGjTMJU="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
      
      # Performance
      auto-optimise-store = true;
      keep-outputs = true;
      keep-derivations = true;
      builders-use-substitutes = true;
      
      # Features
      experimental-features = [ "nix-command" "flakes" "ca-derivations" ];
      trusted-users = [ "root" "@wheel" "zixar" ];
    };
    
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
      persistent = true;
    };
    
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
    
    extraOptions = ''
      http-connections = 50
      binary-caches-parallel-connections = 50
      log-lines = 25
    '';
  };

  # ========================================================================
  # SECURITY
  # ========================================================================
  security = {
    sudo.wheelNeedsPassword = true;
    sudo.extraConfig = ''
      Defaults timestamp_timeout=10
      zixar ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/gaming-perf
      zixar ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/nix-store-optimize
    '';
    polkit.enable = true;
    rtkit.enable = true;
  };
  
  programs.dconf.enable = true;

  # ========================================================================
  # SYSTEM STATE
  # ========================================================================
  system.stateVersion = "25.11";

  # ========================================================================
  # DOCUMENTATION
  # ========================================================================
  environment.etc."nixos-info/README.md".text = ''
    # Gigabyte Aero X16 NixOS Configuration
    
    ## Hardware
    - **CPU**: AMD Ryzen AI 9 HX 370 (Strix Point)
    - **Cores**: 4x Zen 5 (Perf) + 4x Zen 5c (Eff) = 8C/16T
    - **NPU**: AMD XDNA 2 (50 TOPS)
    - **GPU**: NVIDIA RTX 4070 Laptop + AMD Radeon 890M
    - **RAM**: 32GB DDR5
    - **SSD**: Kingston OM8PGP4
    
    ## Quick Commands
    
    ### System
    ```bash
    rebuild           # Rebuild system
    rebuild-test      # Test configuration
    nix-gc           # Garbage collect
    nix-store-optimize # Optimize store
    ```
    
    ### CPU Scheduling
    ```bash
    with-cores perf <cmd>   # Run on Zen 5 cores
    with-cores eff <cmd>    # Run on Zen 5c cores
    cpu-info               # CPU frequency info
    s-tui                  # CPU monitor
    ```
    
    ### NPU
    ```bash
    npu-mon            # NPU status
    npu-bench          # NPU benchmark
    ```
    
    ### Gaming
    ```bash
    gaming-perf on     # Enable gaming mode
    gaming-perf off    # Disable gaming mode
    gamemoderun <game> # Run game with optimizations
    ```
    
    ## Documentation
    - CPU: `/etc/cpu-scheduling/README.md`
    - NPU: `/etc/npu/README.md`
    - Nix: `/etc/nix-optimizations/README.md`
    - Gaming: `/etc/gaming/README.md`
    
    ## Specializations
    - `zen-kernel`: Zen kernel for gaming
    - `xanmod-kernel`: Xanmod low-latency kernel
    - `lts-kernel`: Stable LTS kernel
    
    Select at boot: Advanced options for NixOS
  '';
}
