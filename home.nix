{ lib, pkgs, ... }:

{
  imports = [
    ./home/shell/fish.nix
    ./home/shell/starship.nix
    ./home/shell/ghostty.nix
    ./home/shell/tmux.nix
    ./home/shell/nix-index.nix

    ./home/desktop/hyprland

    ./home/apps/vesktop.nix
    ./home/apps/zen.nix
    ./home/apps/helium.nix
    ./home/apps/brave.nix
    ./home/apps/media.nix
    ./home/apps/games.nix
    ./home/apps/minecraft.nix
    ./home/apps/emu.nix
    ./home/apps/opencode.nix
    ./home/apps/downloads.nix
    ./home/apps/streamrip.nix
    ./home/apps/lollypop.nix
    ./home/apps/syncthing.nix
  ];

  home.username      = "zixar";
  home.homeDirectory = "/home/zixar";
  home.stateVersion  = "26.05";
  programs.home-manager.enable = true;

  # qtct: Stylix'in 'gnome' Qt platformu desteklenmiyor (eval uyarısı).
  stylix.targets.qt.platform = "qtct";
  # rofi yok; hedef açıkken eski seçenek adıyla uyarı basıyor.
  stylix.targets.rofi.enable = false;

  home.shellAliases.hms = "nh home switch -b hm-backup";

  programs.bash.enable = true;

  # .bashrc'nin etkileşimsiz `return`'ü hm-setup-env'i (bash -el) öldürüyordu → yalnız
  # etkileşimli kabukta içer. text mkDefault olduğundan source force'lanmalı.
  home.file.".bash_profile".source = lib.mkForce (pkgs.writeText "bash_profile" ''
    # include .profile if it exists
    if [[ -f ~/.profile ]]; then . ~/.profile; fi

    # include .bashrc if it exists — YALNIZ etkileşimli kabukta
    if [[ $- == *i* && -f ~/.bashrc ]]; then . ~/.bashrc; fi
  '');
}
