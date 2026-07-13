{ ... }:

{
  imports = [
    ./modules/desktop/gnome-hm.nix
    ./modules/desktop/ghostty.nix
    ./modules/desktop/shell.nix
    ./modules/apps/vesktop.nix
    ./modules/apps/zen.nix
    ./modules/apps/claude-desktop.nix
    ./modules/apps/media.nix
    ./modules/apps/helix.nix
    ./modules/apps/gaming.nix
    ./modules/apps/opencode.nix
  ];

  home.username      = "zixar";
  home.homeDirectory = "/home/zixar";
  home.stateVersion  = "26.05";
  programs.home-manager.enable = true;

  # Standalone HM switch kısayolu (-b: gömülü HM'nin backupFileExtension eşleniği)
  home.shellAliases.hms = "nh home switch -b hm-backup";

  programs.bash = {
    enable = true;
    profileExtra = ''
      # JetBrains Toolbox
      export PATH="$PATH:$HOME/.local/share/JetBrains/Toolbox/scripts"
    '';
  };
}
