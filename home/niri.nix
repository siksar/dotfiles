{ config, pkgs, lib, ... }:
let
  # ========================================================================
  # WLR-WHICH-KEY MENU BUILDER (VimJoyer vid74 pattern)
  # ========================================================================
  # Creates named menus that can be triggered via keybinds.
  # Each menu pops up a which-key style overlay showing available actions.
  mkMenu = name: menu: let
    configFile = pkgs.writeText "wlr-which-key-${name}.yaml" (lib.generators.toYAML {} {
      font = "JetBrainsMono Nerd Font 13";
      background = "#222222ee";
      color = "#c2c2b0";
      border = "#c9a554";
      separator = " → ";
      border_width = 0;
      corner_r = 12;
      padding = 16;
      anchor = "center";
      margin_bottom = 0;
      margin_top = 0;
      margin_left = 0;
      margin_right = 0;
      inherit menu;
    });
  in pkgs.writeShellScriptBin "wlr-menu-${name}" ''
    exec ${lib.getExe pkgs.wlr-which-key} ${configFile}
  '';

  # ========================================================================
  # MENU DEFINITIONS
  # ========================================================================

  # 🚀 App Launcher Menu (Mod+D)
  appMenu = mkMenu "apps" [
    { key = "b"; desc = "Brave Browser"; cmd = "brave"; }
    { key = "z"; desc = "Zen Browser"; cmd = "zen"; }
    { key = "d"; desc = "Discord"; cmd = "discord"; }
    { key = "t"; desc = "Telegram"; cmd = "telegram-desktop"; }
    { key = "s"; desc = "Spotify (Web)"; cmd = "zen https://open.spotify.com"; }
    { key = "o"; desc = "OBS Studio"; cmd = "obs"; }
    { key = "p"; desc = "Pavucontrol"; cmd = "pavucontrol"; }
    { key = "g"; desc = "GIMP"; cmd = "gimp"; }
    { key = "m"; desc = "mpv (Last Video)"; cmd = "mpv --player-operation-mode=pseudo-gui"; }
  ];

  # 📁 File/Editor Menu (Mod+O)
  fileMenu = mkMenu "files" [
    { key = "f"; desc = "Yazi File Manager"; cmd = "kitty -e yazi"; }
    { key = "n"; desc = "Neovim"; cmd = "kitty -e nvim"; }
    { key = "r"; desc = "Neovim /"; cmd = "kitty -e nvim /"; }
    { key = "c"; desc = "NixOS Config"; cmd = "kitty -e nvim /etc/nixos"; }
    { key = "h"; desc = "Home Dir"; cmd = "kitty -e yazi /home/zixar"; }
    { key = "d"; desc = "Downloads"; cmd = "kitty -e yazi /home/zixar/Downloads"; }
  ];

  # 🖥️ System Menu (Mod+S)
  systemMenu = mkMenu "system" [
    { key = "m"; desc = " System Monitor"; cmd = "kitty -e btop"; }
    { key = "n"; desc = " Network Manager"; cmd = "kitty -e nmtui"; }
    { key = "b"; desc = " Bluetooth"; cmd = "blueman-manager"; }
    { key = "v"; desc = " Volume Control"; cmd = "pavucontrol"; }
    { key = "w"; desc = " WiFi Settings"; cmd = "caelestia-shell ipc call controlCenter toggle"; }
    { key = "p"; desc = " Power Profile"; cmd = "caelestia-shell ipc call powerProfile toggle"; }
  ];

  # 🎮 Gaming Menu (Mod+G)
  gamingMenu = mkMenu "gaming" [
    { key = "s"; desc = " Steam"; cmd = "gamemoderun steam"; }
    { key = "l"; desc = " Lutris"; cmd = "gamemoderun lutris"; }
    { key = "h"; desc = " Heroic"; cmd = "gamemoderun heroic"; }
    { key = "p"; desc = " Prism Launcher"; cmd = "prismlauncher"; }
    { key = "m"; desc = " MangoHud Config"; cmd = "goverlay"; }
    { key = "g"; desc = " GPU Monitor"; cmd = "kitty -e nvtop"; }
  ];

  # ⚡ Power Menu (Mod+Escape)
  powerMenu = mkMenu "power" [
    { key = "l"; desc = " Lock Screen"; cmd = "caelestia-shell ipc call lockScreen lock"; }
    { key = "s"; desc = " Suspend"; cmd = "systemctl suspend"; }
    { key = "h"; desc = " Hibernate"; cmd = "systemctl hibernate"; }
    { key = "r"; desc = " Reboot"; cmd = "systemctl reboot"; }
    { key = "p"; desc = " Power Off"; cmd = "systemctl poweroff"; }
    { key = "e"; desc = " Exit Niri"; cmd = "niri msg action quit"; }
  ];

  # 📸 Screenshot Menu (Mod+P)
  screenshotMenu = mkMenu "screenshot" [
    { key = "s"; desc = " Select Area → Clipboard"; cmd = "grim -g \"$(slurp)\" - | wl-copy"; }
    { key = "f"; desc = " Full Screen → Clipboard"; cmd = "grim - | wl-copy"; }
    { key = "a"; desc = " Area → Save File"; cmd = "grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"; }
    { key = "w"; desc = " Active Window"; cmd = "grim -g \"$(niri msg --json focused-window | jq -r '.geometry | \"\\(.x),\\(.y) \\(.width)x\\(.height)\"')\" - | wl-copy"; }
    { key = "e"; desc = " Edit (Swappy)"; cmd = "grim -g \"$(slurp)\" - | swappy -f -"; }
    { key = "c"; desc = " Color Picker"; cmd = "hyprpicker -a"; }
  ];

  # 🔧 Niri Layout Menu (Mod+W)
  layoutMenu = mkMenu "layout" [
    { key = "1"; desc = "1/3 Width"; cmd = "niri msg action set-column-width 33%"; }
    { key = "2"; desc = "1/2 Width"; cmd = "niri msg action set-column-width 50%"; }
    { key = "3"; desc = "2/3 Width"; cmd = "niri msg action set-column-width 67%"; }
    { key = "4"; desc = "Full Width"; cmd = "niri msg action set-column-width 100%"; }
    { key = "c"; desc = "Center Column"; cmd = "niri msg action center-column"; }
    { key = "e"; desc = "Equal Widths"; cmd = "niri msg action reset-window-height"; }
    { key = "m"; desc = "Maximize"; cmd = "niri msg action maximize-column"; }
    { key = "f"; desc = "Fullscreen"; cmd = "niri msg action fullscreen-window"; }
  ];

  # 🎨 Noctalia Menu (Mod+N)
  noctaliaMenu = mkMenu "noctalia" [
    { key = "l"; desc = " Launcher"; cmd = "noctalia-shell ipc call launcher toggle"; }
    { key = "c"; desc = " Control Center"; cmd = "noctalia-shell ipc call controlCenter toggle"; }
    { key = "w"; desc = " Wallpaper Random"; cmd = "noctalia-shell ipc call wallpaper random"; }
    { key = "b"; desc = " Bluetooth Panel"; cmd = "noctalia-shell ipc call bluetooth togglePanel"; }
    { key = "n"; desc = " Notifications"; cmd = "noctalia-shell ipc call notifications showHistory"; }
    { key = "x"; desc = " Clear Notifications"; cmd = "noctalia-shell ipc call notifications closeAll"; }
    { key = "s"; desc = " Session Menu"; cmd = "noctalia-shell ipc call sessionMenu show"; }
  ];

in
{
  # ========================================================================
  # NIRI CONFIGURATION (KDL Format) - Full Setup
  # ========================================================================
  
  xdg.configFile."niri/config.kdl".text = ''
    // ====================================================================
    // INPUT
    // ====================================================================
    input {
        keyboard {
            xkb {
                layout "us"
            }
            repeat-delay 300
            repeat-rate 50
        }
        touchpad {
            tap
            natural-scroll
            dwt       // disable while typing
            accel-speed 0.3
        }
        mouse {
            accel-speed 0.0
        }
        // Warp mouse to focused window
        warp-mouse-to-focus
        // Focus follows mouse
        focus-follows-mouse max-scroll-amount="0%"
    }

    // ====================================================================
    // OUTPUT (Display)
    // ====================================================================
    output "eDP-1" {
        scale 1.0
        position x=0 y=0
        // variable-refresh-rate  // uncomment for VRR if supported
    }

    // ====================================================================
    // LAYOUT
    // ====================================================================
    layout {
        gaps 12
        center-focused-column "never"
        
        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }
        
        default-column-width { proportion 0.5; }
        
        focus-ring {
            width 0
            off
            active-color "#c9a55400"
            inactive-color "#22222200"
        }
        
        border {
            off
        }
        
        // Struts (reserved screen space)
        // struts { left 48; }  // Uncomment if caelestia bar needs reserved space
    }

    // ====================================================================
    // APPEARANCE
    // ====================================================================
    prefer-no-csd
    
    // Screenshots path
    screenshot-path "~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png"
    
    // Animations
    animations {
        // Smooth workspace switching
        workspace-switch {
            spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
        }
        window-open {
            duration-ms 200
            curve "ease-out-expo"
        }
        window-close {
            duration-ms 150
            curve "ease-out-quad"
        }
        horizontal-view-movement {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        window-movement {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        window-resize {
            spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        }
        config-notification-open-close {
            spring damping-ratio=0.6 stiffness=1000 epsilon=0.001
        }
    }

    // ====================================================================
    // WINDOW RULES
    // ====================================================================
    window-rule {
        draw-border-with-background false
        geometry-corner-radius 10
        clip-to-geometry true
        opacity 0.93
    }
    
    // Float specific windows
    window-rule {
        match app-id=r#"pavucontrol"#
        open-floating true
    }
    window-rule {
        match app-id=r#"blueman-manager"#
        open-floating true
    }
    window-rule {
        match app-id=r#"nwg-look"#
        open-floating true
    }
    window-rule {
        match app-id=r#"wlr-which-key"#
        open-floating true
    }
    
    // Opacity for terminals
    window-rule {
        match app-id=r#"kitty"#
        opacity 0.95
    }

    // ====================================================================
    // ENVIRONMENT VARIABLES
    // ====================================================================
    // Critical for GTK/Noctalia to work properly in Niri
    environment {
        DISPLAY ":0"
        WAYLAND_DISPLAY "wayland-1"
        XDG_SESSION_TYPE "wayland"
        XDG_CURRENT_DESKTOP "niri"
        XDG_SESSION_DESKTOP "niri"
        GDK_BACKEND "wayland,x11"
        QT_QPA_PLATFORM "wayland;xcb"
        GTK_THEME "adw-gtk3-dark"
        CLUTTER_BACKEND "wayland"
        SDL_VIDEODRIVER "wayland"
        MOZ_ENABLE_WAYLAND "1"
        NIXOS_OZONE_WL "1"
        // Fix for Caelstia GTK warnings in Niri
        GTK_DEBUG ""
        // Cursor
        XCURSOR_THEME "Adwaita"
        XCURSOR_SIZE "24"
    }

    // ====================================================================
    // STARTUP APPLICATIONS
    // ====================================================================
    spawn-at-startup "xwayland-satellite"
    spawn-at-startup "swww-daemon"
    spawn-at-startup "wl-paste" "--type" "text" "--watch" "cliphist" "store"
    spawn-at-startup "wl-paste" "--type" "image" "--watch" "cliphist" "store"
    // Noctalia Shell - delayed start to ensure Wayland socket is ready
    // DISPLAY and GDK_BACKEND set in environment block above
    spawn-at-startup "sh" "-c" "systemctl --user stop dunst mako swaync; pkill -f dunst; pkill -f mako; pkill -f swaync; sleep 2 && noctalia-shell"

    // ====================================================================
    // HOTKEY OVERLAY (built-in which-key, Mod+Shift+/)
    // ====================================================================
    hotkey-overlay {
        skip-at-startup
    }

    // ====================================================================
    // KEYBINDINGS
    // ====================================================================
    binds {
        // ============================================================
        // TERMINAL & DIRECT APPS
        // ============================================================
        Mod+Return { spawn "kitty"; }
        Mod+E { spawn "kitty" "-e" "yazi"; }
        Mod+R { spawn "kitty" "-e" "nvim" "/"; }
        Mod+B { spawn "brave"; }
        Mod+V { spawn "zen"; }

        // ============================================================
        // WLR-WHICH-KEY MENUS (VimJoyer style)
        // One key to open a categorized menu overlay
        // ============================================================
        Mod+D { spawn "${lib.getExe appMenu}"; }
        Mod+O { spawn "${lib.getExe fileMenu}"; }
        Mod+S { spawn "${lib.getExe systemMenu}"; }
        Mod+G { spawn "${lib.getExe gamingMenu}"; }
        Mod+P { spawn "${lib.getExe screenshotMenu}"; }
        Mod+W { spawn "${lib.getExe layoutMenu}"; }
        Mod+N { spawn "${lib.getExe noctaliaMenu}"; }
        Mod+Escape { spawn "${lib.getExe powerMenu}"; }

        // ============================================================
        // NOCTALIA INTEGRATION (Direct shortcuts)
        // ============================================================
        Mod+Z { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Mod+Tab { spawn "noctalia-shell" "ipc" "call" "launcher" "toggle"; }
        Mod+X { spawn "noctalia-shell" "ipc" "call" "controlCenter" "toggle"; }

        // ============================================================
        // WINDOW MANAGEMENT
        // ============================================================
        Mod+Q { close-window; }
        
        // Focus (Arrow keys)
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up    { focus-window-up; }
        Mod+Down  { focus-window-down; }
        
        // Focus (Vim keys)
        Mod+H { focus-column-left; }
        Mod+L { focus-column-right; }
        Mod+K { focus-window-up; }
        Mod+J { focus-window-down; }

        // Move windows (Arrow keys)
        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        Mod+Shift+Up    { move-window-up; }
        Mod+Shift+Down  { move-window-down; }
        
        // Move windows (Vim keys)
        Mod+Shift+H { move-column-left; }
        Mod+Shift+L { move-column-right; }
        Mod+Shift+K { move-window-up; }
        Mod+Shift+J { move-window-down; }

        // ============================================================
        // LAYOUT CONTROL
        // ============================================================
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Space { center-column; }
        Mod+Comma { consume-window-into-column; }
        Mod+Period { expel-window-from-column; }
        Mod+Minus { set-column-width "-10%"; }
        Mod+Equal { set-column-width "+10%"; }
        Mod+Shift+Minus { set-window-height "-10%"; }
        Mod+Shift+Equal { set-window-height "+10%"; }

        // Switch column presets
        Mod+Ctrl+1 { set-column-width "33%"; }
        Mod+Ctrl+2 { set-column-width "50%"; }
        Mod+Ctrl+3 { set-column-width "67%"; }
        Mod+Ctrl+4 { set-column-width "100%"; }

        // ============================================================
        // WORKSPACE MANAGEMENT
        // ============================================================
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }
        
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }

        // Scroll through workspaces
        Mod+WheelScrollDown { focus-workspace-down; }
        Mod+WheelScrollUp { focus-workspace-up; }
        Mod+Shift+WheelScrollDown { move-column-to-workspace-down; }
        Mod+Shift+WheelScrollUp { move-column-to-workspace-up; }

        // ============================================================
        // MONITOR MANAGEMENT
        // ============================================================
        Mod+Ctrl+Left { focus-monitor-left; }
        Mod+Ctrl+Right { focus-monitor-right; }
        Mod+Ctrl+Shift+Left { move-column-to-monitor-left; }
        Mod+Ctrl+Shift+Right { move-column-to-monitor-right; }
        Mod+Shift+P { power-off-monitors; }

        // ============================================================
        // SESSION
        // ============================================================
        Mod+Shift+E { quit; }
        Mod+Shift+Slash { show-hotkey-overlay; }

        // ============================================================
        // MEDIA & HARDWARE KEYS
        // ============================================================
        XF86AudioRaiseVolume  allow-when-locked=true { spawn "pamixer" "-i" "5"; }
        XF86AudioLowerVolume  allow-when-locked=true { spawn "pamixer" "-d" "5"; }
        XF86AudioMute         allow-when-locked=true { spawn "pamixer" "-t"; }
        XF86AudioPlay         allow-when-locked=true { spawn "playerctl" "play-pause"; }
        XF86AudioNext         allow-when-locked=true { spawn "playerctl" "next"; }
        XF86AudioPrev         allow-when-locked=true { spawn "playerctl" "previous"; }
        XF86MonBrightnessUp   allow-when-locked=true { spawn "brightnessctl" "s" "+5%"; }
        XF86MonBrightnessDown allow-when-locked=true { spawn "brightnessctl" "s" "5%-"; }

        // ============================================================
        // SCREENSHOT (Direct - no menu)
        // ============================================================
        Print { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print { screenshot-window; }

        // ============================================================
        // MOUSE BINDS
        // ============================================================
        Mod+WheelScrollRight { focus-column-right; }
        Mod+WheelScrollLeft { focus-column-left; }
    }
  '';

  # ========================================================================
  # NIRI PACKAGES
  # ========================================================================
  home.packages = with pkgs; [
    wlr-which-key   # Which-key overlay for Wayland
    swww             # Wallpaper daemon
    pamixer          # Audio control
    playerctl        # Media player control
    brightnessctl    # Brightness control
    grim             # Screenshot
    slurp            # Region selection
    swappy           # Screenshot editor
    hyprpicker       # Color picker
    wl-clipboard     # Clipboard
    cliphist         # Clipboard history
    xwayland-satellite # X11 compat
    
    # All wlr-which-key menu scripts
    appMenu
    fileMenu
    systemMenu
    gamingMenu
    powerMenu
    screenshotMenu
    layoutMenu
    noctaliaMenu
  ];

  # ========================================================================
  # ENVIRONMENT VARIABLES (for Niri session)
  # ========================================================================
  home.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_DESKTOP = "niri";
    GTK_DEBUG = "";  # Suppress GTK debug warnings
  };
}
