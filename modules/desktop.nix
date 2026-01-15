{ config, pkgs, ... }:

{
  # ========================================================================
  # GNOME DESKTOP ENVIRONMENT
  # ========================================================================
  
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      
      # Keyboard repeat optimization
      autoRepeatDelay = 300;
      autoRepeatInterval = 20;
    };

#    displayManager.gdm.enable = true;
#    desktopManager.gnome.enable = true;
  };
  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;
  # GNOME bloat removal - Aggressive cleanup
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany        # Web browser
    geary           # Mail client
    gnome-music
    gnome-photos
    gnome-maps
    cheese          # Webcam app
    totem           # Video player
    yelp            # Help docs
  ];

  # DConf for GNOME settings
  programs.dconf.enable = true;

  # Cursor theme fix
  environment.variables = {
    XCURSOR_THEME = "Adwaita";
    XCURSOR_SIZE = "24";
    GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
  };

  # Desktop integration packages
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    vanilla-dmz
    pavucontrol
    papirus-icon-theme
  ];

  # XDG Portal for file pickers, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };
}
