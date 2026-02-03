{ config, pkgs, ... }:
{
  # ========================================================================
  # IMPORTS - Modular Configuration Structure
  # ========================================================================
  imports = [ 
    ./hardware-configuration.nix
    # Hardware Contribution Test (DISABLED)
    # ./hardware/gigabyte/aero/16/default.nix
    
    # User modules
    ./modules/nvidia.nix
    ./modules/gaming.nix
    ./modules/kernel.nix 
      
    # System modules
    ./modules/desktop.nix
    ./modules/hyprland.nix
    ./modules/flstudio.nix
    ./modules/audio.nix
    ./modules/networking.nix
    ./modules/packages.nix
    ./modules/zapret.nix
   ./modules/power-management.nix
  ];
  # ========================================================================
  # BOOT CONFIGURATION
  # ========================================================================
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 3;
      };
      timeout = 0;
      efi.canTouchEfiVariables = true;
    };
    
    # Use systemd in initrd for better error handling and mount reliability
    initrd.systemd.enable = true;
  };
  
  # Global systemd timeout to kill stuck services (sound.target, etc) during shutdown
  systemd.watchdog.rebootTime = "10s";
  # New syntax for systemd manager configuration
  # Using systemd.settings.Manager as likely suggested by error
  systemd = {
    settings = {
      Manager = {
        DefaultTimeoutStopSec = "10s";
      };
    };
  };

  # ========================================================================
  # BOOT OPTIMIZATION
  # ========================================================================
  # Disable NetworkManager wait online (Simulates fast boot, rarely causes issues)
  systemd.services.NetworkManager-wait-online.enable = false;
  # NVIDIA Coolbits (videoDrivers nvidia.nix'te tanımlı)
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
  # ========================================================================
  # VIRTUALIZATION
  # ========================================================================
  # ========================================================================
  # VIRTUALIZATION (KVM / QEMU / Podman)
  # ========================================================================
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  
   security.unprivilegedUsernsClone = true;
 virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
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
      "i2c"
    ];
 };
 
 # /etc/nixos dizinine sudo'suz yazma yetkisi
 systemd.tmpfiles.rules = [
   "d /etc/nixos 0755 zixar users -"
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
    ];
    fontconfig = {
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" "JetBrains Mono" ];
        sansSerif = [ "JetBrains Mono" "Noto Sans" ];
        serif = [ "JetBrains Mono" "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  # ========================================================================
  # NIX CONFIGURATION
  # ========================================================================
  nix = {
    settings = {
      max-jobs = "auto";
      cores = 0;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
        "https://attic.xuyh0120.win/lantian"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      ];
      auto-optimise-store = true;
      experimental-features = [ "nix-command" "flakes" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
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
  
  # TLP removed - using auto-cpufreq instead (power-management.nix)
  # Disable power-profiles-daemon (conflicts with auto-cpufreq)
  # services.power-profiles-daemon.enable = false;
  
  system.stateVersion = "26.05";
}
