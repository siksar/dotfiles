{ config, pkgs, ... }:

{
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
  };
  
  services.switcherooControl.enable = true; # GPU geçişi için
  systemd.services.lactd.enable = true;     # AMD GPU kontrol

  programs.gamemode = {
    enable = true;
    settings.general.renice = 10;
  };
}
