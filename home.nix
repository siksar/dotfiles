{ ... }:

{
  imports = [
    ./modules/desktop/hyprland/default.nix
    ./modules/desktop/caelestia/default.nix
    ./modules/desktop/caelestia/stylix-hm.nix
    ./modules/desktop/ghostty.nix
    ./modules/desktop/shell.nix
    ./modules/apps/vesktop.nix
    ./modules/apps/zen.nix
    ./modules/apps/claude-desktop.nix
    ./modules/apps/media.nix
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
