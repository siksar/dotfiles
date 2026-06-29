{ pkgs, ... }:

{
  imports = [
    ./binds.nix
    ./settings.nix
    ./rules.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false; # UWSM ile çakışmayı önler (programs.hyprland.withUWSM = true)
  };
}

