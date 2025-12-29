{ config, pkgs, ... }:

{
  # ========================================================================
  # HOME MANAGER BASE
  # ========================================================================
  
  home.stateVersion = "25.11";
  home.username = "zixar";
  home.homeDirectory = "/home/zixar";

  # Set zsh as default shell
  home.sessionVariables = {
    SHELL = "${pkgs.zsh}/bin/zsh";
  };

  # ========================================================================
  # GIT
  # ========================================================================
  
  programs.git = {
    enable = true;
    userName = "zixar";
    userEmail = "halilbatuhanyilmaz@proton.me";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = false;
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
      ll = "ls -la";
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      update = "cd /etc/nixos && sudo nix flake update && rebuild";
      cleanup = "sudo nix-collect-garbage -d && sudo nix-store --optimize";
      lm = "lmstudio";
    };
    
    initExtra = ''
      # Auto fastfetch
      if [[ -z $FASTFETCH_RAN ]]; then
        export FASTFETCH_RAN=1
        fastfetch
      fi
      
      # Custom functions
      mkcd() { mkdir -p "$1" && cd "$1"; }
    '';
  };

  # Starship prompt (princess theme)
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    
    settings = {
      format = "$directory$git_branch$git_status$character";
      
      character = {
        success_symbol = "[🌹](bold #e88388)";
        error_symbol = "[✗](bold #e88388)";
      };
      
      directory = {
        style = "bold #f5a97f";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      
      git_branch = {
        symbol = "🌿 ";
        style = "bold #90a090";
      };
      
      git_status = {
        style = "bold #e88388";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
      };
    };
  };

  # ========================================================================
  # KITTY TERMINAL
  # ========================================================================
  
  programs.kitty = {
    enable = true;
    
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    
    settings = {
      # Princess theme colors
      background = "#1e1e2e";
      foreground = "#cad3f5";
      
      cursor = "#e88388";
      cursor_text_color = "#2e2a3d";
      
      selection_background = "#e88388";
      selection_foreground = "#2e2a3d";
      
      # Black
      color0 = "#1a1820";
      color8 = "#3d3846";
      
      # Red (rose)
      color1 = "#e88388";
      color9 = "#f5c2c7";
      
      # Green
      color2 = "#90a090";
      color10 = "#b0c0b0";
      
      # Yellow (sunset)
      color3 = "#f5a97f";
      color11 = "#ffc9a0";
      
      # Blue (lavender)
      color4 = "#a8b4d8";
      color12 = "#c8d4f8";
      
      # Magenta (dusty pink)
      color5 = "#d4b5d4";
      color13 = "#f4d5f4";
      
      # Cyan
      color6 = "#a0c0c0";
      color14 = "#c0e0e0";
      
      # White (cream)
      color7 = "#f4e8d8";
      color15 = "#ffffff";
      
      # Window
      background_opacity = "0.92";
      window_padding_width = 12;
      
      # No bell
      enable_audio_bell = false;
      
      # Cursor
      cursor_blink_interval = 0;
    };
  };

  # ========================================================================
  # FASTFETCH
  # ========================================================================
  
  programs.fastfetch = {
    enable = true;
    
    settings = {
      logo = {
        type = "kitty-direct";
        source = "~/.config/fastfetch/nixos-logo.png";
        width = 25;
        height = 12;
        padding = {
          top = 1;
        };
      };
      
      display = {
        separator = " 🌹 ";
        color = {
          keys = "#e88388";
          title = "#f5a97f";
        };
      };
      
      modules = [
        {
          type = "title";
          format = "{user-name}@{host-name}";
        }
        "separator"
        {
          type = "os";
          key = "OS";
        }
        {
          type = "host";
          key = "Host";
        }
        {
          type = "kernel";
          key = "Kernel";
        }
        {
          type = "uptime";
          key = "Uptime";
        }
        {
          type = "packages";
          key = "Packages";
        }
        {
          type = "shell";
          key = "Shell";
        }
        "separator"
        {
          type = "display";
          key = "Display";
        }
        {
          type = "wm";
          key = "WM";
        }
        {
          type = "terminal";
          key = "Terminal";
        }
        {
          type = "terminalfont";
          key = "Font";
        }
        "separator"
        {
          type = "cpu";
          key = "CPU";
        }
        {
          type = "gpu";
          key = "GPU";
        }
        {
          type = "memory";
          key = "Memory";
        }
        {
          type = "disk";
          key = "Disk (/)";
        }
        {
          type = "localip";
          key = "Local IP";
        }
        "separator"
        {
          type = "locale";
          key = "Locale";
        }
      ];
    };
  };

  # ========================================================================
  # ANYRUN - Modern Application Launcher
  # ========================================================================
  
  programs.anyrun = {
    enable = true;
    
    config = {
      # Position & Size
      x = { fraction = 0.5; };
      y = { fraction = 0.3; };
      width = { fraction = 0.4; };
      height = { absolute = 0; };
      
      # Settings
      hideIcons = false;
      ignoreExclusiveZones = false;
      layer = "overlay";
      hidePluginInfo = false;
      closeOnClick = true;
      showResultsImmediately = true;
      maxEntries = 8;
      
      # Plugins
      plugins = [
       # "${pkgs.anyrun}/lib/libapplications.so"
        "${pkgs.anyrun}/lib/libsymbols.so"
        "${pkgs.anyrun}/lib/libshell.so"
      ];
    };
    
    # Princess Theme Styling
    extraCss = ''
      * {
        all: unset;
        font-family: "JetBrainsMono Nerd Font";
        font-size: 14px;
      }
      
      #window {
        background: rgba(46, 42, 61, 0.95);
        border: 3px solid #e88388;
        border-radius: 16px;
        padding: 20px;
      }
      
      #entry {
        background: rgba(58, 52, 71, 0.8);
        color: #f4e8d8;
        border: 2px solid #f5a97f;
        border-radius: 12px;
        padding: 12px 16px;
        margin-bottom: 16px;
      }
      
      #entry:focus {
        border-color: #e88388;
        box-shadow: 0 0 8px rgba(232, 131, 136, 0.4);
      }
      
      #match {
        padding: 8px 12px;
        margin: 4px 0;
        border-radius: 8px;
        transition: all 0.2s;
      }
      
      #match:hover {
        background: rgba(232, 131, 136, 0.2);
      }
      
      #match:selected {
        background: linear-gradient(135deg, rgba(232, 131, 136, 0.4), rgba(245, 169, 127, 0.4));
        border-left: 4px solid #e88388;
      }
      
      #match-title {
        color: #f4e8d8;
        font-weight: 600;
      }
      
      #match-desc {
        color: #a6adc8;
        font-size: 12px;
        margin-top: 4px;
      }
      
      #plugin {
        color: #f5a97f;
        font-size: 11px;
        font-weight: 500;
        margin-right: 8px;
      }
    '';
    
    # Plugin configurations
    extraConfigFiles = {
      "applications.ron".text = ''
        Config(
          desktop_actions: false,
          max_entries: 8,
          terminal: Some("kitty"),
        )
      '';
      
      "symbols.ron".text = ''
        Config(
          prefix: "::",
          symbols: {
            "heart": "❤️",
            "rose": "🌹",
            "star": "⭐",
            "fire": "🔥",
            "rocket": "🚀",
            "check": "✅",
            "cross": "❌",
            "smile": "😊",
            "crown": "👑",
            "sparkle": "✨",
            "arrow": "→",
            "dash": "—",
            "pi": "π",
          },
          max_entries: 8,
        )
      '';
      
      "shell.ron".text = ''
        Config(
          prefix: "!",
          shell: Some("zsh"),
          max_entries: 5,
        )
      '';
    };
  };

  # ========================================================================
  # GTK THEME
  # ========================================================================
  
  gtk = {
    enable = true;
    
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # ========================================================================
  # PACKAGES
  # ========================================================================
  
  home.packages = with pkgs; [
    # Wayland utilities
    wl-clipboard
    grim
    slurp
    swappy
    grimblast
    
    # Wallpaper
    swww
    
    # Fonts
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    font-awesome
    
    # Icon theme
    papirus-icon-theme
  ];
}
