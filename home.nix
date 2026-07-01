{ ... }:

{
  imports = [
    ./modules/desktop/hyprland/default.nix
    ./modules/desktop/waybar/default.nix
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

      # UWSM canonical check: compositor yoksa ve VT uygunsa Hyprland başlat
      if uwsm check may-start 2>/dev/null; then
        exec uwsm start hyprland-uwsm.desktop
      fi
    '';
  };
}
