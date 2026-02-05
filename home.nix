{ config, pkgs, hyprland, noctalia, zen-browser, ... }:
{
  # ========================================================================
  # IMPORTS - Modular Home Configuration
  # ========================================================================
  imports = [
    ./home/hyprland.nix   # Hyprland user config
    ./home/noctalia.nix   # Noctalia Shell
    ./home/zsh.nix        # ZSH
    ./home/starship.nix   # Starship Config
    # ./home/waybar.nix     # DISABLED - Using Noctalia bar
    # ./home/rofi.nix       # DISABLED - Using Noctalia launcher
    ./home/editors.nix    # VS Code, Neovim, Helix
    # ./home/dunst.nix      # DISABLED - Using Noctalia notifications
    ./home/hyprlock.nix   # Lock screen & idle
    ./home/tui-media.nix  # Anime/Manga TUI apps
    ./home/wrappers.nix   # Tutorial/Examples for wrappers
    ./home/yazi.nix       # Modern TUI File Manager
    ./modules/noctalia-home.nix # Noctalia Shell (Declarative)
  ];

  # ========================================================================
  # HOME MANAGER BASE
  # ========================================================================
  home.stateVersion = "25.11";
  home.username = "zixar";
  home.homeDirectory = "/home/zixar";
  home.sessionVariables = {
    SHELL = "${pkgs.zsh}/bin/zsh";
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "kitty";
    BROWSER = "zen";
  };

  # Add local bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # ========================================================================
  # GIT
  # ========================================================================
  programs.git = {
    enable = true;
    settings = {
      user.name = "zixar";
      user.email = "halilbatuhanyilmaz@proton.me";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
    };
  };
  
  # Delta - Better git diff
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "gruvbox-dark";
      line-numbers = true;
    };
  };

  # ZSH + Starship -> Moved to ./home/zsh.nix

  # ========================================================================
  # KITTY TERMINAL - Dynamic Theme Support (Noctalia Integration)
  # ========================================================================
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    settings = {
      # ====================================================================
      # RENK TEMASı - Noctalia tarafından yönetiliyor
      # ====================================================================
      # Noctalia Settings → Color Scheme → Templates → Kitty'yi aktifleştir
      # Renkler ~/.config/kitty/current-theme.conf dosyasından dinamik olarak okunur
      
      # Tokyo Night
      background = "#1a1b26";
      foreground = "#a9b1d6";
      
      # Cursor
      cursor = "#c0caf5";
      cursor_text_color = "#1a1b26";
      
      # Selection
      selection_background = "#33467c";
      selection_foreground = "#c0caf5";
      
      # Black
      color0 = "#414868";
      color8 = "#414868";
      
      # Red
      color1 = "#f7768e";
      color9 = "#f7768e";
      
      # Green
      color2 = "#73daca";
      color10 = "#73daca";
      
      # Yellow
      color3 = "#e0af68";
      color11 = "#e0af68";
      
      # Blue
      color4 = "#7aa2f7";
      color12 = "#7aa2f7";
      
      # Magenta
      color5 = "#bb9af7";
      color13 = "#bb9af7";
      
      # Cyan
      color6 = "#7dcfff";
      color14 = "#7dcfff";
      
      # White
      color7 = "#c0caf5";
      color15 = "#c0caf5";
      
      # UI
      background_opacity = "0.95";
      window_padding_width = 12;
      enable_audio_bell = false;
      cursor_blink_interval = 0;
      confirm_os_window_close = 0;
      
      # URL
      url_color = "#73daca";
      url_style = "curly";
      
      # Tab bar
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      active_tab_background = "#7aa2f7";
      active_tab_foreground = "#1a1b26";
      inactive_tab_background = "#24283b";
      inactive_tab_foreground = "#a9b1d6";
      
      # Image protocol (for fastfetch, etc.)
      allow_hyperlinks = "yes";
    };
    

    
    keybindings = {
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+w" = "close_tab";
      "ctrl+shift+left" = "previous_tab";
      "ctrl+shift+right" = "next_tab";
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";
      "ctrl+plus" = "change_font_size all +2.0";
      "ctrl+minus" = "change_font_size all -2.0";
      "ctrl+0" = "change_font_size all 0";
    };
  };

  # ========================================================================
  # FASTFETCH - With Kitty Image Support
  # ========================================================================
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "kitty";
        source = "/home/zixar/Pictures/logo_v2.png";
        width = 40;
        height = 18;
      };
      display = {
        separator = ": ";
        color = {
          keys = "yellow";
          title = "red";
        };
      };
      modules = [
        {
          type = "title";
          format = "{user-name}@{host-name}";
        }
        "separator"
        { type = "os"; key = "OS"; }
        { type = "host"; key = "Host"; }
        { type = "kernel"; key = "Kernel"; }
        { type = "uptime"; key = "Uptime"; }
        { type = "packages"; key = "Packages"; }
        { type = "shell"; key = "Shell"; }
        { type = "display"; key = "Display"; }
        { type = "wm"; key = "WM"; }
        { type = "theme"; key = "Theme"; }
        { type = "icons"; key = "Icons"; }
        { type = "cursor"; key = "Cursor"; }
        { type = "terminal"; key = "Terminal"; }
        { type = "terminalfont"; key = "Terminal Font"; }
        { type = "cpu"; key = "CPU"; }
        { type = "gpu"; key = "GPU"; }
        { type = "memory"; key = "Memory"; }
        { type = "swap"; key = "Swap"; }
        { type = "disk"; key = "Disk (/)"; }
        { type = "localip"; key = "Local IP"; }
        { type = "battery"; key = "Battery"; }
        { type = "locale"; key = "Locale"; }
        "separator"
        { type = "colors"; symbol = "block"; }
  ];
    };
  };

  # ========================================================================
  # GTK THEME - Gruvbox
  # ========================================================================
  gtk = {
    enable = true;
    theme = {
      name = "Gruvbox-Dark";
      package = pkgs.gruvbox-gtk-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "JetBrains Mono";
      size = 11;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # ========================================================================
  # QT THEME
  # ========================================================================
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  # ========================================================================
  # CURSOR THEME
  # ========================================================================
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # ========================================================================
  # PACKAGES
  # ========================================================================
  home.packages = [
    # Noctalia Shell is now managed by programs.noctalia-shell
    
    # Zen Browser (Flake üzerinden - Flatpak'a gerek yok)
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ] ++ (with pkgs; [

    # Clipboard & Screenshot (for Hyprland)
    wl-clipboard
    grim
    slurp
    swappy
    grimblast
    
    # Container tools
    # docker-compose - KALDIRILDI (packages.nix'te zaten var)
    podman-compose
    podman-tui
    kubectl
    kubernetes-helm
    k9s
    dive
    lazydocker
    ctop
    buildah
    skopeo
    
    # Wallpaper
    swww
    
    # Fonts
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    font-awesome
    
    # Icons
    papirus-icon-theme
    
    # Utilities
    btop           # Better htop
    eza            # Better ls
    fd             # Better find
    ripgrep        # Better grep
    fzf            # Fuzzy finder
    bat            # Better cat
    jq             # JSON processor
    yq             # YAML processor
    tree           # Directory tree
    unzip
    p7zip
    
    # Media
    mpv
    imv            # Image viewer
    mpvpaper       # Video wallpaper
    
    # Social
    discord
    
    # Development
    git-lfs
    lazygit
    
    # Browser - FIREFOX KALDIRILDI (Zen kullanılıyor)
    
    # Wayland utilities
    wtype          # For rofimoji
    wev            # Wayland event viewer
  ]);

  # ========================================================================
  # XDG
  # ========================================================================
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "app.zen_browser.zen.desktop";
        "x-scheme-handler/http" = "app.zen_browser.zen.desktop";
        "x-scheme-handler/https" = "app.zen_browser.zen.desktop";
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "image/gif" = "imv.desktop";
        "video/mp4" = "mpv.desktop";
        "video/mkv" = "mpv.desktop";
        "inode/directory" = "yazi.desktop";
      };
    };
  };

  # ========================================================================
  # FILES
  # ========================================================================
  home.file = {
    ".local/bin/wallpaper-cycle" = {
      source = ./scripts/wallpaper-cycle.sh;
      executable = true;
    };
  };

  # ========================================================================
  # DIRENV
  # ========================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ========================================================================
  # FZF
  # ========================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    colors = {
      # Gruvbox colors for fzf
      "bg+" = "#3c3836";
      "bg" = "#282828";
      "spinner" = "#fb4934";
      "hl" = "#83a598";
      "fg" = "#ebdbb2";
      "header" = "#8ec07c";
      "info" = "#fabd2f";
      "pointer" = "#fb4934";
      "marker" = "#fb4934";
      "fg+" = "#ebdbb2";
      "prompt" = "#fb4934";
      "hl+" = "#83a598";
    };
  };

  # ========================================================================
  # EZA (Better ls)
  # ========================================================================
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
  };

  # ========================================================================
  # BAT (Better cat)
  # ========================================================================
  programs.bat = {
    enable = true;
    config = {
      theme = "gruvbox-dark";
      pager = "less -FR";
    };
  };

  # ========================================================================
  # BTOP
  # ========================================================================
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "gruvbox_dark";
      theme_background = false;
      vim_keys = true;
    };
  };

  # btop config dosyası için force (backup çakışmasını önler)
  xdg.configFile."btop/btop.conf".force = true;
}
