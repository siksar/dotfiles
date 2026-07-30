{ lib, pkgs, ... }:

{
  imports = [
    ./modules/desktop/hyprland-rice/hm.nix
    ./modules/desktop/fish.nix
    ./modules/desktop/ghostty.nix
    ./modules/desktop/shell.nix
    ./modules/apps/vesktop.nix
    ./modules/apps/zen.nix
    ./modules/apps/claude-desktop.nix
    ./modules/apps/media.nix
    ./modules/apps/gaming.nix
    ./modules/apps/minecraft.nix
    ./modules/apps/opencode.nix
    ./modules/apps/vscodium.nix
    ./modules/apps/tui.nix
  ];

  home.username      = "zixar";
  home.homeDirectory = "/home/zixar";
  home.stateVersion  = "26.05";
  programs.home-manager.enable = true;

  # Standalone HM switch kısayolu (-b: gömülü HM'nin backupFileExtension eşleniği)
  home.shellAliases.hms = "nh home switch -b hm-backup";

  programs.bash.enable = true;

  # HM'nin ürettiği .bash_profile, .bashrc'yi koşulsuz source eder; .bashrc'nin
  # `[[ $- == *i* ]] || return` koruması etkileşimsiz kabukta 1 döndürür.
  # hm-setup-env aktivasyonu `bash -el` (login + errexit) açtığından bu,
  # home-manager-zixar.service'i çıktısız öldürüyordu (üstakım activation
  # driver-v1 regresyonu). .bashrc'yi yalnız etkileşimli kabukta içer.
  # NOT: modül .bash_profile'ı `source` ile tanımlar; `text` mkDefault'a
  # çevrildiğinden text'i force'lamak YETMEZ — source force'lanmalı.
  home.file.".bash_profile".source = lib.mkForce (pkgs.writeText "bash_profile" ''
    # include .profile if it exists
    if [[ -f ~/.profile ]]; then . ~/.profile; fi

    # include .bashrc if it exists — YALNIZ etkileşimli kabukta
    if [[ $- == *i* && -f ~/.bashrc ]]; then . ~/.bashrc; fi
  '');
}
