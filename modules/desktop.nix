{ config, pkgs, ... }:
{
  # ========================================================================
  # DESKTOP ENVIRONMENT - Hyprland Only
  # ========================================================================
  
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      autoRepeatDelay = 300;
      autoRepeatInterval = 20;
    };
  };

  # ========================================================================
  # SDDM DISPLAY MANAGER (Wayland)
  # ========================================================================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  
  # Auto-login for zixar
  services.displayManager.autoLogin = {
    enable = true;
    user = "zixar";
  };
  
  # Default session (Hyprland)
  services.displayManager.defaultSession = "hyprland";

  # ========================================================================
  # ESSENTIAL DESKTOP PACKAGES
  # ========================================================================
  environment.systemPackages = with pkgs; [
    # File manager (lightweight alternative to Dolphin)
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    
    # Archive manager
    file-roller
    
    # Image viewer
    imv
    
    # System
    adwaita-icon-theme
    papirus-icon-theme
    pavucontrol
  ];

  # ========================================================================
  # DCONF & GTK INTEGRATION
  # ========================================================================
  programs.dconf.enable = true;
  
  # Cursor theme
  environment.variables = {
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
  };

  # ========================================================================
  # XDG PORTAL - Hyprland + GTK
  # ========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [ 
      pkgs.xdg-desktop-portal-gtk 
    ];
    config = {
      hyprland.default = [ "hyprland" "gtk" ];
      common.default = [ "gtk" ];
    };
  };
}
