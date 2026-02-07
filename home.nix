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
    ./home/editors.nix    # Helix
    ./home/hyprlock.nix   # Lock screen & idle
    ./home/tui-media.nix  # Anime/Manga TUI apps
    ./home/wrappers.nix   # Tutorial/Examples for wrappers
    ./home/yazi.nix       # Modern TUI File Manager
    ./home/niri.nix       # Niri (Rust) WM
    ./home/nushell.nix    # Nushell
    ./home/kitty.nix      # Kitty Terminal
  ];

  # ========================================================================
  # HOME MANAGER BASE
  # ========================================================================
  home.stateVersion = "25.11";
  home.username = "zixar";
  home.homeDirectory = "/home/zixar";
  home.sessionVariables = {
    SHELL = "${pkgs.nushell}/bin/nu";
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "kitty";
    BROWSER = "zen";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
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
      core.editor = "hx";
    };
  };
  
  # Delta - Better git diff (Rust based)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "gruvbox-dark";
      line-numbers = true;
    };
  };

  # ========================================================================
  # ALACRITTY - Rust Term (Fastest) - Kitty Alternatifi
  # ========================================================================
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        padding = { x = 12; y = 12; };
        opacity = 0.95;
        title = "Alacritty";
        dynamic_title = true;
      };
      
      font = {
        normal = { family = "JetBrainsMono Nerd Font"; style = "Regular"; };
        bold = { family = "JetBrainsMono Nerd Font"; style = "Bold"; };
        italic = { family = "JetBrainsMono Nerd Font"; style = "Italic"; };
        size = 12.0;
      };
      
      # Tokyo Night Theme
      colors = {
        primary = {
          background = "#1a1b26";
          foreground = "#a9b1d6";
        };
        normal = {
          black = "#414868";
          red = "#f7768e";
          green = "#73daca";
          yellow = "#e0af68";
          blue = "#7aa2f7";
          magenta = "#bb9af7";
          cyan = "#7dcfff";
          white = "#c0caf5";
        };
        bright = {
          black = "#414868";
          red = "#f7768e";
          green = "#73daca";
          yellow = "#e0af68";
          blue = "#7aa2f7";
          magenta = "#bb9af7";
          cyan = "#7dcfff";
          white = "#c0caf5";
        };
      };
    };
  };

  # ========================================================================
  # SYSTEM MONITORING & TOOLS (RUST POWER)
  # ========================================================================
  
  # Procs - Modern ps replacement
  programs.broot = {
    enable = true;
    enableZshIntegration = true;
  };

  # Zoxide - Smarter cd
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  # Atuin - Magical Shell History
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
    };
  };

  # Bottom - Rust System Monitor (Btop Replacement)
  programs.bottom = {
    enable = true;
    settings = {
      flags = {
        avg_cpu = true;
        group_processes = true;
        temperature_type = "c";
      };
      colors = {
        high_battery_color = "green";
        medium_battery_color = "yellow";
        low_battery_color = "red";
      };
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
    # Noctalia Shell
    
    # Portals
    # Portals - Handled by modules/desktop.nix
    # pkgs.xdg-desktop-portal-gnome
    # pkgs.xdg-desktop-portal-gtk
    
    
    # Zen Browser
    zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    
    # Rust Replacements
    pkgs.macchina      # Fastfetch alt (Rust)
    pkgs.procs         # ps alt (Rust)
    pkgs.dust          # du alt (Rust)
    pkgs.tokei         # code stats (Rust)
    pkgs.sd            # sed alt (Rust)
    pkgs.jaq           # jq alt (Rust-like)
    pkgs.gitui         # lazygit alt (Rust) - optional but nice
    pkgs.ripgrep       # grep alt (Rust)
    pkgs.fd            # find alt (Rust)
    
  ] ++ (with pkgs; [
    # Niri Startup Script
    # Niri Session Script Removed (Using systemd services)
    # (writeShellScriptBin "zixar-niri-session" ...

    # Wayland tools
    wl-clipboard
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    grim
    slurp
    swappy
    grimblast
    
    # Container tools
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
    # btop - Removed (Bottom used)
    # fastfetch - Removed (Macchina used)
    # fzf - Keep (Standard)
    # unzip/p7zip - Keep
    unzip
    p7zip
    tree
    jq
    yq
    
    # Media
    mpv
    imv
    mpvpaper
    
    # Social
    discord
    
    # Development
    git-lfs
    lazygit # Keeping as fallback or if gitui not enough
    
    wtype
    wev
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
  # FILES & CONFIG
  # ========================================================================
  home.file = {
    ".local/bin/wallpaper-cycle" = {
      source = ./scripts/wallpaper-cycle.sh;
      executable = true;
    };
    
    # Macchina Config - Fastfetch-like appearance
    ".config/macchina/macchina.toml".text = ''
      theme = "ZixarNight"
      interface = "DefaultAscii"
      show = [
        "Host",
        "Machine",
        "Kernel",
        "Distribution",
        "DE",
        "WM",
        "Shell",
        "Terminal",
        "Uptime",
        "Processor",
        "ProcessorUsage",
        "Memory",
        "GPU",
        "Battery"
      ]
      
      long_shell = false
      long_uptime = true
      long_kernel = false
      current_shell = true
      physical_cores = false
    '';

    # Macchina ZixarNight Theme - Tokyo Night inspired
    ".config/macchina/themes/ZixarNight.toml".text = ''
      # Spacing and padding
      spacing = 2
      padding = 0
      hide_ascii = false
      separator = "  "
      key_color = "Blue"
      separator_color = "Magenta"
      
      # Palette section for custom colors
      [palette]
      type = "Dark"
      glyph = ""
      
      # Custom ASCII art colors
      [custom_ascii]
      color = "Blue"

      # Bar configuration  
      [bar]
      glyph = "●"
      symbol_open = "["
      symbol_close = "]"
      visible = true
    '';

    # Rio Config Removed
    # ".config/rio/config.toml".source = ./home/rio-config.toml;
  };

  # ========================================================================
  # DIRENV (Go, but essential for Nix)
  # ========================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # ========================================================================
  # FZF (Go)
  # ========================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    colors = {
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
  # EZA (Better ls - Rust)
  # ========================================================================
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
  };

  # ========================================================================
  # BAT (Better cat - Rust)
  # ========================================================================
  programs.bat = {
    enable = true;
    config = {
      theme = "gruvbox-dark";
      pager = "less -FR";
    };
  };

  # ========================================================================
  # SYSTEMD SERVICES
  # ========================================================================
  # ========================================================================
  # SYSTEMD SERVICES - Handled by modules/desktop.nix or specific home modules
  # ========================================================================
}
