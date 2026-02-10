
{ config, pkgs, inputs, ... }:
{
  # ========================================================================
  # IMPORTS - Modular Home Configuration
  # ========================================================================
  imports = [
    ./home/hyprland.nix
    # ./home/noctalia.nix
    ./home/caelstia-shell.nix
    ./home/starship.nix
    ./home/editors.nix
    # ./home/hyprlock.nix # Replaced by Caelstia Lock
    ./home/tui-media.nix
    ./home/wrappers.nix
    ./home/yazi.nix
    ./home/niri.nix
    ./home/nushell.nix
    ./home/kitty.nix
    ./home/gaming.nix      # User gaming config

    ./home/fastfetch.nix    # System fetch tool
  ];
  # ========================================================================
  # HOME MANAGER BASE
  # ========================================================================
  home.stateVersion = "25.11";
  home.username = "zixar";
  home.homeDirectory = "/home/zixar";
  
  # Force overwrite for files that may conflict with backups
  xdg.configFile."hypr/hyprland.conf".force = true;
  
  home.sessionVariables = {
    SHELL = "${pkgs.nushell}/bin/nu";
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "kitty";
    BROWSER = "zen";
    
    # Wayland
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "gtk2";
    GDK_BACKEND = "wayland,x11";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    NIXOS_OZONE_WL = "1";
    XDG_SESSION_TYPE = "wayland";
    # XDG_CURRENT_DESKTOP = "Hyprland";
    # XDG_SESSION_DESKTOP = "Hyprland";
    
    # Theming
    GTK_THEME = "adw-gtk3-dark";
    ICON_THEME = "Papirus-Dark";
    
    # GPU
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __NV_PRIME_RENDER_OFFLOAD = "1";
    __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
    
    # Performance
    MESA_NO_ERROR = "1";
    __GL_THREADED_OPTIMIZATIONS = "1";
    
    # Nix
    NIX_BUILD_CORES = "4";
    NIX_MAX_JOBS = "8";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
  ];

  # ========================================================================
  # GIT
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "zixar";
        email = "halilbatuhanyilmaz@proton.me";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
      core.autocrlf = "input";
      push.autoSetupRemote = true;
      fetch.prune = true;
      diff.tool = "delta";
      difftool.delta.cmd = "delta \"$LOCAL\" \"$REMOTE\"";
      merge.tool = "nvimdiff";
      mergetool.nvimdiff.cmd = "nvim -d \"$LOCAL\" \"$REMOTE\" \"$MERGED\"";
      color.ui = true;
      credential.helper = "cache --timeout=3600";
    };
    lfs.enable = true;
  };
  
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      syntax-theme = "gruvbox-dark";
      line-numbers = true;
      side-by-side = false;
      navigate = true;
    };
  };

  # NOTE: Using Kitty as terminal (configured in home/kitty.nix)

  # ========================================================================
  # SYSTEM MONITORING & TOOLS
  # ========================================================================
  programs.broot = {
    enable = true;
    enableZshIntegration = false;
    enableNushellIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;
    enableNushellIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.atuin = {
    enable = true;
    enableZshIntegration = false;
    enableNushellIntegration = true;
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      sync_address = "https://api.atuin.sh";
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
      inline_height = 20;
    };
  };

  programs.bottom = {
    enable = true;
    settings = {
      flags = {
        avg_cpu = true;
        group_processes = true;
        temperature_type = "c";
        mem_as_value = true;
      };
      colors = {
        high_battery_color = "green";
        medium_battery_color = "yellow";
        low_battery_color = "red";
      };
    };
  };

  # ========================================================================
  # GTK THEME
  # ========================================================================
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
    };
    font = {
      name = "Noto Sans";
      size = 11;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-enable-animations = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
      gtk-enable-animations = true;
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
  home.packages = with pkgs; [
    # Browsers
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    
    # Rust Tools
    procs
    dust
    tokei
    sd
    jaq
    gitui
    ripgrep
    fd
    eza
    bat
    delta
    hyperfine
    bandwhich
    grex
    
    # Development
    gcc
    # clang # Removed to avoid conflict with gcc over /bin/cc
    cmake
    gnumake
    ninja
    pkg-config
    git-lfs
    lazygit
    gh
    
    # Containers
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
    
    # System
    nwg-look
    wl-clipboard
    cliphist
    qt6.qtwayland
    libsForQt5.qt5.qtwayland
    kdePackages.qtwayland
    grim
    slurp
    swappy
    grimblast
    hyprpicker
    
    # Wallpaper
    swww
    waypaper
    
    # Media
    mpv
    imv
    mpvpaper
    
    # Social
    discord
    telegram-desktop
    
    # Utilities
    unzip
    p7zip
    tree
    jq
    yq
    fzf
    tldr
    cheat
    
    # Input
    wtype
    wev
    
    # Monitoring
    btop
    iotop
    powertop
    
    # Gaming (user-level)
    mangohud
    goverlay
    vkbasalt
    
    # AI/ML
    ollama
  ] ++ lib.optionals (pkgs.stdenv.isx86_64) [
    # x86_64 specific packages
  ];

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
      templates = "${config.home.homeDirectory}/Templates";
      publicShare = "${config.home.homeDirectory}/Public";
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "app.zen_browser.zen.desktop";
        "x-scheme-handler/http" = "app.zen_browser.zen.desktop";
        "x-scheme-handler/https" = "app.zen_browser.zen.desktop";
        "x-scheme-handler/about" = "app.zen_browser.zen.desktop";
        "x-scheme-handler/unknown" = "app.zen_browser.zen.desktop";
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "image/gif" = "imv.desktop";
        "image/webp" = "imv.desktop";
        "video/mp4" = "mpv.desktop";
        "video/mkv" = "mpv.desktop";
        "video/webm" = "mpv.desktop";
        "inode/directory" = "yazi.desktop";
        "text/plain" = "nvim.desktop";
      };
    };
    configFile = {
      "user-dirs.locale".text = "en_US";
    };
  };

  # ========================================================================
  # FILES & CONFIG
  # ========================================================================
  home.file = {
    # Wallpaper cycle script
    ".local/bin/wallpaper-cycle" = {
      source = ./scripts/wallpaper-cycle.sh;
      executable = true;
    };
    
    # fastfetch config is in home/fastfetch.nix
    
    # Ollama config
    ".config/ollama/config.json".text = ''
      {
        "gpu": true,
        "num_gpu": 1,
        "num_thread": 8,
        "ctx_size": 4096
      }
    '';
  };

  # ========================================================================
  # DIRENV
  # ========================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = false;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
    silent = false;
  };

  # ========================================================================
  # FZF
  # ========================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    # enableNushellIntegration = true; # Not supported in current Home Manager
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
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--preview 'bat --color=always {}'"
    ];
  };

  # ========================================================================
  # EZA
  # ========================================================================
  programs.eza = {
    enable = true;
    enableZshIntegration = false;
    enableNushellIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };

  # ========================================================================
  # BAT
  # ========================================================================
  programs.bat = {
    enable = true;
    config = {
      theme = "gruvbox-dark";
      pager = "less -FR";
      style = "numbers,changes,header";
    };
    extraPackages = with pkgs.bat-extras; [
      batdiff
      batgrep
      batman
      batpipe
      batwatch
      prettybat
    ];
  };

  # LESS - using defaults
  programs.less.enable = true;

  # ========================================================================
  # MAN PAGES
  # ========================================================================
  programs.man = {
    enable = true;
    generateCaches = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        compression = true;
        controlMaster = "auto";
        controlPath = "~/.ssh/sockets/%r@%h-%p";
        controlPersist = "10m";
        serverAliveInterval = 60;
        hashKnownHosts = true;
        extraOptions = {
          AddKeysToAgent = "yes";
        };
      };
    };
  };

  # ========================================================================
  # GPG
  # ========================================================================
  programs.gpg = {
    enable = true;
    homedir = "${config.home.homeDirectory}/.gnupg";
    settings = {
      personal-digest-preferences = "SHA512";
      cert-digest-algo = "SHA512";
      default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
    };
  };

  # ========================================================================
  # SERVICES
  # ========================================================================
  services.ssh-agent.enable = true;
  services.gpg-agent = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = true;
    defaultCacheTtl = 3600;
    maxCacheTtl = 7200;
    pinentry.package = pkgs.pinentry-curses;
  };

  # ========================================================================
  # SHELL ALIASES
  # ========================================================================
  home.shellAliases = {
    # Nix
    rebuild = "sudo nixos-rebuild switch --flake .#nixos";
    rebuild-test = "sudo nixos-rebuild test --flake .#nixos";
    zixswitch = "home-manager switch --flake /etc/nixos#zixar -b backup";
    # NOTE: fullrebuild moved to nushell.nix as a custom command (def)
    # because nushell treats ';' in aliases as a command separator,
    # causing the second command to run on every shell startup!
    nix-gc = "nix-collect-garbage --delete-older-than 7d";
    
    # Editors
    v = "nvim";
    vim = "nvim";
    
    # CPU
    perf-run = "with-cores perf";
    eff-run = "with-cores eff";
    
    # Navigation
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    
    # Listing
    ls = "eza";
    ll = "eza -l";
    la = "eza -la";
    lt = "eza --tree";
    lla = "eza -la";
    
    # File operations
    cat = "bat";
    du = "dust";
    ps = "procs";
    find = "fd";
    grep = "rg";
    sed = "sd";
    
    # Git
    g = "git";
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gpl = "git pull";  # Changed from 'gl' to avoid conflict
    gl = "git log --oneline -10";  # Short git log
    gs = "git status";
    gd = "git diff";
    gco = "git checkout";
    gb = "git branch";
    
    # Config shortcuts
    hypr = "nvim ~/.config/hypr/hyprland.conf";
    
    # System
    top = "btop";
    htop = "btop";
    
    # Misc
    c = "clear";
    q = "exit";
  };

  # ========================================================================
  # DOCUMENTATION
  # ========================================================================
  home.file."README.md".text = ''
    # Home Manager Configuration
    
    ## Structure
    - `home/` - Modular configurations
    - `scripts/` - Custom scripts
    
    ## Key Bindings
    
    ### Terminal
    - `Ctrl+T` - FZF file search
    - `Ctrl+R` - FZF history search
    - `Alt+C` - FZF cd
    
    ### Applications
    - `Super+Return` - Terminal
    - `Super+Q` - Close window
    - `Super+M` - Exit Hyprland
    - `Super+E` - File manager
    - `Super+B` - Browser
    
    ## Tools
    
    ### File Management
    - `yazi` - TUI file manager
    - `eza` - Better ls
    - `bat` - Better cat
    - `fd` - Better find
    - `ripgrep` - Better grep
    
    ### System Monitoring
    - `btop` - System monitor
    - `bottom` - Process viewer
    - `fastfetch` - System info
    
    ### Development
    - `gitui` - TUI git
    - `lazygit` - Alternative git TUI
    - `delta` - Better git diff
    
    ## Customization
    Edit files in `~/.config/home-manager/` and run:
    ```bash
    home-manager switch --flake .#zixar
    ```
  '';
}
