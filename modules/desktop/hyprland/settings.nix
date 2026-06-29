{ osConfig, ... }:

let
  theme = osConfig.desktop.theme;
in
{
  wayland.windowManager.hyprland.settings = {
    # --- Monitör Tanımı ---
    monitor = [
      "eDP-1, 2560x1600@165, 0x0, 1"  # dahili ekran, native çözünürlük, 165Hz
      ", preferred, auto, 1"            # harici monitörler otomatik
    ];

    # --- Wayland / NVIDIA Ortam Değişkenleri ---
    env = [
      "XCURSOR_SIZE,24"
      "HYPRCURSOR_SIZE,24"
      "GDK_BACKEND,wayland,x11,*"
      "QT_QPA_PLATFORM,wayland;xcb"
      "SDL_VIDEODRIVER,wayland"
      "CLUTTER_BACKEND,wayland"
      "XDG_CURRENT_DESKTOP,Hyprland"
      "XDG_SESSION_TYPE,wayland"
      "XDG_SESSION_DESKTOP,Hyprland"
      "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
      # NVIDIA PRIME offload + Wayland uyumu
      "LIBVA_DRIVER_NAME,radeonsi"
      "GBM_BACKEND,nvidia-drm"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"
      "NVD_BACKEND,direct"
      "ELECTRON_OZONE_PLATFORM_HINT,auto"
    ];

    general = {
      gaps_in = 5;
      gaps_out = 10;
      border_size = 2;
      "col.active_border" = theme.colors.activeBorder;
      "col.inactive_border" = theme.colors.inactiveBorder;
      resize_on_border = false;
      allow_tearing = false;
      layout = "dwindle";
    };

    decoration = {
      rounding = 0;
      shadow = {
        enabled = true;
        range = 2;
        render_power = 3;
        color = "rgba(1a1a1aee)";
      };
      blur = {
        enabled = true;
        size = 2;
        passes = 1;    # 2→1: GPU tasarrufu
        special = true;
        brightness = 0.60;
        contrast = 0.75;
      };
    };

    # --- Render & Enerji Verimliliği ---
    render = {
      direct_scanout = true; # Fullscreen uygulamalar compositor'u bypass eder
      explicit_sync  = 2;    # NVIDIA Wayland explicit sync (2 = auto)
    };

    group = {
      "col.border_active" = theme.colors.activeBorder;
      "col.border_inactive" = theme.colors.inactiveBorder;
      "col.border_locked_active" = theme.colors.activeBorder;
      "col.border_locked_inactive" = theme.colors.inactiveBorder;

      groupbar = {
        font_size = 12;
        font_family = "monospace";
        font_weight_active = "ultraheavy";
        font_weight_inactive = "normal";
        indicator_height = 0;
        indicator_gap = 5;
        height = 22;
        gaps_in = 5;
        gaps_out = 0;
        text_color = "rgb(ffffff)";
        text_color_inactive = "rgba(ffffff90)";
        "col.active" = "rgba(00000040)";
        "col.inactive" = "rgba(00000020)";
        gradients = true;
        gradient_rounding = 0;
        gradient_round_only_edges = false;
      };
    };

    animations = {
      enabled = true;
      bezier = [
        "easeOutQuint,0.23,1,0.32,1"
        "easeInOutCubic,0.65,0.05,0.36,1"
        "linear,0,0,1,1"
        "almostLinear,0.5,0.5,0.75,1.0"
        "quick,0.15,0,0.1,1"
      ];
      animation = [
        "global, 1, 10, default"
        "border, 1, 5.39, easeOutQuint"
        "windows, 1, 3.79, easeOutQuint"
        "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
        "windowsOut, 1, 1.49, linear, popin 87%"
        "fadeIn, 1, 1.73, almostLinear"
        "fadeOut, 1, 1.46, almostLinear"
        "fade, 1, 3.03, quick"
        "layers, 1, 3.81, easeOutQuint"
        "layersIn, 1, 4, easeOutQuint, fade"
        "layersOut, 1, 1.5, linear, fade"
        "fadeLayersIn, 1, 1.79, almostLinear"
        "fadeLayersOut, 1, 1.39, almostLinear"
        "workspaces, 0, 0, ease"
        "specialWorkspace, 1, 3, easeOutQuint, slidevert"
      ];
    };

    dwindle = {
      preserve_split = true;
      force_split = 2;
    };

    scrolling = {
      column_width = 0.49;
    };

    master = {
      new_status = "master";
    };

    misc = {
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
      disable_scale_notification = true;
      focus_on_activate = true;
      anr_missed_pings = 3;
      on_focus_under_fullscreen = 1;
      vrr = 1;    # VRR / Adaptive Sync → boşta Hz düşer, güç tasarrufu
      vfr = true; # Variable Frame Rate → değişiklik yoksa frame render etme
    };

    cursor = {
      hide_on_key_press = true;
      warp_on_change_workspace = 1;
    };

    binds = {
      hide_special_on_workspace_change = true;
    };

    input = {
      kb_layout = "us";
      follow_mouse = 1;
      touchpad = {
        natural_scroll = true;
      };
      sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
    };
  };
}
