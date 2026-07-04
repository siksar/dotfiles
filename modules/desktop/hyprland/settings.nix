{ ... }:

{
  wayland.windowManager.hyprland.extraConfig = ''
    # --- Renk şeması (Caelestia canlı yazar; fallback: HM activation) ---
    source = ~/.config/hypr/scheme/current.conf

    # --- Monitör ---
    monitor = eDP-1, 2560x1600@165, 0x0, 1
    monitor = , preferred, auto, 1

    # --- Ortam Değişkenleri ---
    # iGPU-only: AQ_DRM_DEVICES = card1 (amdgpu). Nvidia env kaldırıldı.
    env = AQ_DRM_DEVICES,/dev/dri/card1
    env = XCURSOR_SIZE,24
    env = HYPRCURSOR_SIZE,24
    env = GDK_BACKEND,wayland,x11,*
    env = QT_QPA_PLATFORM,wayland;xcb
    env = SDL_VIDEODRIVER,wayland
    env = CLUTTER_BACKEND,wayland
    env = XDG_CURRENT_DESKTOP,Hyprland
    env = XDG_SESSION_TYPE,wayland
    env = XDG_SESSION_DESKTOP,Hyprland
    env = QT_WAYLAND_DISABLE_WINDOWDECORATION,1
    env = LIBVA_DRIVER_NAME,radeonsi
    env = ELECTRON_OZONE_PLATFORM_HINT,auto

    general {
      gaps_in = 5
      gaps_out = 10
      border_size = 0
      col.active_border = rgba($primarye6)
      col.inactive_border = rgba($onSurfaceVariant11)
      resize_on_border = false
      allow_tearing = false
      layout = dwindle
    }

    decoration {
      rounding = 0
      shadow {
        enabled = true
        range = 14
        render_power = 3
        color = rgba($shadow66)
      }
      blur {
        enabled = true
        size = 2
        passes = 1
        special = true
        brightness = 0.60
        contrast = 0.75
      }
    }

    render {
      direct_scanout = true
      new_render_scheduling = true  # PSR residency'yi artırır: frame'ler gereksiz yere push edilmez
    }

    group {
      col.border_active = rgba($primarye6)
      col.border_inactive = rgba($onSurfaceVariant11)
      col.border_locked_active = rgba($tertiarye6)
      col.border_locked_inactive = rgba($onSurfaceVariant11)

      groupbar {
        font_size = 12
        font_family = monospace
        font_weight_active = ultraheavy
        font_weight_inactive = normal
        indicator_height = 0
        indicator_gap = 5
        height = 22
        gaps_in = 5
        gaps_out = 0
        text_color = rgb(ffffff)
        text_color_inactive = rgba(ffffff90)
        col.active = rgba(00000040)
        col.inactive = rgba(00000020)
        gradients = true
        gradient_rounding = 0
        gradient_round_only_edges = false
      }
    }

    animations {
      enabled = true
      bezier = easeOutQuint,0.23,1,0.32,1
      bezier = easeInOutCubic,0.65,0.05,0.36,1
      bezier = linear,0,0,1,1
      bezier = almostLinear,0.5,0.5,0.75,1.0
      bezier = quick,0.15,0,0.1,1

      animation = global, 1, 10, default
      animation = border, 1, 5.39, easeOutQuint
      animation = windows, 1, 3.79, easeOutQuint
      animation = windowsIn, 1, 4.1, easeOutQuint, popin 87%
      animation = windowsOut, 1, 1.49, linear, popin 87%
      animation = fadeIn, 1, 1.73, almostLinear
      animation = fadeOut, 1, 1.46, almostLinear
      animation = fade, 1, 3.03, quick
      animation = layers, 1, 3.81, easeOutQuint
      animation = layersIn, 1, 4, easeOutQuint, fade
      animation = layersOut, 1, 1.5, linear, fade
      animation = fadeLayersIn, 1, 1.79, almostLinear
      animation = fadeLayersOut, 1, 1.39, almostLinear
      animation = workspaces, 0, 0, ease
      animation = specialWorkspace, 1, 3, easeOutQuint, slidevert
    }

    dwindle {
      preserve_split = true
      force_split = 2
    }

    master {
      new_status = master
    }

    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
      disable_scale_notification = true
      focus_on_activate = true
      anr_missed_pings = 3
      on_focus_under_fullscreen = 1
      vrr = 0  # VRR kapalı: PSR ile çakışıyor; AC'de elle açılabilir
    }

    cursor {
      hide_on_key_press = true
      warp_on_change_workspace = 1
      inactive_timeout = 3  # 3sn hareketsizlikte imleci gizle → PSR devreye girsin
    }

    binds {
      hide_special_on_workspace_change = true
    }

    # --- Touchpad jestleri (caelestia dots değerleri) ---
    gestures {
      workspace_swipe_distance = 700
      workspace_swipe_cancel_ratio = 0.15
      workspace_swipe_min_speed_to_force = 5
      workspace_swipe_direction_lock = true
      workspace_swipe_direction_lock_threshold = 10
      workspace_swipe_create_new = true
    }
    gesture = 3, horizontal, workspace

    input {
      kb_layout = us
      follow_mouse = 1
      touchpad {
        natural_scroll = true
      }
      sensitivity = 0
    }
  '';
}
