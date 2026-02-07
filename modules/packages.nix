{ config, pkgs, ... }:
{
  # ========================================================================
  # SYSTEM PACKAGES
  # ========================================================================

  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    # Core utilities
    helix # Rust based editor (Neovim replacement)
    wget
    git
    macchina # Rust based fetch (Fastfetch replacement)
    bottom # Rust based monitor (Btop replacement)

    nvtopPackages.full # AMD + NVIDIA desteği için full paket
    lact # AMD GPU kontrol (gaming.nix'ten taşındı)
    antigravity
    vscode


    # Hardware Diagnostics
    nvme-cli
    smartmontools
    claude-code
    # Browser & Productivity
    bitwarden-desktop
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
    prismlauncher # Minecraft launcher with mod support
    heroic # Epic Games & GOG launcher

    # Music Applications
    ytmdesktop # YouTube Music desktop client
    # mpv is required for ytui-music and is generally useful
    mpv
    yt-dlp

    # AppImage support
    appimage-run
    # Development tools
    docker
    gruvbox-gtk-theme
    gruvbox-dark-icons-gtk
    docker-compose
    protonup-qt # Proton version manager (GE-Proton installation)
    mangohud # FPS counter & limiter/unlimiter
    gamescope # Wayland compositor for gaming (useful for fix resolution/refresh rate)
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

  programs = {
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
      };
    };

  };
}
