{ config, pkgs, ... }:

{
  # ========================================================================
  # HYPRLAND - Wayland Compositor
  # ========================================================================
  
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Hyprland ecosystem packages
  environment.systemPackages = with pkgs; [
    waybar       # Status bar
    dunst        # Notification daemon
    swww         # Wallpaper daemon
    wofi         # App launcher
    kitty        # Terminal
    
    # Wayland utilities
    wl-clipboard
    grim         # Screenshot
    slurp        # Screen area selection
  ];

  # XDG Portal for Hyprland
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };
}
