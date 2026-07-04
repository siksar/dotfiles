{ lib, ... }:

let
  # SUPER içeren her bind için otomatik "launcher iptal ikizi" üretilir:
  # aynı kombinasyona non-consuming (bindn) caelestia:launcherInterrupt eklenir.
  # Böylece SUPER+X kombinasyonlarından sonra SUPER bırakılınca menü AÇILMAZ
  # (Copilot=Meta+Shift+F23 dahil). catchall bu Hyprland'de submap dışında yasak.
  needsTwin = mods: key: lib.hasInfix "SUPER" mods && key != "SUPER_L";
  twin = mods: key:
    lib.optional (needsTwin mods key)
      "bindn = ${mods}, ${key}, global, caelestia:launcherInterrupt";

  # Açıklamalı bind (bindd ailesi): flags "d" içermeli
  mkd = flags: mods: key: desc: action:
    [ "bind${flags} = ${mods}, ${key}, ${desc}, ${action}" ] ++ twin mods key;
  # Açıklamasız bind
  mk = flags: mods: key: action:
    [ "bind${flags} = ${mods}, ${key}, ${action}" ] ++ twin mods key;

  # Çalışma alanları 1-10 (klavye code:10..19)
  wsBinds = lib.concatLists (map (i: let
    code = "code:${toString (i + 9)}";
    ws = toString i;
  in
    mkd "d" "SUPER" code "Switch to workspace ${ws}" "workspace, ${ws}"
    ++ mkd "d" "SUPER SHIFT" code "Move window to workspace ${ws}" "movetoworkspace, ${ws}"
    ++ lib.optionals (i <= 5)
      (mkd "d" "SUPER SHIFT ALT" code "Move window silently to workspace ${ws}" "movetoworkspacesilent, ${ws}")
  ) (lib.range 1 10));

  allBinds = lib.concatLists [
    # --- Uygulamalar ---
    (mkd "d" "SUPER" "RETURN" "Terminal" "exec, ghostty")
    (mkd "d" "SUPER" "F" "File manager" "exec, nautilus")
    (mkd "d" "SUPER" "B" "Web browser" "exec, firefox")
    (mkd "d" "SUPER" "N" "Neovim" "exec, ghostty -e nvim")
    (mkd "rd" "SUPER" "SUPER_L" "Launch apps" "global, caelestia:launcher")
    # Copilot tuşu = Meta+Shift+F23 (libinput ile doğrulandı)
    (mkd "d" "SUPER SHIFT" "F23" "Claude Desktop" "exec, claude-desktop")

    # --- Caelestia Shell ---
    (mkd "d" "SUPER" "L" "Lock screen" "global, caelestia:lock")
    (mkd "d" "SUPER" "X" "Session menu" "global, caelestia:session")
    (mkd "d" "SUPER" "D" "Dashboard" "exec, caelestia shell drawers toggle dashboard")
    (mkd "d" "SUPER SHIFT" "N" "Notification sidebar" "global, caelestia:sidebar")
    (mkd "d" "SUPER SHIFT" "C" "Clear notifications" "global, caelestia:clearNotifs")
    (mkd "d" "SUPER CTRL SHIFT" "R" "Restart shell" "exec, systemctl --user restart caelestia")

    # --- Pencere Yönetimi ---
    (mkd "d" "SUPER" "Q" "Close window" "killactive,")
    (mkd "d" "SUPER" "T" "Toggle window floating" "togglefloating,")
    (mkd "d" "SUPER SHIFT" "F" "Full screen" "fullscreen, 0")
    (mkd "d" "SUPER CTRL" "F" "Tiled full screen" "fullscreenstate, 0 2")
    (mkd "d" "SUPER" "J" "Toggle window split" "layoutmsg, togglesplit")
    (mkd "d" "SUPER" "P" "Pseudo window" "pseudo,")

    # --- Gruplama ---
    (mkd "d" "SUPER" "G" "Toggle window grouping" "togglegroup")
    (mkd "d" "SUPER ALT" "G" "Move active window out of group" "moveoutofgroup")
    (mkd "d" "SUPER ALT" "LEFT" "Move window to group on left" "moveintogroup, l")
    (mkd "d" "SUPER ALT" "RIGHT" "Move window to group on right" "moveintogroup, r")
    (mkd "d" "SUPER ALT" "UP" "Move window to group on top" "moveintogroup, u")
    (mkd "d" "SUPER ALT" "DOWN" "Move window to group on bottom" "moveintogroup, d")
    (mkd "d" "SUPER ALT" "TAB" "Next window in group" "changegroupactive, f")
    (mkd "d" "SUPER ALT SHIFT" "TAB" "Previous window in group" "changegroupactive, b")

    # --- Odak ---
    (mkd "d" "SUPER" "LEFT" "Focus on left window" "movefocus, l")
    (mkd "d" "SUPER" "RIGHT" "Focus on right window" "movefocus, r")
    (mkd "d" "SUPER" "UP" "Focus on above window" "movefocus, u")
    (mkd "d" "SUPER" "DOWN" "Focus on below window" "movefocus, d")
    (mkd "d" "ALT" "TAB" "Focus on next window" "cyclenext")
    (mkd "d" "ALT SHIFT" "TAB" "Focus on previous window" "cyclenext, prev")

    # --- Çalışma Alanları ---
    wsBinds
    (mkd "d" "SUPER" "TAB" "Next workspace" "workspace, e+1")
    (mkd "d" "SUPER SHIFT" "TAB" "Previous workspace" "workspace, e-1")
    (mkd "d" "SUPER CTRL" "TAB" "Former workspace" "workspace, previous")

    # --- Pencere Taşıma ---
    (mkd "d" "SUPER SHIFT" "LEFT" "Swap window to the left" "swapwindow, l")
    (mkd "d" "SUPER SHIFT" "RIGHT" "Swap window to the right" "swapwindow, r")
    (mkd "d" "SUPER SHIFT" "UP" "Swap window up" "swapwindow, u")
    (mkd "d" "SUPER SHIFT" "DOWN" "Swap window down" "swapwindow, d")

    # --- Boyutlandırma ---
    (mkd "d" "SUPER" "code:20" "Expand window left" "resizeactive, -100 0")
    (mkd "d" "SUPER" "code:21" "Shrink window left" "resizeactive, 100 0")
    (mkd "d" "SUPER SHIFT" "code:20" "Shrink window up" "resizeactive, 0 -100")
    (mkd "d" "SUPER SHIFT" "code:21" "Expand window down" "resizeactive, 0 100")

    # --- Scratchpad ---
    (mkd "d" "SUPER" "S" "Toggle scratchpad" "togglespecialworkspace, scratchpad")
    (mkd "d" "SUPER ALT" "S" "Move window to scratchpad" "movetoworkspacesilent, special:scratchpad")

    # --- Ses (PipeWire / WirePlumber) ---
    (mkd "eld" "" "XF86AudioRaiseVolume" "Volume up" "exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+")
    (mkd "eld" "" "XF86AudioLowerVolume" "Volume down" "exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-")
    (mkd "eld" "" "XF86AudioMute" "Mute" "exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    (mkd "eld" "" "XF86AudioMicMute" "Mute microphone" "exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
    (mkd "eld" "ALT" "XF86AudioRaiseVolume" "Volume up precise" "exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 1%+")
    (mkd "eld" "ALT" "XF86AudioLowerVolume" "Volume down precise" "exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 1%-")

    # --- Parlaklık (Caelestia OSD'li) ---
    (mkd "eld" "" "XF86MonBrightnessUp" "Brightness up" "global, caelestia:brightnessUp")
    (mkd "eld" "" "XF86MonBrightnessDown" "Brightness down" "global, caelestia:brightnessDown")
    (mkd "eld" "SHIFT" "XF86MonBrightnessUp" "Brightness maximum" "exec, brightnessctl set 100%")
    (mkd "eld" "SHIFT" "XF86MonBrightnessDown" "Brightness minimum" "exec, brightnessctl set 1%")
    (mkd "eld" "ALT" "XF86MonBrightnessUp" "Brightness up precise" "exec, brightnessctl set +1%")
    (mkd "eld" "ALT" "XF86MonBrightnessDown" "Brightness down precise" "exec, brightnessctl set 1%-")

    # --- Ekran Görüntüsü (Fn+F11 = F20, libinput ile doğrulandı) ---
    (mkd "d" "" "F20" "Screenshot region" "global, caelestia:screenshotFreeze")
    (mkd "d" "" "PRINT" "Screenshot region" "global, caelestia:screenshotFreeze")
    (mkd "d" "SHIFT" "PRINT" "Screenshot full" "exec, caelestia screenshot")

    # --- Kapak Anahtarı ---
    (mk "l" "" "switch:on:Lid Switch" "exec, hyprctl dispatch dpms off eDP-1")
    (mk "l" "" "switch:off:Lid Switch" "exec, hyprctl dispatch dpms on eDP-1")

    # --- Güç ---
    (mkd "ld" "" "XF86PowerOff" "Power menu" "global, caelestia:session")

    # --- Fare ---
    (mk "" "SUPER" "mouse_down" "workspace, e+1")
    (mk "" "SUPER" "mouse_up" "workspace, e-1")
    (mkd "md" "SUPER" "mouse:272" "Move window" "movewindow")
    (mkd "md" "SUPER" "mouse:273" "Resize window" "resizewindow")
  ];
in
{
  wayland.windowManager.hyprland.extraConfig =
    lib.concatStringsSep "\n" allBinds;
}
