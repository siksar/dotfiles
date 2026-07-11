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

    # --- Tearing (VARSAYILAN KAPALI — VRR yolu tercih edildi) ---
    # En düşük gecikme isteyen esports oyunları için: aşağıdaki bloğun yorumunu
    # kaldır VE settings.nix'te general:allow_tearing = true yap. docs/gaming.md.
    # windowrule {
    #   name = steam-tearing
    #   match:class = ^(steam_app_.*)$
    #   immediate = true
    # }
  '';
}
