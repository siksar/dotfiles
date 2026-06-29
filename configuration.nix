{ pkgs, config, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  boot.initrd.kernelModules = [ "amdgpu" ];
  
  boot.kernelParams = [
    "amd_pstate=active"     # Strix Point/Zen 5 EPP scaling
    "amdgpu.gfx_off=1"      # RDNA 3.5 iGPU sleep
    "amdgpu.abmlevel=3"     # eDP panel Auto Brightness Management
  ];

  boot.extraModprobeConfig = ''
    options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y disable_clkreq=y
    options rtw89_core disable_ps_mode=y
  '';

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Istanbul";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
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

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  services.power-profiles-daemon.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open = true; # Blackwell dGPU open source driver modules
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest; # Will evaluation to v610 series
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:100:0:0";
      amdgpuBusId = "PCI:101:0:0";
    };
  };

  users.users.zixar = {
    isNormalUser = true;
    description = "zixar";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    antigravity
    bitwarden-desktop
    libva-utils
    vdpauinfo
  ];

  environment.variables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER = "radeonsi";
  };

  system.stateVersion = "26.05";

}
