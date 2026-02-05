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
  # NIRI WINDOW MANAGER (Rust Based)
  # ========================================================================
  programs.niri.enable = true;

  # ========================================================================
  # GREETD DISPLAY MANAGER (Rust Based)
  # ========================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd hyprland --asterisks --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };

  # SDDM Disabled
  # services.displayManager.sddm = {
  #   enable = true;
  #   wayland.enable = true;
  # };
  
  # Auto-login disabled (handled by remember-session in tuigreet if needed)
  # services.displayManager.autoLogin...
  
  # Default session is handled by tuigreet --cmd flag
  # services.displayManager.defaultSession = "hyprland";

  # ========================================================================
  # ESSENTIAL DESKTOP PACKAGES
  # ========================================================================
  environment.systemPackages = with pkgs; [
    # File manager - THUNAR KALDIRILDI (Yazi kullanılıyor - home/yazi.nix)
    
    # Archive manager
    file-roller
    
    # Image viewer
    imv
    
    # System
    adwaita-icon-theme
    papirus-icon-theme
    pavucontrol
    
    # DM
    tuigreet
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
