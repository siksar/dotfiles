{ config, pkgs, ... }:

{
  # ========================================================================
  # HOME MANAGER BASE
  # ========================================================================
  
  home.stateVersion = "25.11";
  home.username = "zixar";
  home.homeDirectory = "/home/zixar";

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
    
    # Auto fastfetch on terminal start
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
      
      # Princess prompt colors
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
      background = "#2e2a3d";
      foreground = "#f4e8d8";
      
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
        width = 30;
        height = 15;
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
          type = "kernel";
          key = "Kernel";
        }
        {
          type = "packages";
          key = "Packages";
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
          type = "shell";
          key = "Shell";
        }
        "separator"
        {
          type = "uptime";
          key = "Uptime";
        }
        {
          type = "memory";
          key = "Memory";
        }
      ];
    };
  };

  # ========================================================================
  # ROFI
  # ========================================================================
  
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    terminal = "\${pkgs.kitty}/bin/kitty";
    
    # Theme will be set manually at ~/.config/hyprland/rofi/
    
    extraConfig = {
      modi = "drun,emoji,window";
      show-icons = true;
      icon-theme = "Papirus";
      drun-display-format = "{name}";
      disable-history = false;
      display-drun = "  Apps";
      display-window = " 󰕰 Windows";
      display-emoji = " 󰞅 Emoji";
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
  # HYPRLAND
  # ========================================================================
  
  wayland.windowManager.hyprland = {
    enable = true;
    
    # Config will be at ~/.config/hypr/hyprland.conf (manual)
    extraConfig = ''
      source = ~/.config/hypr/hyprland.conf
    '';
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
    
    # Emoji picker
    rofimoji
    
    # Fonts - FIXED SYNTAX
    jetbrains-mono
    nerd-fonts.jetbrains-mono
    font-awesome
    
    # Icon theme
    papirus-icon-theme
  ];
}
