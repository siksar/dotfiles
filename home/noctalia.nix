{ config, pkgs, lib, ... }:
{
  # ========================================================================
  # NOCTALIA SHELL - Modern Wayland Desktop Shell
  # ========================================================================
  
  imports = [ ../base/modules/noctalia-home.nix ];

  programs.noctalia-shell = {
    enable = true;
    package = pkgs.noctalia-shell;
    systemd.enable = true;

    settings = lib.mkForce {
      settingsVersion = 0; # Version reset to 0 as requested

      # ==================================================================
      # BAR CONFIGURATION
      # ==================================================================
      bar = {
        barType = "framed";
        position = "top"; # Bar moved to TOP
        monitors = [ ];
        density = "comfortable";
        showOutline = false;
        showCapsule = false; # Capsules hidden
        capsuleOpacity = 0;
        capsuleColorKey = "primary";
        backgroundOpacity = 0; # Fully transparent bar
        marginVertical = 4;
        marginHorizontal = 4;
        frameThickness = 10;
        frameRadius = 14;
        outerCorners = true;
        displayMode = "always_visible";
        autoHideDelay = 500;
        autoShowDelay = 150;

        widgets = {
          # LEFT
          left = [
            {
              id = "ControlCenter";
              useDistroLogo = true; # Only Distro Logo as requested
              colorize = true;
              colorKey = "tertiary";
            }
          ];

          # MIDDLE
          center = [
            { id = "Workspace"; hideUnoccupied = true; labelMode = "none"; colorKey = "tertiary"; }
          ];

          # RIGHT
          right = [
            { id = "Battery"; colorKey = "tertiary"; }
            { id = "KeyboardLayout"; colorKey = "tertiary"; }
            { id = "SystemMonitor"; colorKey = "tertiary"; }
          ];
        };
        screenOverrides = [ ];
      };

      # ==================================================================
      # GENERAL SETTINGS
      # ==================================================================
      general = {
        avatarImage = "/Pictures/logo.png";
        dimmerOpacity = 0.2;
        showScreenCorners = false;
        scaleRatio = 1;
        radiusRatio = 1;
        animationSpeed = 1;
        compactLockScreen = true;
        lockScreenAnimations = true;
        lockOnSuspend = true;
        enableShadows = true;
        shadowDirection = "bottom_right";
        language = "tr";
        allowPanelsOnScreenWithoutBar = true;
        telemetryEnabled = false;
      };

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
        boxBorderEnabled = false;
      };

      location = {
        name = "Sivas";
        weatherEnabled = true;
        weatherShowEffects = true;
        useFahrenheit = false;
        use12hourFormat = false;
        firstDayOfWeek = 1;
      };

      controlCenter = {
        position = "close_to_bar_button";
        diskPath = "/";
        shortcuts = {
          left = [
            { id = "Network"; }
            { id = "Bluetooth"; }
            { id = "WallpaperSelector"; }
          ];
          right = [
            { id = "Notifications"; }
            { id = "PowerProfile"; }
          ];
        };
        cards = [
          { enabled = true; id = "profile-card"; }
          { enabled = true; id = "shortcuts-card"; }
          { enabled = true; id = "audio-card"; }
          { enabled = true; id = "brightness-card"; }
        ];
      };

      audio = {
        volumeStep = 5;
        cavaFrameRate = 30;
        visualizerType = "linear";
        volumeFeedback = false;
      };

      colorSchemes = {
        useWallpaperColors = false;
        predefinedScheme = "Miasma";
        darkMode = true;
        generationMethod = "tonal-spot";
      };

      dock = { enabled = false; };

      wallpaper = {
        enabled = true;
        directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
        setWallpaperOnAllMonitors = true;
        fillMode = "crop";
        wallpaperChangeMode = "random";
        randomIntervalSec = 300;
        transitionDuration = 1500;
        transitionType = "random";
        panelPosition = "follow_bar";
      };

      appLauncher = {
        enableClipboardHistory = true;
        autoPasteClipboard = false;
        enableClipPreview = true;
        clipboardWrapText = true;
        terminalCommand = "kitty -e";
        viewMode = "list";
        showCategories = true;
        iconMode = "tabler";
      };

      notifications = {
        enabled = true;
        location = "top_right";
        overlayLayer = true;
        backgroundOpacity = 1;
      };

      plugins = {
        autoUpdate = false;
        version = 1;
      };

      desktopWidgets = {
        enabled = true;
        gridSnap = false;
        monitorWidgets = [
          {
            id = "Weather";
            position = "top_right";
            usePrimaryColor = true;
            backgroundOpacity = 0.0;
            margin = 20;
          }
        ];
      };
    };
  };
}
