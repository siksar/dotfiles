# Sway + noctalia-shell rice — HM katmanı (vyrx-dev/dotfiles portu).
# GNOME'un ve Hyprland rice'ının tamamen bağımsızı; Stylix'in her iki
# oturumda da aynı kalan uygulamalarına (ghostty/gtk/fish/tmux/yazi/…)
# dokunmaz. Ayrıntı: docs/sway-rice.md
{ config, lib, pkgs, osConfig ? { }, inputs, ... }:

let
  cfg = config.rice.sway;
  cfgHome = config.xdg.configHome;

  keybindsMod = import ./keybinds.nix { inherit lib; };
  windowRules = import ./window-rules.nix { };
  scripts = import ./scripts.nix {
    inherit pkgs lib;
    inherit (keybindsMod) binds;
  };
  noctaliaSettings = import ./noctalia.nix { inherit cfgHome; };

  swayBaseConfig = {
    modifier = "Mod4";
    terminal = "ghostty";
    menu = "noctalia msg launcher toggle";
    inherit (keybindsMod) keybindings;
    gaps.inner = 5;
    window = {
      border = 2;
      hideEdgeBorders = "smart";
    };
    floating.border = 2;
    focus.wrapping = "no";
    workspaceAutoBackAndForth = true;

    # resize modu BURADA tanımlanmalı, extraConfig'te DEĞİL. HM'nin sway modülü
    # `config.modes` için hazır bir varsayılan resize modu üretiyor (adımlar
    # "10 px", boşluklu). extraConfig'e ikinci bir `mode "resize"` bloğu yazmak
    # onu silmiyor, ÜSTÜNE yazıyor → sway her açılışta 10 tane
    # "Overwriting binding 'h' … from `resize shrink width 10 px`" uyarısı
    # basıp swaynag hata çubuğunu açıyordu. Buradan verince tek blok üretilir.
    modes.resize = {
      h = "resize shrink width 10px";
      j = "resize grow height 10px";
      k = "resize shrink height 10px";
      l = "resize grow width 10px";
      Left = "resize shrink width 10px";
      Down = "resize grow height 10px";
      Up = "resize shrink height 10px";
      Right = "resize grow width 10px";
      Return = "mode default";
      Escape = "mode default";
    };
  };
in
{
  options.rice.sway.enable = lib.mkOption {
    type = lib.types.bool;
    # hyprland-rice/hm.nix ile aynı desen: gömülü HM'de osConfig üzerinden
    # sistemdeki rice.sway.enable'ı otomatik izler. İkinci bir kullanıcı
    # toggle'ı YOK — standalone hms yolunda osConfig geçirilmezse (flake.nix'te
    # geçiriliyor) burada elle true yapılabilir.
    default = osConfig.rice.sway.enable or false;
    defaultText = lib.literalExpression "osConfig.rice.sway.enable or false";
    description = "Sway + noctalia-shell rice'ının HM katmanı";
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.sway = {
      enable = true;
      package = null; # sistem sahibi (system.nix) — çifte kurulum olmasın
      checkConfig = false; # config, henüz var olmayabilecek ~/.config/sway/colors'ı include ediyor
      systemd.enable = true; # sway-session.target üretir (GNOME'a sızmaz)

      config = lib.recursiveUpdate swayBaseConfig windowRules;

      extraConfig = ''
        include ${cfgHome}/sway/colors

        seat * xcursor_theme Bibata-Modern-Ice 24
        seat * hide_cursor 8000
        seat * hide_cursor when-typing enable

        input type:touchpad {
          dwt enabled
          tap enabled
          natural_scroll enabled
          middle_emulation enabled
          scroll_method two_finger
          click_method clickfinger
        }

        input type:keyboard {
          repeat_delay 200
          repeat_rate 60
        }

      '';
    };

    # ── noctalia-shell ──────────────────────────────────────────────────
    programs.noctalia = {
      enable = true;
      systemd.enable = true;
      settings = noctaliaSettings;
    };

    # noctalia'nın kendi HM modülü servisini config.wayland.systemd.target'a
    # (varsayılan graphical-session.target — GNOME'da da tetiklenir) bağlıyor.
    # hyprland-rice/hm.nix:595'teki swaync mkForce deseninin aynısı:
    # sway-session.target'a AÇIKÇA ez, paylaşılan hedefe DOKUNMA.
    systemd.user.services.noctalia = {
      Unit = {
        PartOf = lib.mkForce [ "sway-session.target" ];
        After = lib.mkForce [ "sway-session.target" ];
      };
      Install.WantedBy = lib.mkForce [ "sway-session.target" ];
    };

    # ── Stylix devri: bu hedefler noctalia'nın dinamik paletine bırakılır ──
    # stylix.targets.noctalia ŞARTSIZ tetiklenir (programs.noctalia var olduğu
    # anda `options.programs ? noctalia` true olur) ve theme.source'u "custom"a
    # zorlar — kapatılmazsa noctaliaSettings'teki "wallpaper" ile ÇAKIŞIR.
    stylix.targets = {
      sway.enable = false;
      cava.enable = false;
      fuzzel.enable = false;
      noctalia.enable = false;
    };

    # ── fuzzel: cheatsheet/beats/game-menu/kanshi-switch'in dmenu backend'i ──
    # Renkler noctalia'nın user-template'inden gelen AYRI bir dosyadan include
    # edilir (fuzzel.ini(5) SECTION:main → include=, [main] altında olmalı) —
    # fuzzel.ini'nin kendisi HM symlink'i olduğundan noctalia'nın TÜM dosyayı
    # yazması mümkün değil, bu yüzden sadece include edilen parça runtime'da
    # yazılıyor.
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          terminal = "ghostty";
          layer = "overlay";
          include = "${cfgHome}/fuzzel/colors.ini";
        };
        border.radius = 4;
      };
    };

    # ── noctalia şablon girdileri (input_path'lerin işaret ettiği dosyalar) ──
    xdg.configFile = {
      "noctalia/templates/sway-colors".source = ./templates/sway-colors;
      "noctalia/templates/fuzzel-colors.ini".source = ./templates/fuzzel-colors.ini;
      "noctalia/templates/cava-config".source = ./templates/cava-config;
      "noctalia/templates/terminal-sequences".source = ./templates/terminal-sequences;
    };

    # ── kanshi: monitör profilleri ──
    # DİKKAT: eDP-1 dışındaki çıktı adı/modu bu makinede DOĞRULANMADI —
    # ilk harici monitör bağlantısında `swaymsg -t get_outputs` ile kontrol et.
    services.kanshi = {
      enable = true;
      systemdTarget = "sway-session.target";
      settings = [
        {
          profile.name = "laptop-only";
          profile.outputs = [ { criteria = "eDP-1"; } ];
        }
        {
          profile.name = "laptop-harici";
          profile.outputs = [
            { criteria = "eDP-1"; position = "0,0"; }
            { criteria = "*"; position = "1920,0"; }
          ];
        }
      ];
    };

    home.packages = with pkgs; [
      scripts.sway-cheatsheet
      scripts.sway-screenshot
      scripts.sway-screenrecord
      scripts.launch-webapp
      scripts.beats
      scripts.game-menu
      scripts.toggle-output
      scripts.kanshi-switch
      scripts.run-scrcpy
      scripts.sway-theme-sequences
      scripts.nixos-generation-age

      gum
      satty
      grim
      slurp
      wl-clipboard
      brightnessctl
      ddcutil
      playerctl
      scrcpy
      chromium
      obsidian
      inputs.toofan.packages.${pkgs.system}.default
    ];

    # ── İlk kurulum tohumu ──
    # Renk dosyaları hiç yoksa Stylix paletinden bir kez seed et — noctalia
    # ilk açılışta wallpaper_scheme'i henüz üretmemişken sway/cava/terminal
    # renksiz kalmasın. hyprland-rice/hm.nix:617'deki desenin sway kopyası.
    home.activation.swayRiceSeedColors =
      let
        c = config.lib.stylix.colors;
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$HOME/.config/sway" "$HOME/.config/cava" "$HOME/.local/state/sway-rice"
        if [ ! -e "$HOME/.config/sway/colors" ]; then
          verboseEcho "sway-rice: ilk renk tohumu (Stylix ${config.stylix.base16Scheme or "palet"})"
          run tee "$HOME/.config/sway/colors" >/dev/null <<'SWAYCOLORS'
        client.focused          #${c.base0D-hex} #${c.base01-hex} #${c.base05-hex} #${c.base0D-hex} #${c.base0D-hex}
        client.focused_inactive #${c.base03-hex} #${c.base00-hex} #${c.base05-hex} #${c.base03-hex} #${c.base03-hex}
        client.unfocused        #${c.base02-hex} #${c.base00-hex} #${c.base04-hex} #${c.base02-hex} #${c.base02-hex}
        client.urgent            #${c.base08-hex} #${c.base01-hex} #${c.base05-hex} #${c.base08-hex} #${c.base08-hex}
        SWAYCOLORS
        fi
        if [ ! -e "$HOME/.config/cava/colors" ]; then
          run tee "$HOME/.config/cava/colors" >/dev/null <<'CAVACOLORS'
        [color]
        gradient = 1
        gradient_count = 2
        gradient_color_1 = '#${c.base0D-hex}'
        gradient_color_2 = '#${c.base0B-hex}'
        CAVACOLORS
        fi
      '';
  };
}
