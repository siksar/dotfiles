{ ... }:

{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "suppress_event maximize, match:class .*"
      "tag +default-opacity, match:class .*"
      "no_focus on, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0"
      "opacity 0.97 0.9, match:tag default-opacity"
    ];
  };
}
