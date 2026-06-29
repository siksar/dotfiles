{ ... }:

{
  home.username = "zixar";
  home.homeDirectory = "/home/zixar";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;

  imports = [
    ./modules/desktop/hyprland/default.nix
  ];
}
