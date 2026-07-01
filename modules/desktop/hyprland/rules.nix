{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    windowrule {
      name = ignore-maximize
      match:class = .*
      suppress_event = maximize
    }
    windowrule {
      name = tag-opacity
      match:class = .*
      tag = +default-opacity
    }
    windowrule {
      name = no-focus-ghost
      match:class = ^$
      match:title = ^$
      match:xwayland = true
      match:float = true
      match:fullscreen = false
      match:pin = false
      no_focus = 1
    }
    windowrule {
      name = default-opacity-value
      match:tag = default-opacity
      opacity = 0.97 0.9
    }
  '';
}
