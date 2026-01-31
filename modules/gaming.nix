{ config, pkgs, ... }:
{
  # ========================================================================
  # GAMING - Steam, Gamemode, GPU Tools
  # ========================================================================
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
  };
  
  services.switcherooControl.enable = true;
  # NOT: LACT paketi packages.nix'te eklendi
  # lactd servisi yok, sadece GUI uygulaması var
  programs.gamemode = {
    enable = true;
    settings.general.renice = 10;
  };

  # MangoHud is installed as a package in packages.nix
  # Configuration can be done via ~/.config/MangoHud/MangoHud.conf or environment variables
  # Example: MANGOHUD_CONFIG=fps,cpu_temp,gpu_temp mangohud %command%

  
  # ========================================================================
  # GPU POWER MANAGEMENT
  # ========================================================================
  # Custom power profile services removed - letting power-profiles-daemon 
  # and NVIDIA driver handle power management automatically.
}
