{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    # Main Modifier
    "$mainMod" = "SUPER";

    # Standard Application Keybindings
    bindd = [
      "$mainMod, RETURN, Terminal, exec, alacritty"
      "$mainMod, F, File manager, exec, nautilus"
      "$mainMod, B, Web browser, exec, firefox"
      "$mainMod, N, Neovim, exec, alacritty -e nvim"
      "$mainMod, T, Top, exec, alacritty -e btop"
      "$mainMod, G, Messenger, exec, signal-desktop"
      "$mainMod, O, Pop window out (float & pin), exec, omarchy-hyprland-window-pop"
      "$mainMod, L, Toggle workspace layout, exec, omarchy-hyprland-workspace-layout-toggle"
      "$mainMod, W, Close window, killactive,"
      "CTRL ALT, DELETE, Close all windows, exec, omarchy-hyprland-window-close-all"

      # Control Tiling
      "$mainMod, J, Toggle window split, layoutmsg, togglesplit"
      "$mainMod, P, Pseudo window, pseudo,"
      "$mainMod, T, Toggle window floating/tiling, togglefloating,"
      "$mainMod, F, Full screen, fullscreen, 0"
      "$mainMod CTRL, F, Tiled full screen, fullscreenstate, 0 2"
      "$mainMod ALT, F, Full width, fullscreen, 1"

      # Move Focus
      "$mainMod, LEFT, Focus on left window, movefocus, l"
      "$mainMod, RIGHT, Focus on right window, movefocus, r"
      "$mainMod, UP, Focus on above window, movefocus, u"
      "$mainMod, DOWN, Focus on below window, movefocus, d"

      # Switch Workspaces
      "$mainMod, code:10, Switch to workspace 1, workspace, 1"
      "$mainMod, code:11, Switch to workspace 2, workspace, 2"
      "$mainMod, code:12, Switch to workspace 3, workspace, 3"
      "$mainMod, code:13, Switch to workspace 4, workspace, 4"
      "$mainMod, code:14, Switch to workspace 5, workspace, 5"
      "$mainMod, code:15, Switch to workspace 6, workspace, 6"
      "$mainMod, code:16, Switch to workspace 7, workspace, 7"
      "$mainMod, code:17, Switch to workspace 8, workspace, 8"
      "$mainMod, code:18, Switch to workspace 9, workspace, 9"
      "$mainMod, code:19, Switch to workspace 10, workspace, 10"

      # Move Active Window to Workspace
      "$mainMod SHIFT, code:10, Move window to workspace 1, movetoworkspace, 1"
      "$mainMod SHIFT, code:11, Move window to workspace 2, movetoworkspace, 2"
      "$mainMod SHIFT, code:12, Move window to workspace 3, movetoworkspace, 3"
      "$mainMod SHIFT, code:13, Move window to workspace 4, movetoworkspace, 4"
      "$mainMod SHIFT, code:14, Move window to workspace 5, movetoworkspace, 5"
      "$mainMod SHIFT, code:15, Move window to workspace 6, movetoworkspace, 6"
      "$mainMod SHIFT, code:16, Move window to workspace 7, movetoworkspace, 7"
      "$mainMod SHIFT, code:17, Move window to workspace 8, movetoworkspace, 8"
      "$mainMod SHIFT, code:18, Move window to workspace 9, movetoworkspace, 9"
      "$mainMod SHIFT, code:19, Move window to workspace 10, movetoworkspace, 10"

      # Move Active Window Silently
      "$mainMod SHIFT ALT, code:10, Move window silently to workspace 1, movetoworkspacesilent, 1"
      "$mainMod SHIFT ALT, code:11, Move window silently to workspace 2, movetoworkspacesilent, 2"
      "$mainMod SHIFT ALT, code:12, Move window silently to workspace 3, movetoworkspacesilent, 3"
      "$mainMod SHIFT ALT, code:13, Move window silently to workspace 4, movetoworkspacesilent, 4"
      "$mainMod SHIFT ALT, code:14, Move window silently to workspace 5, movetoworkspacesilent, 5"
      "$mainMod SHIFT ALT, code:15, Move window silently to workspace 6, movetoworkspacesilent, 6"
      "$mainMod SHIFT ALT, code:16, Move window silently to workspace 7, movetoworkspacesilent, 7"
      "$mainMod SHIFT ALT, code:17, Move window silently to workspace 8, movetoworkspacesilent, 8"
      "$mainMod SHIFT ALT, code:18, Move window silently to workspace 9, movetoworkspacesilent, 9"
      "$mainMod SHIFT ALT, code:19, Move window silently to workspace 10, movetoworkspacesilent, 10"

      # Scratchpad
      "$mainMod, S, Toggle scratchpad, togglespecialworkspace, scratchpad"
      "$mainMod ALT, S, Move window to scratchpad, movetoworkspacesilent, special:scratchpad"

      # Workspace Navigation
      "$mainMod, TAB, Next workspace, workspace, e+1"
      "$mainMod SHIFT, TAB, Previous workspace, workspace, e-1"
      "$mainMod CTRL, TAB, Former workspace, workspace, previous"

      # Swap Active Window
      "$mainMod SHIFT, LEFT, Swap window to the left, swapwindow, l"
      "$mainMod SHIFT, RIGHT, Swap window to the right, swapwindow, r"
      "$mainMod SHIFT, UP, Swap window up, swapwindow, u"
      "$mainMod SHIFT, DOWN, Swap window down, swapwindow, d"

      # Cycle Window Focus
      "ALT, TAB, Focus on next window, cyclenext"
      "ALT SHIFT, TAB, Focus on previous window, cyclenext, prev"
      "ALT, TAB, Reveal active window on top, bringactivetotop"
      "ALT SHIFT, TAB, Reveal active window on top, bringactivetotop"

      # Monitor Navigation
      "CTRL ALT, TAB, Focus on next monitor, focusmonitor, +1"
      "CTRL ALT SHIFT, TAB, Focus on previous monitor, focusmonitor, -1"

      # Resize Active Window
      "$mainMod, code:20, Expand window left, resizeactive, -100 0"
      "$mainMod, code:21, Shrink window left, resizeactive, 100 0"
      "$mainMod SHIFT, code:20, Shrink window up, resizeactive, 0 -100"
      "$mainMod SHIFT, code:21, Expand window down, resizeactive, 0 100"

      # Groups
      "$mainMod, G, Toggle window grouping, togglegroup"
      "$mainMod ALT, G, Move active window out of group, moveoutofgroup"
      "$mainMod ALT, LEFT, Move window to group on left, moveintogroup, l"
      "$mainMod ALT, RIGHT, Move window to group on right, moveintogroup, r"
      "$mainMod ALT, UP, Move window to group on top, moveintogroup, u"
      "$mainMod ALT, DOWN, Move window to group on bottom, moveintogroup, d"
      "$mainMod ALT, TAB, Next window in group, changegroupactive, f"
      "$mainMod ALT SHIFT, TAB, Previous window in group, changegroupactive, b"
      "$mainMod CTRL, LEFT, Move grouped window focus left, changegroupactive, b"
      "$mainMod CTRL, RIGHT, Move grouped window focus right, changegroupactive, f"
      "$mainMod ALT, code:10, Switch to group window 1, changegroupactive, 1"
      "$mainMod ALT, code:11, Switch to group window 2, changegroupactive, 2"
      "$mainMod ALT, code:12, Switch to group window 3, changegroupactive, 3"
      "$mainMod ALT, code:13, Switch to group window 4, changegroupactive, 4"
      "$mainMod ALT, code:14, Switch to group window 5, changegroupactive, 5"

      # Utilities Menus
      "$mainMod, SPACE, Launch apps, exec, omarchy-launch-walker"
      "$mainMod CTRL, E, Emoji picker, exec, omarchy-launch-walker -m symbols"
      "$mainMod CTRL, C, Capture menu, exec, omarchy-menu capture"
      "$mainMod CTRL, O, Toggle menu, exec, omarchy-menu toggle"
      "$mainMod CTRL, H, Hardware menu, exec, omarchy-menu hardware"
      "$mainMod ALT, SPACE, Omarchy menu, exec, omarchy-menu"
      "$mainMod SHIFT, code:201, Omarchy menu, exec, omarchy-menu"
      "$mainMod, ESCAPE, System menu, exec, omarchy-menu system"
      "$mainMod, K, Show key bindings, exec, omarchy-menu-keybindings"

      # Aesthetics Toggles
      "$mainMod SHIFT, SPACE, Toggle top bar, exec, omarchy-toggle-waybar"
      "$mainMod CTRL, SPACE, Theme background menu, exec, omarchy-menu background"
      "$mainMod SHIFT CTRL, SPACE, Theme menu, exec, omarchy-menu theme"
      "$mainMod, BACKSPACE, Toggle window transparency, exec, omarchy-hyprland-window-transparency-toggle"
      "$mainMod SHIFT, BACKSPACE, Toggle window gaps, exec, omarchy-hyprland-window-gaps-toggle"
      "$mainMod CTRL, BACKSPACE, Toggle single-window square aspect, exec, omarchy-hyprland-window-single-square-aspect-toggle"

      # Notifications
      "$mainMod, COMMA, Dismiss last notification, exec, makoctl dismiss"
      "$mainMod SHIFT, COMMA, Dismiss all notifications, exec, makoctl dismiss --all"
      "$mainMod CTRL, COMMA, Toggle silencing notifications, exec, omarchy-toggle-notification-silencing"
      "$mainMod ALT, COMMA, Invoke last notification, exec, makoctl invoke"
      "$mainMod SHIFT ALT, COMMA, Restore last notification, exec, makoctl restore"

      # Idle & Display Control
      "$mainMod CTRL, I, Toggle locking on idle, exec, omarchy-toggle-idle"
      "$mainMod CTRL, N, Toggle nightlight, exec, omarchy-toggle-nightlight"
      "$mainMod CTRL, Delete, Toggle laptop display, exec, omarchy-hyprland-monitor-internal toggle"
      "$mainMod CTRL ALT, Delete, Toggle laptop display mirroring, exec, omarchy-hyprland-monitor-internal-mirror toggle"

      # Captures
      ", PRINT, Screenshot, exec, omarchy-capture-screenshot"
      "ALT, PRINT, Screenrecording, exec, omarchy-menu screenrecord"
      "$mainMod, PRINT, Color picker, exec, pkill hyprpicker || hyprpicker -a"
      "$mainMod CTRL, PRINT, Extract text (OCR) from screenshot, exec, omarchy-capture-text-extraction"

      # Extras
      "$mainMod CTRL, S, Share, exec, omarchy-menu share"
      "$mainMod CTRL, PERIOD, Transcode, exec, omarchy-transcode"
      "$mainMod CTRL, R, Set reminder, exec, omarchy-menu reminder-set"
      "$mainMod CTRL ALT, R, Show reminders, exec, omarchy-reminder show"
      "$mainMod SHIFT CTRL, R, Clear reminders, exec, omarchy-reminder clear"

      # Waybar-less info
      "$mainMod CTRL ALT, T, Show time, exec, notify-send -u low '    $(date +\"%A %H:%M  ·  %d %B %Y  ·  Week %V\")'"
      "$mainMod CTRL ALT, B, Show battery remaining, exec, notify-send -u low \"$(omarchy-battery-status)\""
      "$mainMod CTRL ALT, W, Show weather, exec, notify-send -u low \"$(omarchy-weather-status)\""

      # Control Panels
      "$mainMod CTRL, A, Audio controls, exec, omarchy-launch-audio"
      "$mainMod CTRL, B, Bluetooth controls, exec, omarchy-launch-bluetooth"
      "$mainMod CTRL, W, Wifi controls, exec, omarchy-launch-wifi"
      "$mainMod CTRL, T, Activity, exec, omarchy-launch-tui btop"

      # Dictation
      "$mainMod CTRL, X, Toggle dictation, exec, voxtype record toggle"

      # Zoom
      "$mainMod CTRL, Z, Zoom in, exec, hyprctl keyword cursor:zoom_factor $(hyprctl getoption cursor:zoom_factor -j | jq '.float + 1')"
      "$mainMod CTRL ALT, Z, Reset zoom, exec, hyprctl keyword cursor:zoom_factor 1"

      # Lock System
      "$mainMod CTRL, L, Lock system, exec, omarchy-system-lock"
    ];

    bindeld = [
      ",XF86AudioRaiseVolume, Volume up, exec, omarchy-swayosd-client --output-volume raise"
      ",XF86AudioLowerVolume, Volume down, exec, omarchy-swayosd-client --output-volume lower"
      ",XF86AudioMute, Mute, exec, omarchy-swayosd-client --output-volume mute-toggle"
      ",XF86AudioMicMute, Mute microphone, exec, omarchy-audio-input-mute"
      ",XF86MonBrightnessUp, Brightness up, exec, omarchy-brightness-display +5%"
      ",XF86MonBrightnessDown, Brightness down, exec, omarchy-brightness-display 5%-"
      "SHIFT, XF86MonBrightnessUp, Brightness maximum, exec, omarchy-brightness-display 100%"
      "SHIFT, XF86MonBrightnessDown, Brightness minimum, exec, omarchy-brightness-display 1%"
      ",XF86KbdBrightnessUp, Keyboard brightness up, exec, omarchy-brightness-keyboard up"
      ",XF86KbdBrightnessDown, Keyboard brightness down, exec, omarchy-brightness-keyboard down"

      # Precise adjustments
      "ALT, XF86AudioRaiseVolume, Volume up precise, exec, omarchy-swayosd-client --output-volume +1"
      "ALT, XF86AudioLowerVolume, Volume down precise, exec, omarchy-swayosd-client --output-volume -1"
      "ALT, XF86MonBrightnessUp, Brightness up precise, exec, omarchy-brightness-display +1%"
      "ALT, XF86MonBrightnessDown, Brightness down precise, exec, omarchy-brightness-display 1%-"
    ];

    bindld = [
      ",XF86KbdLightOnOff, Keyboard backlight cycle, exec, omarchy-brightness-keyboard cycle"
      ",XF86TouchpadToggle, Toggle touchpad, exec, omarchy-toggle-touchpad"
      ",XF86TouchpadOn, Enable touchpad, exec, omarchy-toggle-touchpad on"
      ",XF86TouchpadOff, Disable touchpad, exec, omarchy-toggle-touchpad off"

      # Playerctl controls
      ", XF86AudioNext, Next track, exec, omarchy-swayosd-client --playerctl next"
      ", XF86AudioPause, Pause, exec, omarchy-swayosd-client --playerctl play-pause"
      ", XF86AudioPlay, Play, exec, omarchy-swayosd-client --playerctl play-pause"
      ", XF86AudioPrev, Previous track, exec, omarchy-swayosd-client --playerctl previous"

      # Audio Output switch
      "$mainMod, XF86AudioMute, Switch audio output, exec, omarchy-audio-output-switch"
    ];

    bindl = [
      ", XF86PowerOff, Power menu, exec, omarchy-menu system"
      ", switch:on:Lid Switch, exec, omarchy-hw-external-monitors && omarchy-hyprland-monitor-internal off"
      ", switch:off:Lid Switch, exec, omarchy-hyprland-monitor-internal on"
    ];

    bindmd = [
      "$mainMod, mouse:272, Move window, movewindow"
      "$mainMod, mouse:273, Resize window, resizewindow"
    ];

    bindm = [
      # Scroll workspaces
      "$mainMod, mouse_down, workspace, e+1"
      "$mainMod, mouse_up, workspace, e-1"
      "$mainMod ALT, mouse_down, changegroupactive, f"
      "$mainMod ALT, mouse_up, changegroupactive, b"
    ];
  };
}
