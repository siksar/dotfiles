{ ... }:

{
  imports = [
    ./modules/desktop/hyprland/default.nix
    ./modules/desktop/waybar/default.nix
    ./modules/desktop/caelestia/stylix-hm.nix
  ];

  home.username      = "zixar";
  home.homeDirectory = "/home/zixar";
  home.stateVersion  = "26.05";
  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    profileExtra = ''
      # JetBrains Toolbox
      export PATH="$PATH:$HOME/.local/share/JetBrains/Toolbox/scripts"
    '';
  };
}
