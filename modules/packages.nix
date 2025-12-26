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
    nvtopPackages.v3d
    # Browser & Productivity
    brave
    bitwarden-desktop
    
    # AI Tools
    lmstudio
    
    # AppImage support
    appimage-run
    
    # Development tools (uncomment if needed)
    vscode
     docker
     docker-compose
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

  # Flatpak
  services.flatpak.enable = true;

  # Programs
  programs = {
    # Git configuration
    git = {
      enable = true;
      config = {
        init.defaultBranch = "main";
      };
    };
    
    # Neovim (if you want to replace vim)
     neovim = {
       enable = true;
       defaultEditor = true;
     };
  };
}
