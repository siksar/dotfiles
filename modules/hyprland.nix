{ config, pkgs, hyprland, ... }:
{
  # ========================================================================
  # HYPRLAND WINDOW MANAGER
  # ========================================================================
  
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # Use the flake package for latest features
    package = hyprland.packages.${pkgs.system}.hyprland;
  };

  # ========================================================================
  # XDG PORTAL FOR HYPRLAND
  # Note: xdg-desktop-portal-hyprland is provided by Hyprland flake module
  # ========================================================================
  xdg.portal.config.hyprland.default = [ "hyprland" "gtk" ];

  # ========================================================================
  # HYPRLAND DEPENDENCIES & UTILITIES
  # ========================================================================
  environment.systemPackages = with pkgs; [
    # Hyprland ecosystem
    hyprpaper              # Wallpaper daemon
    hypridle               # Idle daemon
    hyprlock               # Screen lock
    hyprpicker             # Color picker
    
    # Status bar
    waybar
    
    # Application launcher
    rofi                 # rofi-wayland merged into rofi in 25.11
    
    # Notifications
    # dunst # Removed to prevent conflict with Noctalia notifications
    libnotify
    
    # Screenshot & Recording
    grim
    slurp
    wf-recorder
    grimblast
    
    # Clipboard
    wl-clipboard
    cliphist
    
    # Audio control
    pamixer
    playerctl
    
    # Brightness control
    brightnessctl
    
    # Wallpaper
    swww
    
    # File manager - THUNAR KALDIRILDI (Yazi kullanılıyor)
    
    # Network applet
    networkmanagerapplet
    
    # Bluetooth
    blueman
    
    # Authentication agent
    polkit_gnome
  ];

  # ========================================================================
  # POLKIT AUTHENTICATION AGENT
  # ========================================================================
  security.polkit.enable = true;
  
  systemd.user.services.polkit-gnome-agent = {
    description = "Polkit GNOME Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # ========================================================================
  # ENVIRONMENT VARIABLES FOR WAYLAND/HYPRLAND
  # ========================================================================
  environment.sessionVariables = {
    # Wayland
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    
    # XDG
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    
    # Qt
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    
    # GTK
    GDK_BACKEND = "wayland,x11";
    
    # Cursor
    XCURSOR_SIZE = "24";
  };

  # ========================================================================
  # SERVICES
  # ========================================================================
  
  # D-Bus (required for many desktop features)
  services.dbus.enable = true;
  
  # GVFS for file manager functionality
  services.gvfs.enable = true;
  
  # Tumbler for thumbnails
  services.tumbler.enable = true;
  
  # UDisks2 for drive management
  services.udisks2.enable = true;
}
