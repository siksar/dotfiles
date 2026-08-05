{ lib, pkgs, ... }:

{
  imports = [
    # desktop/ — Hyprland oturumu, bar, launcher, tema motoru
    ./home/desktop/session.nix
    ./home/desktop/theme/matugen.nix
    ./home/desktop/bar/waybar.nix
    ./home/desktop/launcher/rofi.nix
    ./home/desktop/notify/swaync.nix

    # shell/ — kabuk ve terminal ortamı
    ./home/shell/fish.nix
    ./home/shell/starship.nix
    ./home/shell/ghostty.nix
    ./home/shell/tmux.nix

    # apps/ — kullanıcı uygulamaları
    ./home/apps/vesktop.nix
    ./home/apps/zen.nix
    ./home/apps/vscodium.nix
    ./home/apps/claude-desktop.nix
    ./home/apps/media.nix
    ./home/apps/games.nix
    ./home/apps/minecraft.nix
    ./home/apps/emu.nix
    ./home/apps/opencode.nix
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
