{ config, pkgs, ... }:

{
  # ========================================================================
  # IMPORTS - Modular Configuration Structure
  # ========================================================================
  imports = [ 
    ./hardware-configuration.nix
    
    # Hardware modules (senin mevcut dosyaların)
    ./modules/nvidia.nix
    ./modules/gaming.nix
    
    # System modules (yeni oluşturacağın)
    ./modules/desktop.nix
    ./modules/hyprland.nix
    ./modules/audio.nix
    ./modules/networking.nix
    ./modules/packages.nix
  ];

  # ========================================================================
  # BOOT CONFIGURATION
  # ========================================================================
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 3;  # Sadece 3 generation tut
      };
      timeout = 0;  # Boot menu bypass - instant boot
      efi.canTouchEfiVariables = true;
    };
    
    # Performance kernel
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    
    # Kernel tuning for gaming
    kernel.sysctl = {
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };
  };
services.xserver = {
  enable = true;
  videoDrivers = [ "nvidia" ];
  
  # "28" değeri tüm overclock ve fan kontrol özelliklerini açar
  deviceSection = ''
    Option "Coolbits" "28"
  '';
};
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

  # Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;  # Start on boot
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Podman (Docker alternative - rootless)
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;  # Create 'docker' alias to podman
    defaultNetwork.settings.dns_enabled = true;
  };

  # Container networking
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
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "video" 
      "audio"
      "podman"
      "docker"  # Uncomment if using Docker
    ];
  };

  # ========================================================================
  # NIX CONFIGURATION
  # ========================================================================
  nix = {
    settings = {
      # Parallel builds
      max-jobs = "auto";
      cores = 0;
      
      # Binary cache
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      
      # Store optimization
      auto-optimise-store = true;
      
      # Experimental features
      experimental-features = [ "nix-command" "flakes" ];
    };

    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    
    # Store optimization
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # ========================================================================
  # SECURITY
  # ========================================================================
  security = {
    sudo.wheelNeedsPassword = true;
    polkit.enable = true;
  };

  # ========================================================================
  # SYSTEM
  # ========================================================================
  system.stateVersion = "25.11";  # ASLA DEĞİŞTİRME
}
