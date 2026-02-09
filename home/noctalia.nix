{ config, pkgs, lib, noctalia, ... }:
{
  # ========================================================================
  # NOCTALIA SHELL - Modern Wayland Desktop Shell
  # ========================================================================
  # Declarative configuration with left sidebar bar layout
  # Features: Control Center, Workspaces, AudioVisualizer, Network widgets
  
  imports = [ noctalia.homeModules.default ];
  
  programs.noctalia-shell = {
    enable = true;
    
    # ====================================================================
    # SETTINGS
    # ====================================================================
    settings = {
      settingsVersion = 0;
      
      # ==================================================================
      # BAR CONFIGURATION - Left sidebar, comfortable size
      # ==================================================================
      bar = {
        barType = "simple";
        position = "left";  # Sol köşede bar
        monitors = [ ];
        density = "comfortable";  # Comfortable büyüklük
        showOutline = false;
        showCapsule = true;
        capsuleOpacity = 0;
        capsuleColorKey = "primary";  # Primary renk kullan
        backgroundOpacity = 0.93;
        useSeparateOpacity = false;
        floating = false;
        marginVertical = 4;
        marginHorizontal = 4;
        frameThickness = 10;
        frameRadius = 14;
        outerCorners = true;
        hideOnOverview = false;
        displayMode = "always_visible";
        autoHideDelay = 500;
        autoShowDelay = 150;
        
        # Widget Layout
        widgets = {
          # TOP: Control Center (distro logo ile) + Workspaces
          left = [
            { 
              id = "ControlCenter"; 
              useDistroLogo = true;  # Tema rengine uygun distro logosu
              colorize = true;       # Renklendirme aktif
              colorKey = "primary";  # Primary renk
            }
            { 
              id = "Workspace";
              hideUnoccupied = false;
              labelMode = "none";
            }
          ];
          
          # MIDDLE: AudioVisualizer (Cava based)
          center = [
            { id = "AudioVisualizer"; }
          ];
          
          # BOTTOM: Network widgets + Calendar
          right = [
            { id = "Network"; }      # WiFi
            { id = "Bluetooth"; }    # Bluetooth
            { id = "Volume"; }       # Volume control
            { 
              id = "Clock";          # Calendar için Clock widget
              formatHorizontal = "HH:mm";
              formatVertical = "HH\nmm";
              useMonospacedFont = true;
              usePrimaryColor = true;
            }
          ];
        };
        screenOverrides = [ ];
      };
      
      # ==================================================================
      # GENERAL SETTINGS
      # ==================================================================
      general = {
        avatarImage = "";
        dimmerOpacity = 0.2;
        showScreenCorners = false;
        forceBlackScreenCorners = false;
        scaleRatio = 1;
        radiusRatio = 1;
        iRadiusRatio = 1;
        boxRadiusRatio = 1;
        screenRadiusRatio = 1;
        animationSpeed = 1;
        animationDisabled = false;
        compactLockScreen = false;
        lockScreenAnimations = true;
        lockOnSuspend = true;
        showSessionButtonsOnLockScreen = true;
        enableShadows = true;
        shadowDirection = "bottom_right";
        language = "tr";  # Türkçe dil
        allowPanelsOnScreenWithoutBar = true;
        showChangelogOnStartup = false;
        telemetryEnabled = false;
      };
      
      # ==================================================================
      # UI SETTINGS - JetBrains Mono font
      # ==================================================================
      ui = {
        fontDefault = "JetBrainsMono Nerd Font";
        fontFixed = "JetBrainsMono Nerd Font";
        fontDefaultScale = 1;
        fontFixedScale = 1;
        tooltipsEnabled = true;
        panelBackgroundOpacity = 0.93;
        panelsAttachedToBar = true;
        settingsPanelMode = "attached";
        wifiDetailsViewMode = "grid";
        bluetoothDetailsViewMode = "grid";
        networkPanelView = "wifi";
        bluetoothHideUnnamedDevices = false;
        boxBorderEnabled = false;
      };
      
      # ==================================================================
      # LOCATION & CALENDAR
      # ==================================================================
      location = {
        name = "Istanbul";
        weatherEnabled = true;
        weatherShowEffects = true;
        useFahrenheit = false;
        use12hourFormat = false;
        showWeekNumberInCalendar = false;
        showCalendarEvents = true;
        showCalendarWeather = true;
        analogClockInCalendar = false;
        firstDayOfWeek = 1;  # Monday
        hideWeatherTimezone = false;
        hideWeatherCityName = false;
      };
      
      # ==================================================================
      # CONTROL CENTER
      # ==================================================================
      controlCenter = {
        position = "close_to_bar_button";
        diskPath = "/";
        shortcuts = {
          left = [
            { id = "Network"; }
            { id = "Bluetooth"; }
            { id = "WallpaperSelector"; }
            { id = "NoctaliaPerformance"; }
          ];
          right = [
            { id = "Notifications"; }
            { id = "PowerProfile"; }
            { id = "KeepAwake"; }
            { id = "NightLight"; }
          ];
        };
        cards = [
          { enabled = true; id = "profile-card"; }
          { enabled = true; id = "shortcuts-card"; }
          { enabled = true; id = "audio-card"; }
          { enabled = true; id = "brightness-card"; }
          { enabled = true; id = "weather-card"; }
          { enabled = true; id = "media-sysmon-card"; }
        ];
      };
      
      # ==================================================================
      # AUDIO SETTINGS (visualizer dahil)
      # ==================================================================
      audio = {
        volumeStep = 5;
        volumeOverdrive = false;
        cavaFrameRate = 30;
        visualizerType = "linear";
        mprisBlacklist = [ ];
        preferredPlayer = "";
        volumeFeedback = false;
      };
      
      # ==================================================================
      # COLOR SCHEMES - Gruvbox, Tokyo Night, Catppuccin, Tonal Spot
      # ==================================================================
      colorSchemes = {
        useWallpaperColors = false;
        predefinedScheme = "Gruvbox Dark";  # Default: Gruvbox
        darkMode = true;
        schedulingMode = "off";
        generationMethod = "tonal-spot";  # Tonal Spot generation method
        monitorForColors = "";
      };
      
      # ==================================================================
      # TEMPLATES - All applications enabled
      # ==================================================================
      templates = {
        activeTemplates = [
          "kitty"
          "hyprland"
          "gtk"
          "qt"
          "foot"
          "alacritty"
          "wezterm"
          "rofi"
          "wofi"
          "waybar"
          "dunst"
          "mako"
          "swaync"
          "fuzzel"
          "tofi"
          "swaylock"
          "hyprlock"
          "btop"
          "cava"
          "discord"
          "emacs"
          "ghostty"
          "helix"
          "hyprtoolkit"
          "kcolorscheme"
          "mango"
          "niri"
          "pywalfox"
          "spicetify"
          "sway"
          "telegram"
          "vicinae"
          "vscode"
          "walker"
          "yazi"
          "zathura"
          "zed"
          "zen"
        ];
        enableUserTheming = true;
      };
      
      # ==================================================================
      # DOCK
      # ==================================================================
      dock = {
        enabled = false;  # Bar kullandığımız için dock devre dışı
        position = "bottom";
        displayMode = "auto_hide";
        backgroundOpacity = 1;
        size = 1;
        onlySameOutput = true;
        monitors = [ ];
        pinnedApps = [ ];
        colorizeIcons = false;
      };
      
      # ==================================================================
      # WALLPAPER
      # ==================================================================
      wallpaper = {
        enabled = true;
        overviewEnabled = false;
        directory = "";
        setWallpaperOnAllMonitors = true;
        fillMode = "crop";
        automationEnabled = false;
        wallpaperChangeMode = "random";
        randomIntervalSec = 300;
        transitionDuration = 1500;
        transitionType = "random";
        panelPosition = "follow_bar";
      };
      
      # ==================================================================
      # APP LAUNCHER
      # ==================================================================
      appLauncher = {
        enableClipboardHistory = true;
        autoPasteClipboard = false;
        enableClipPreview = true;
        clipboardWrapText = true;
        clipboardWatchTextCommand = "wl-paste --type text --watch cliphist store";
        clipboardWatchImageCommand = "wl-paste --type image --watch cliphist store";
        position = "center";
        pinnedApps = [ ];
        sortByMostUsed = true;
        terminalCommand = "kitty -e";
        viewMode = "list";
        showCategories = true;
        iconMode = "tabler";
        enableSettingsSearch = true;
        enableWindowsSearch = true;
      };
      
      # ==================================================================
      # NOTIFICATIONS
      # ==================================================================
      notifications = {
        enabled = true;
        monitors = [ ];
        location = "top_right";
        overlayLayer = true;
        backgroundOpacity = 1;
        respectExpireTimeout = false;
        lowUrgencyDuration = 3;
        normalUrgencyDuration = 8;
        criticalUrgencyDuration = 15;
        saveToHistory = {
          low = true;
          normal = true;
          critical = true;
        };
        sounds = {
          enabled = false;
          volume = 0.5;
        };
        enableMediaToast = false;
        enableKeyboardLayoutToast = true;
        enableBatteryToast = true;
      };
      
      # ==================================================================
      # PLUGINS - AudioVisualizer enabled
      # ==================================================================
      plugins = {
        autoUpdate = true;
      };
    };
    
    # ====================================================================
    # PLUGINS CONFIGURATION
    # ====================================================================
    plugins = {
      sources = [
        {
          enabled = true;
          name = "Official Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
      ];
      states = {
        audiovisualizer = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
      };
      version = 1;
    };
    
    # ====================================================================
    # USER TEMPLATES - Write to non-conflicting paths
    # ====================================================================
    user-templates = {
      config = {
        # General template settings
      };
      templates = {
        # Kitty terminal theme - using include file instead of main config
        kitty = {
          input_path = "${config.home.homeDirectory}/.config/noctalia/templates/kitty.conf";
          output_path = "${config.home.homeDirectory}/.config/kitty/noctalia-theme.conf";
          post_hook = "killall -SIGUSR1 kitty";
        };
        # Starship prompt theme - using noctalia-specific file
        starship-noctalia = {
          input_path = "${config.home.homeDirectory}/.config/noctalia/templates/starship.toml";
          output_path = "${config.home.homeDirectory}/.config/noctalia/generated/starship.toml";
        };
        # GTK3 theme override - using noctalia-specific file
        gtk3-noctalia = {
          input_path = "${config.home.homeDirectory}/.config/noctalia/templates/gtk3.css";
          output_path = "${config.home.homeDirectory}/.config/noctalia/generated/gtk3.css";
        };
        # GTK4 theme override - using noctalia-specific file
        gtk4-noctalia = {
          input_path = "${config.home.homeDirectory}/.config/noctalia/templates/gtk4.css";
          output_path = "${config.home.homeDirectory}/.config/noctalia/generated/gtk4.css";
        };
        # Hyprlock theme - dinamik Noctalia renkleri
        hyprlock = {
          input_path = "${config.home.homeDirectory}/.config/noctalia/templates/hyprlock.conf";
          output_path = "${config.home.homeDirectory}/.config/hypr/hyprlock-theme.conf";
          post_hook = "";  # Hyprlock otomatik yükler
        };
      };
    };
  };

  # ========================================================================
  # TEMPLATE FILES - Source templates for Noctalia theme propagation
  # ========================================================================
  
  xdg.configFile."noctalia/templates/kitty.conf".text = ''
    # Noctalia Template - Kitty Theme
    foreground {{foreground}}
    background {{background}}
    selection_foreground {{foreground}}
    selection_background {{primary}}
    cursor {{primary}}
    cursor_text_color {{background}}
    url_color {{secondary}}
    active_border_color {{primary}}
    inactive_border_color {{outline}}
    bell_border_color {{error}}
    active_tab_foreground {{onPrimary}}
    active_tab_background {{primary}}
    inactive_tab_foreground {{onSurfaceVariant}}
    inactive_tab_background {{surfaceVariant}}
    color0 {{surface}}
    color8 {{outline}}
    color1 {{error}}
    color9 {{error}}
    color2 {{tertiary}}
    color10 {{tertiary}}
    color3 {{secondary}}
    color11 {{secondary}}
    color4 {{primary}}
    color12 {{primary}}
    color5 {{tertiary}}
    color13 {{tertiary}}
    color6 {{secondary}}
    color14 {{secondary}}
    color7 {{onSurface}}
    color15 {{onSurface}}
  '';
  
  xdg.configFile."noctalia/templates/starship.toml".text = ''
    # Noctalia Template - Starship Prompt
    format = """
    []({{primary}})\
    [ ](bg:{{primary}} fg:{{onPrimary}})\
    [](fg:{{primary}} bg:{{secondary}})\
    $directory\
    [](fg:{{secondary}} bg:{{tertiary}})\
    $git_branch\
    $git_status\
    [](fg:{{tertiary}} bg:{{surfaceVariant}})\
    $nodejs\
    $rust\
    $python\
    [](fg:{{surfaceVariant}} bg:{{surface}})\
    $time\
    [ ](fg:{{surface}})\
    $line_break$character"""

    [directory]
    style = "fg:{{onSecondary}} bg:{{secondary}}"
    format = "[ $path ]($style)"
    truncation_length = 3
    truncation_symbol = "…/"

    [git_branch]
    symbol = ""
    style = "bg:{{tertiary}}"
    format = "[[ $symbol $branch ](fg:{{onTertiary}} bg:{{tertiary}})]($style)"

    [git_status]
    style = "bg:{{tertiary}}"
    format = "[[($all_status$ahead_behind )](fg:{{onTertiary}} bg:{{tertiary}})]($style)"

    [nodejs]
    symbol = ""
    style = "bg:{{surfaceVariant}}"
    format = "[[ $symbol ($version) ](fg:{{onSurfaceVariant}} bg:{{surfaceVariant}})]($style)"

    [rust]
    symbol = ""
    style = "bg:{{surfaceVariant}}"
    format = "[[ $symbol ($version) ](fg:{{onSurfaceVariant}} bg:{{surfaceVariant}})]($style)"

    [python]
    symbol = ""
    style = "bg:{{surfaceVariant}}"
    format = "[[ $symbol ($version) ](fg:{{onSurfaceVariant}} bg:{{surfaceVariant}})]($style)"

    [time]
    disabled = false
    time_format = "%R"
    style = "bg:{{surface}}"
    format = "[[  $time ](fg:{{onSurface}} bg:{{surface}})]($style)"

    [character]
    success_symbol = "[❯](bold {{primary}})"
    error_symbol = "[❯](bold {{error}})"
  '';
  
  xdg.configFile."noctalia/templates/gtk3.css".text = ''
    /* Noctalia Template - GTK3 Colors */
    @define-color accent_color {{primary}};
    @define-color accent_bg_color {{primary}};
    @define-color window_bg_color {{background}};
    @define-color window_fg_color {{foreground}};
    @define-color headerbar_bg_color {{surfaceVariant}};
    @define-color headerbar_fg_color {{foreground}};
    @define-color card_bg_color {{surface}};
    @define-color card_fg_color {{foreground}};
    @define-color popover_bg_color {{surface}};
    @define-color popover_fg_color {{foreground}};
    @define-color view_bg_color {{background}};
    @define-color view_fg_color {{foreground}};
  '';
  
  xdg.configFile."noctalia/templates/gtk4.css".text = ''
    /* Noctalia Template - GTK4 Colors */
    @define-color accent_color {{primary}};
    @define-color accent_bg_color {{primary}};
    @define-color window_bg_color {{background}};
    @define-color window_fg_color {{foreground}};
    @define-color headerbar_bg_color {{surfaceVariant}};
    @define-color headerbar_fg_color {{foreground}};
    @define-color card_bg_color {{surface}};
    @define-color card_fg_color {{foreground}};
    @define-color popover_bg_color {{surface}};
    @define-color popover_fg_color {{foreground}};
    @define-color view_bg_color {{background}};
    @define-color view_fg_color {{foreground}};
  '';
  
  xdg.configFile."noctalia/templates/hyprlock.conf".text = ''
    # Noctalia Template - Hyprlock Theme Colors
    # Bu dosya Noctalia tarafından otomatik işlenir
    
    # Primary accent color
    $primary = rgb({{primary}})
    $onPrimary = rgb({{onPrimary}})
    
    # Surface colors
    $surface = rgb({{surface}})
    $surfaceVariant = rgb({{surfaceVariant}})
    $onSurface = rgb({{onSurface}})
    $onSurfaceVariant = rgb({{onSurfaceVariant}})
    
    # Background/Foreground
    $background = rgb({{background}})
    $foreground = rgb({{foreground}})
    
    # Semantic colors
    $error = rgb({{error}})
    $tertiary = rgb({{tertiary}})
    $secondary = rgb({{secondary}})
    $outline = rgb({{outline}})
  '';
  
  # Create generated directory for noctalia outputs
  xdg.configFile."noctalia/generated/.keep".text = "";
}
