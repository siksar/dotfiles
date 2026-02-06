{ config, pkgs, ... }:
{
  # ========================================================================
  # DESKTOP ENVIRONMENT - Hyprland + Niri
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
  programs.niri = {
    enable = true;
    # Niri package from flake input will be used automatically via nixosModules.niri
  };
  # ========================================================================
  # GREETD DISPLAY MANAGER (Rust Based)
  # ========================================================================
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # Multi-session support - user can choose between Hyprland and Niri
        command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
    };
  };
  # ========================================================================
  # ESSENTIAL DESKTOP PACKAGES
  # ========================================================================
  environment.systemPackages = with pkgs; [
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
  # XDG PORTAL - Hyprland + Niri + GTK
  # ========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config = {
      hyprland.default = [ "hyprland" "gtk" ];
      niri.default = [ "gnome" "gtk" ];
      common.default = [ "gtk" ];
    };
  };
}
