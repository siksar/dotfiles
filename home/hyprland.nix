{ config, pkgs, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings = {
      monitor = [
        "eDP-1, 2560x1600@165, 0x0, 1"
        ", preferred, auto, 1"
      ];

      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 0;
        "col.active_border" = "rgba(d65d0eff) rgba(fe8019ff) 45deg";
        "col.inactive_border" = "rgba(928374ff)";
        layout = "dwindle";
        allow_tearing = false;
      };

      decoration = {
        rounding = 10;

        blur = {
          enabled = false;
          size = 6;
          passes = 3;
          new_optimizations = true;
          xray = true;
        };

        shadow = {
          enabled = true;
          range = 12;
          render_power = 3;
          color = "rgba(1d2021ee)";
        };

        active_opacity = 0.95;
        inactive_opacity = 0.95;
      };

      input = {
        kb_layout = "us";
        kb_variant = "";
        follow_mouse = 1;
        sensitivity = 0;

        touchpad = {
          natural_scroll = true;
          disable_while_typing = true;
          tap-to-click = true;
        };
      };

      animations = {
        enabled = true;

        bezier = [
          "overshot, 0.05, 0.9, 0.1, 1.1"
          "smoothOut, 0.36, 0, 0.66, -0.56"
          "smoothIn, 0.25, 1, 0.5, 1"
          "gruvbox, 0.4, 0, 0.2, 1"
        ];

        animation = [
          "windows, 1, 5, overshot, slide"
          "windowsOut, 1, 4, smoothOut, slide"
          "windowsMove, 1, 4, gruvbox"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 5, smoothIn"
          "workspaces, 1, 6, gruvbox, slide"
        ];
      };

      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2;
      };

      master = {
        new_status = "master";
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
        animate_manual_resizes = true;
        enable_swallow = true;
        swallow_regex = "^(kitty|Kitty)$";
      };

      "$mod" = "SUPER";

      bind = [
        "$mod, Return, exec, kitty"
        "$mod, Q, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, kitty -e yazi"
        "$mod, R, exec, kitty -e nvim /"
        "$mod, B, exec, brave"

        "$mod, Z, exec, noctalia-shell ipc call launcher toggle"
        "$mod, Tab, exec, noctalia-shell ipc call launcher toggle"

        "$mod, X, exec, noctalia-shell ipc call controlCenter toggle"
        "$mod, W, exec, noctalia-shell ipc call wallpaper random"
        "$mod, C, exec, noctalia-shell ipc call bluetooth togglePanel"
        "$mod, V, exec, noctalia-shell ipc call sessionMenu show"

        "$mod, F, fullscreen, 1"
        "$mod SHIFT, F, fullscreen, 0"
        "$mod, Space, togglefloating,"
        "$mod, P, pseudo,"
        "$mod, J, togglesplit,"

        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, h, movefocus, l"
        "$mod, l, movefocus, r"
        "$mod, k, movefocus, u"
        "$mod, j, movefocus, d"

        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, l, movewindow, r"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, j, movewindow, d"

        "$mod SHIFT, L, exec, noctalia-shell ipc call lockScreen lock"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        ", Print, exec, grimblast copy area"
        "SHIFT, Print, exec, grimblast save area ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
        "CTRL, Print, exec, grimblast copy screen"

        "$mod SHIFT, C, exec, hyprpicker -a"

        "$mod, N, exec, noctalia-shell ipc call notifications showHistory"
        "$mod SHIFT, N, exec, noctalia-shell ipc call notifications closeAll"
      ];

      binde = [
        ", XF86AudioRaiseVolume, exec, pamixer -i 5"
        ", XF86AudioLowerVolume, exec, pamixer -d 5"
        ", XF86AudioMute, exec, pamixer -t"
        ", XF86MonBrightnessUp, exec, brightnessctl s +5%"
        ", XF86MonBrightnessDown, exec, brightnessctl s 5%-"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      exec-once = [
        "noctalia-shell"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];
    };
  };
}
