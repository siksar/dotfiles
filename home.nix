{ config, pkgs, hyprland, noctalia, ... }:
{
  # ========================================================================
  # IMPORTS - Modular Home Configuration
  # ========================================================================
  imports = [
    ./home/hyprland.nix   # Hyprland user config
    ./home/noctalia.nix   # Noctalia Shell
    ./home/waybar.nix     # Waybar status bar
    ./home/rofi.nix       # Application launcher
    ./home/editors.nix    # VS Code, Neovim, Helix
    ./home/dunst.nix      # Notifications
    ./home/hyprlock.nix   # Lock screen & idle
    ./home/tui-media.nix  # Anime/Manga TUI apps
    ./home/wrappers.nix   # Tutorial/Examples for wrappers
    ./home/yazi.nix       # Modern TUI File Manager
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

  # ========================================================================
  # ZSH + STARSHIP
  # ========================================================================
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      # System
      ll = "ls -la --color=auto";
      la = "ls -A --color=auto";
      l = "ls -CF --color=auto";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      update = "cd /etc/nixos && sudo nix flake update && rebuild";
      cleanup = "sudo nix-collect-garbage -d && sudo nix-store --optimize";
      
      # Editors
      v = "nvim";
      vim = "nvim";
      hx = "helix";
      c = "code .";
      
      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline -10";
      
      # Apps
      lm = "lmstudio";
      
      # Hyprland
      hypr = "nvim ~/.config/hypr/hyprland.conf";
      
      # Power Control
      gaming = "sudo power-control gaming";
      turbo = "sudo power-control turbo";
      tasarruf = "sudo power-control saver";
      normal = "sudo power-control normal";
      auto-power = "sudo power-control auto";
    };
    
    initContent = ''
      # Auto fastfetch with image
      if [[ -z $FASTFETCH_RAN ]]; then
        export FASTFETCH_RAN=1
        fastfetch
      fi
      
      # Custom functions
      mkcd() { mkdir -p "$1" && cd "$1"; }
      
      # Extract any archive
      extract() {
        if [ -f "$1" ]; then
          case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.7z)      7z x "$1" ;;
            *)         echo "'$1' cannot be extracted" ;;
          esac
        else
          echo "'$1' is not a valid file"
        fi
      }
    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      format = "[󱄅](bold #5277c3) $directory$git_branch$git_status$character";
      
      character = {
        success_symbol = "[❯](bold #d65d0e)";  # Gruvbox orange
        error_symbol = "[❯](bold #cc241d)";    # Gruvbox red
      };
      
      directory = {
        style = "bold #d79921";  # Gruvbox yellow
        truncation_length = 3;
        truncate_to_repo = true;
      };
      
      git_branch = {
        symbol = " ";
        style = "bold #689d6a";  # Gruvbox aqua
      };
      
      git_status = {
        style = "bold #cc241d";  # Gruvbox red
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
      };
    };
  };

  # ========================================================================
  # KITTY TERMINAL - Gruvbox Theme with Image Support
  # ========================================================================
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    settings = {
      # Gruvbox Dark Hard
      background = "#1d2021";
      foreground = "#ebdbb2";
      
      # Cursor
      cursor = "#d65d0e";
      cursor_text_color = "#1d2021";
      
      # Selection
      selection_background = "#d65d0e";
      selection_foreground = "#1d2021";
      
      # Black
      color0 = "#282828";
      color8 = "#928374";
      
      # Red
      color1 = "#cc241d";
      color9 = "#fb4934";
      
      # Green
      color2 = "#98971a";
      color10 = "#b8bb26";
      
      # Yellow
      color3 = "#d79921";
      color11 = "#fabd2f";
      
      # Blue
      color4 = "#458588";
      color12 = "#83a598";
      
      # Magenta
      color5 = "#b16286";
      color13 = "#d3869b";
      
      # Cyan
      color6 = "#689d6a";
      color14 = "#8ec07c";
      
      # White
      color7 = "#a89984";
      color15 = "#ebdbb2";
      
      # UI
      background_opacity = "0.95";
      window_padding_width = 12;
      enable_audio_bell = false;
      cursor_blink_interval = 0;
      confirm_os_window_close = 0;
      
      # URL
      url_color = "#83a598";
      url_style = "curly";
      
      # Tab bar
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";
      active_tab_background = "#d65d0e";
      active_tab_foreground = "#1d2021";
      inactive_tab_background = "#3c3836";
      inactive_tab_foreground = "#a89984";
      
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
    # Noctalia Shell
    noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
  ] ++ (with pkgs; [

    # Clipboard & Screenshot (for Hyprland)
    wl-clipboard
    grim
    slurp
    swappy
    grimblast
    
    # Container tools
    docker-compose
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
    
    # Browser
    firefox
    
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
        "inode/directory" = "thunar.desktop";
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
}
