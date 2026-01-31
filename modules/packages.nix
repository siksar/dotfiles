{ config, pkgs, ... }:
{
  # ========================================================================
  # SYSTEM PACKAGES
  # ========================================================================
  
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    # Core utilities
    vim
    wget
    git
    fastfetch
    htop
    nvtopPackages.full # AMD + NVIDIA desteği için full paket
    lact               # AMD GPU kontrol (gaming.nix'ten taşındı)
    antigravity   
    
    # Hardware Diagnostics
    nvme-cli
    smartmontools
    
    # Browser & Productivity
    bitwarden-desktop
    vivaldi
    home-manager   
    bottles 
    # AI Tools
    lmstudio
    localsend
    wine
    winetricks
    dxvk
    vkd3d
    
    # Gaming Launchers
    prismlauncher      # Minecraft launcher with mod support
    heroic             # Epic Games & GOG launcher
    
    # Music Applications
    ytui-music         # YouTube Music TUI/CLI player
    ytmdesktop         # YouTube Music desktop client
    mpv                # Media player (required for ytui-music)
    yt-dlp             # YouTube downloader (required for ytui-music)
    
    # AppImage support
    appimage-run
    # Development tools
    vscode
    docker
    gruvbox-gtk-theme
    gruvbox-dark-icons-gtk
    docker-compose
    protonup-qt       # Proton version manager (GE-Proton installation)
    mangohud          # FPS counter & limiter/unlimiter
    gamescope         # Wayland compositor for gaming (useful for fix resolution/refresh rate)
  ];
  # AppImage binfmt registration
  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };
  services.flatpak.enable = true;
  programs = {
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
      };
    };
    
    neovim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
