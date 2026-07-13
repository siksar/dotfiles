{ lib, config, ... }:

let
  shell = config.rice.shell;

  # --- Kabuk-özel eylem haritası — tuşlar üç kabukta da aynı kalır ---
  # caelestia: Quickshell global kısayolları; dms/noctalia: IPC exec'leri
  cmd = {
    caelestia = {
      lock        = "global, caelestia:lock";
      session     = "global, caelestia:session";
      dashboard   = "exec, caelestia shell drawers toggle dashboard";
      sidebar     = "global, caelestia:sidebar";
      clearNotifs = "global, caelestia:clearNotifs";
      restart     = "exec, systemctl --user restart caelestia";
      briUp       = "global, caelestia:brightnessUp";
      briDown     = "global, caelestia:brightnessDown";
      shotRegion  = "global, caelestia:screenshotFreeze";
      shotFull    = "exec, caelestia screenshot";
      launcher    = null; # özel: SUPER-release bind'ı (aşağıda)
      clipboard   = null; # launcher içinde (">clip")
    };
    dms = {
      lock        = "exec, dms ipc call lock lock";
      session     = "exec, dms ipc call powermenu toggle";
      dashboard   = ''exec, dms ipc call dash toggle ""'';
      sidebar     = "exec, dms ipc call notifications toggle";
      clearNotifs = "exec, dms ipc call notifications clearAll";
      restart     = "exec, systemctl --user restart dms";
      briUp       = ''exec, dms ipc call brightness increment 5 ""'';
      briDown     = ''exec, dms ipc call brightness decrement 5 ""'';
      shotRegion  = "exec, dms screenshot";
      shotFull    = "exec, dms screenshot full";
      launcher    = "exec, dms ipc call spotlight toggle";
      clipboard   = "exec, dms ipc call clipboard toggle";
    };
    noctalia = {
      lock        = "exec, noctalia msg session lock";
      session     = "exec, noctalia msg panel-toggle session";
      dashboard   = "exec, noctalia msg panel-toggle control-center";
      sidebar     = "exec, noctalia msg panel-toggle control-center notifications";
      clearNotifs = "exec, noctalia msg notification-clear-active";
      restart     = "exec, systemctl --user restart noctalia";
      briUp       = "exec, noctalia msg brightness-up";
      briDown     = "exec, noctalia msg brightness-down";
      shotRegion  = "exec, noctalia msg screenshot-region";
      shotFull    = "exec, noctalia msg screenshot-fullscreen";
      launcher    = "exec, noctalia msg panel-toggle launcher";
      clipboard   = "exec, noctalia msg panel-toggle clipboard";
    };
  }.${shell};

  # SUPER içeren her bind için otomatik "launcher iptal ikizi" üretilir:
  # aynı kombinasyona non-consuming (bindn) caelestia:launcherInterrupt eklenir.
  # Böylece SUPER+X kombinasyonlarından sonra SUPER bırakılınca menü AÇILMAZ
  # (Copilot=Meta+Shift+F23 dahil). catchall bu Hyprland'de submap dışında yasak.
  # Interrupt protokolü caelestia'ya özgü — diğer kabuklarda ikiz üretilmez.
  needsTwin = mods: key: shell == "caelestia" && lib.hasInfix "SUPER" mods && key != "SUPER_L";
  twin = mods: key:
    lib.optional (needsTwin mods key)
      "bindn = ${mods}, ${key}, global, caelestia:launcherInterrupt";

  # Açıklamalı bind (bindd ailesi): flags "d" içermeli
  mkd = flags: mods: key: desc: action:
    [ "bind${flags} = ${mods}, ${key}, ${desc}, ${action}" ] ++ twin mods key;
  # Açıklamasız bind
  mk = flags: mods: key: action:
    [ "bind${flags} = ${mods}, ${key}, ${action}" ] ++ twin mods key;

  # Launcher: caelestia'da SUPER-release (interrupt protokolüyle güvenli);
  # dms/noctalia'da interrupt IPC'si yok → çıplak release-bind her SUPER
  # kısayolundan sonra launcher açardı. Onlarda SUPER+SPACE kullanılır.
  launcherBinds =
    if shell == "caelestia"
    then mkd "rd" "SUPER" "SUPER_L" "Launch apps" "global, caelestia:launcher"
    else mkd "d" "SUPER" "SPACE" "Launch apps" cmd.launcher;

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
    launcherBinds
    # Copilot tuşu = Meta+Shift+F23 (libinput ile doğrulandı)
    (mkd "d" "SUPER SHIFT" "F23" "Claude Desktop" "exec, claude-desktop")

    # --- Shell (aktif rice.shell'in eylem haritası) ---
    (mkd "d" "SUPER" "L" "Lock screen" cmd.lock)
    (mkd "d" "SUPER" "X" "Session menu" cmd.session)
    (mkd "d" "SUPER" "D" "Dashboard" cmd.dashboard)
    (mkd "d" "SUPER SHIFT" "N" "Notification sidebar" cmd.sidebar)
    (mkd "d" "SUPER SHIFT" "C" "Clear notifications" cmd.clearNotifs)
    (mkd "d" "SUPER CTRL SHIFT" "R" "Restart shell" cmd.restart)
    (lib.optionals (cmd.clipboard != null)
      (mkd "d" "SUPER" "V" "Clipboard history" cmd.clipboard))

    # --- Fan modu döngüsü (aorus-laptop WMI) — 0→1→2→5, bkz. gigabyte-wmi.nix ---
    (mkd "d" "SUPER" "M" "Fan mode cycle" "exec, systemctl start --no-block fan-mode-cycle.service")

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

    # --- Parlaklık (kabuk OSD'li) ---
    (mkd "eld" "" "XF86MonBrightnessUp" "Brightness up" cmd.briUp)
    (mkd "eld" "" "XF86MonBrightnessDown" "Brightness down" cmd.briDown)
    (mkd "eld" "SHIFT" "XF86MonBrightnessUp" "Brightness maximum" "exec, brightnessctl set 100%")
    (mkd "eld" "SHIFT" "XF86MonBrightnessDown" "Brightness minimum" "exec, brightnessctl set 1%")
    (mkd "eld" "ALT" "XF86MonBrightnessUp" "Brightness up precise" "exec, brightnessctl set +1%")
    (mkd "eld" "ALT" "XF86MonBrightnessDown" "Brightness down precise" "exec, brightnessctl set 1%-")

    # --- Ekran Görüntüsü ---
    # NOT: F20 bind'ı kaldırıldı — F20'yi Fn+F11 değil ÇIPLAK Fn gönderiyormuş
    # (hwdb ile susturuldu, bkz. gigabyte-wmi.nix). Bölge screenshot: PRINT
    # veya SUPER+SHIFT+S.
    (mkd "d" "" "PRINT" "Screenshot region" cmd.shotRegion)
    (mkd "d" "SUPER SHIFT" "S" "Screenshot region" cmd.shotRegion)
    (mkd "d" "SHIFT" "PRINT" "Screenshot full" cmd.shotFull)

    # --- Kapak Anahtarı ---
    (mk "l" "" "switch:on:Lid Switch" "exec, hyprctl dispatch dpms off eDP-1")
    (mk "l" "" "switch:off:Lid Switch" "exec, hyprctl dispatch dpms on eDP-1")

    # --- Güç ---
    (mkd "ld" "" "XF86PowerOff" "Power menu" cmd.session)

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
