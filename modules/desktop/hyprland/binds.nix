{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    # --- Uygulamalar ---
    bindd=SUPER, RETURN, Terminal, exec, alacritty
    bindd=SUPER, F, File manager, exec, nautilus
    bindd=SUPER, B, Web browser, exec, firefox
    bindd=SUPER, N, Neovim, exec, alacritty -e nvim
    bindd=SUPER, SPACE, Launch apps, exec, rofi -show drun

    # --- Pencere Yönetimi ---
    bindd=SUPER, W, Close window, killactive,
    bindd=SUPER, T, Toggle window floating, togglefloating,
    bindd=SUPER SHIFT, F, Full screen, fullscreen, 0
    bindd=SUPER CTRL, F, Tiled full screen, fullscreenstate, 0 2
    bindd=SUPER, J, Toggle window split, layoutmsg, togglesplit
    bindd=SUPER, P, Pseudo window, pseudo,

    # --- Gruplama ---
    bindd=SUPER, G, Toggle window grouping, togglegroup
    bindd=SUPER ALT, G, Move active window out of group, moveoutofgroup
    bindd=SUPER ALT, LEFT, Move window to group on left, moveintogroup, l
    bindd=SUPER ALT, RIGHT, Move window to group on right, moveintogroup, r
    bindd=SUPER ALT, UP, Move window to group on top, moveintogroup, u
    bindd=SUPER ALT, DOWN, Move window to group on bottom, moveintogroup, d
    bindd=SUPER ALT, TAB, Next window in group, changegroupactive, f
    bindd=SUPER ALT SHIFT, TAB, Previous window in group, changegroupactive, b

    # --- Odak ---
    bindd=SUPER, LEFT, Focus on left window, movefocus, l
    bindd=SUPER, RIGHT, Focus on right window, movefocus, r
    bindd=SUPER, UP, Focus on above window, movefocus, u
    bindd=SUPER, DOWN, Focus on below window, movefocus, d
    bindd=ALT, TAB, Focus on next window, cyclenext
    bindd=ALT SHIFT, TAB, Focus on previous window, cyclenext, prev

    # --- Çalışma Alanları ---
    bindd=SUPER, code:10, Switch to workspace 1, workspace, 1
    bindd=SUPER, code:11, Switch to workspace 2, workspace, 2
    bindd=SUPER, code:12, Switch to workspace 3, workspace, 3
    bindd=SUPER, code:13, Switch to workspace 4, workspace, 4
    bindd=SUPER, code:14, Switch to workspace 5, workspace, 5
    bindd=SUPER, code:15, Switch to workspace 6, workspace, 6
    bindd=SUPER, code:16, Switch to workspace 7, workspace, 7
    bindd=SUPER, code:17, Switch to workspace 8, workspace, 8
    bindd=SUPER, code:18, Switch to workspace 9, workspace, 9
    bindd=SUPER, code:19, Switch to workspace 10, workspace, 10
    bindd=SUPER SHIFT, code:10, Move window to workspace 1, movetoworkspace, 1
    bindd=SUPER SHIFT, code:11, Move window to workspace 2, movetoworkspace, 2
    bindd=SUPER SHIFT, code:12, Move window to workspace 3, movetoworkspace, 3
    bindd=SUPER SHIFT, code:13, Move window to workspace 4, movetoworkspace, 4
    bindd=SUPER SHIFT, code:14, Move window to workspace 5, movetoworkspace, 5
    bindd=SUPER SHIFT, code:15, Move window to workspace 6, movetoworkspace, 6
    bindd=SUPER SHIFT, code:16, Move window to workspace 7, movetoworkspace, 7
    bindd=SUPER SHIFT, code:17, Move window to workspace 8, movetoworkspace, 8
    bindd=SUPER SHIFT, code:18, Move window to workspace 9, movetoworkspace, 9
    bindd=SUPER SHIFT, code:19, Move window to workspace 10, movetoworkspace, 10
    bindd=SUPER SHIFT ALT, code:10, Move window silently to workspace 1, movetoworkspacesilent, 1
    bindd=SUPER SHIFT ALT, code:11, Move window silently to workspace 2, movetoworkspacesilent, 2
    bindd=SUPER SHIFT ALT, code:12, Move window silently to workspace 3, movetoworkspacesilent, 3
    bindd=SUPER SHIFT ALT, code:13, Move window silently to workspace 4, movetoworkspacesilent, 4
    bindd=SUPER SHIFT ALT, code:14, Move window silently to workspace 5, movetoworkspacesilent, 5
    bindd=SUPER, TAB, Next workspace, workspace, e+1
    bindd=SUPER SHIFT, TAB, Previous workspace, workspace, e-1
    bindd=SUPER CTRL, TAB, Former workspace, workspace, previous

    # --- Pencere Taşıma ---
    bindd=SUPER SHIFT, LEFT, Swap window to the left, swapwindow, l
    bindd=SUPER SHIFT, RIGHT, Swap window to the right, swapwindow, r
    bindd=SUPER SHIFT, UP, Swap window up, swapwindow, u
    bindd=SUPER SHIFT, DOWN, Swap window down, swapwindow, d

    # --- Boyutlandırma ---
    bindd=SUPER, code:20, Expand window left, resizeactive, -100 0
    bindd=SUPER, code:21, Shrink window left, resizeactive, 100 0
    bindd=SUPER SHIFT, code:20, Shrink window up, resizeactive, 0 -100
    bindd=SUPER SHIFT, code:21, Expand window down, resizeactive, 0 100

    # --- Scratchpad ---
    bindd=SUPER, S, Toggle scratchpad, togglespecialworkspace, scratchpad
    bindd=SUPER ALT, S, Move window to scratchpad, movetoworkspacesilent, special:scratchpad

    # --- Waybar ---
    bindd=SUPER SHIFT, SPACE, Toggle top bar, exec, pkill -SIGUSR1 waybar

    # --- Ses (PipeWire / WirePlumber) ---
    bindeld=,XF86AudioRaiseVolume, Volume up, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
    bindeld=,XF86AudioLowerVolume, Volume down, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindeld=,XF86AudioMute, Mute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindeld=,XF86AudioMicMute, Mute microphone, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    bindeld=ALT, XF86AudioRaiseVolume, Volume up precise, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 1%+
    bindeld=ALT, XF86AudioLowerVolume, Volume down precise, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-

    # --- Parlaklık (brightnessctl) ---
    bindeld=,XF86MonBrightnessUp, Brightness up, exec, brightnessctl set +5%
    bindeld=,XF86MonBrightnessDown, Brightness down, exec, brightnessctl set 5%-
    bindeld=SHIFT, XF86MonBrightnessUp, Brightness maximum, exec, brightnessctl set 100%
    bindeld=SHIFT, XF86MonBrightnessDown, Brightness minimum, exec, brightnessctl set 1%
    bindeld=ALT, XF86MonBrightnessUp, Brightness up precise, exec, brightnessctl set +1%
    bindeld=ALT, XF86MonBrightnessDown, Brightness down precise, exec, brightnessctl set 1%-

    # --- Ekran Görüntüsü (grim + slurp + wl-clipboard) ---
    bindd=,PRINT, Screenshot region, exec, grim -g "$(slurp)" - | wl-copy
    bindd=SHIFT, PRINT, Screenshot full, exec, grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png

    # --- Kapak Anahtarı ---
    bindl=, switch:on:Lid Switch, exec, hyprctl dispatch dpms off eDP-1
    bindl=, switch:off:Lid Switch, exec, hyprctl dispatch dpms on eDP-1

    # --- Güç ---
    bindld=, XF86PowerOff, Power menu, exec, systemctl poweroff

    # --- Fare ---
    bind=SUPER, mouse_down, workspace, e+1
    bind=SUPER, mouse_up, workspace, e-1
    bindmd=SUPER, mouse:272, Move window, movewindow
    bindmd=SUPER, mouse:273, Resize window, resizewindow
  '';
}
