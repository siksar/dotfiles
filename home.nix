{ ... }:

{
  imports = [
    ./modules/desktop/shells/choice.nix
    ./modules/desktop/shells/common.nix
    ./modules/desktop/hyprland/default.nix
    ./modules/desktop/caelestia/default.nix
    ./modules/desktop/caelestia/stylix-hm.nix
    ./modules/desktop/dms/default.nix
    ./modules/desktop/noctalia/default.nix
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

  # Aktif kabuk — caelestia | dms | noctalia
  # Değiştir + `hms` (nh home switch) → eski kabuk durur, yenisi başlar
  rice.shell = "caelestia";

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
