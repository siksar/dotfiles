# Hyprland oturumu — HM katmanının çekirdeği: pencere yöneticisi, kilit ekranı,
# boşta yönetimi, polkit ajanı. Bar/launcher/bildirim/tema kendi modüllerinde:
#
#   bar/waybar.nix        çubuk + 16 tema (waybar-theme --pick)
#   launcher/rofi.nix     launcher teması + duvar kağıdı grid'i
#   notify/swaync.nix     bildirim merkezi
#   theme/matugen.nix     duvar kağıdı→renk zinciri (motor: theme/engine.nix)
#
# Hepsi aynı `desktop.hyprland.enable` bayrağını okur; bayrak BURADA tanımlı.
# Ayrıntı: Documentation/desktop.md · tuzaklar: home/desktop/CLAUDE.md
{ config, lib, pkgs, osConfig ? { }, ... }:

let
  cfg = config.desktop.hyprland;
  cfgHome = config.xdg.configHome;

  # --- Ekran görüntüsü (eskiden sway rice'ta olan sway-screenshot'ın portu) ---
  # grim/slurp wlr-screencopy protokolünü kullanır — compositor bağımsız,
  # swaymsg'e ihtiyaç yok, Hyprland'de aynen çalışır.
  hypr-screenshot = pkgs.writeShellScriptBin "hypr-screenshot" ''
    set -euo pipefail
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    out="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

    case "''${1:-region}" in
      fullscreen)
        ${pkgs.grim}/bin/grim "$out"
        ;;
      clipboard)
        geom=$(${pkgs.slurp}/bin/slurp) || exit 0
        ${pkgs.grim}/bin/grim -g "$geom" - | ${pkgs.wl-clipboard}/bin/wl-copy
        ${pkgs.libnotify}/bin/notify-send -a "Ekran Görüntüsü" "Panoya kopyalandı"
        exit 0
        ;;
      *)
        geom=$(${pkgs.slurp}/bin/slurp) || exit 0
        ${pkgs.grim}/bin/grim -g "$geom" "$out"
        ;;
    esac

    ${pkgs.libnotify}/bin/notify-send -a "Ekran Görüntüsü" "Kaydedildi" "$out"
    ${pkgs.satty}/bin/satty -f "$out" --output-filename "$out"
  '';
in
{
  options.desktop.hyprland.enable = lib.mkOption {
    type = lib.types.bool;
    # Gömülü HM: sistemdeki desktop.hyprland.enable'ı osConfig ile izler —
    # tek anahtar configuration.nix'te. Standalone `hms` yolunda osConfig
    # olmadığından varsayılan false; gerekirse home.nix'te elle açılır.
    default = osConfig.desktop.hyprland.enable or false;
    defaultText = lib.literalExpression "osConfig.desktop.hyprland.enable or false";
    description = "Hyprland + Matugen rice'ının HM katmanı (waybar, rofi, swaync, swww, cava, tema motoru)";
  };

  options.desktop.hyprland.waybarTheme = lib.mkOption {
    type = lib.types.str;
    default = osConfig.desktop.hyprland.waybarTheme or "current";
    defaultText = lib.literalExpression ''osConfig.desktop.hyprland.waybarTheme or "current"'';
    description = "Waybar temasının varsayılanı — bkz. waybar-themes.nix ve `waybar-theme --list`.";
  };

  config = lib.mkIf cfg.enable {
    # Stylix bu beş hedefte matugen ile çakışır (iki renk yazarı olamaz) —
    # rice bileşenlerinin renk sahibi matugen. Stylix GTK, ghostty, starship
    # vb. hedeflerinde tek kaynak olmaya devam eder.
    stylix.targets = {
      hyprland.enable = false;
      waybar.enable = false;
      rofi.enable = false;
      swaync.enable = false;
      cava.enable = false;
      hyprlock.enable = false;
    };

    # Stylix'in gtk hedefi gtk.enable=true yapar ama ikon teması ayarlamaz —
    # Stylix'te ayrı bir icons modülü yok. adwaita-icon-theme daha önce
    # GNOME'un systemPackages'ından geliyordu; olmadan rofi -show drun
    # (show-icons=true), nautilus ve tüm GTK diyalogları ikonsuz kalır.
    gtk.iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };

    home.packages = [
      pkgs.adwaita-icon-theme
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      hypr-screenshot
    ];

    #### Hyprland — tamamen hyprland.lua üzerinden (0.55+ Lua çağı) ####
    wayland.windowManager.hyprland = {
      enable = true;
      package = null; # sistemdeki programs.hyprland paketi (çifte kurulum olmasın)
      portalPackage = null; # portal da sistemden
      configType = "lua"; # ~/.config/hypr/hyprland.lua üretilir
      systemd.enable = true; # hyprland-session.target — aşağıdaki servisler buna bağlanır
      # `settings` attrset'i YERİNE saf Lua dosyaları: hem HM'nin attrset→Lua
      # çevirisindeki emekleme dönemi sorunlarından kaçınır (HM #9468) hem de
      # config gerçek Lua olarak okunur/düzenlenir. hyprland.lua bunları
      # otomatik require eder (alfabetik: autostart, binds, main, rules, theme).
      extraLuaFiles = {
        autostart = ./wm/autostart.lua;
        binds = ./wm/binds.lua;
        main = ./wm/main.lua;
        rules = ./wm/rules.lua;
        theme = ./wm/theme.lua;
      };
    };

    #### hyprlock — kilit ekranı (renk sahibi matugen, yukarıdaki template) ####
    programs.hyprlock = {
      enable = true;
      settings = {
        # importantPrefixes varsayılanı "$"/"source" içerir → dosyanın en
        # başına, matugen'in renk $değişkenlerinden ÖNCE gelmez diye taşınır.
        source = "${cfgHome}/hypr/hyprlock-colors.conf";

        general = {
          hide_cursor = false;
          ignore_empty_input = true;
        };

        background = [{
          path = "screenshot";
          blur_passes = 2;
          blur_size = 7;
          color = "$surface";
        }];

        input-field = [{
          size = "250, 60";
          position = "0, -100";
          monitor = "";
          dots_center = true;
          fade_on_empty = false;
          outer_color = "$primary";
          inner_color = "$bg_alt";
          font_color = "$fg";
          fail_color = "$error";
          check_color = "$tertiary";
          outline_thickness = 3;
          placeholder_text = "Parola...";
        }];

        label = [{
          text = ''cmd[update:1000] date +"%H : %M"'';
          color = "$fg";
          font_size = 64;
          position = "0, 200";
          halign = "center";
          valign = "center";
        }];
      };
    };

    #### hypridle — boşta DPMS + kilit (idle-notify protokolü, poll YOK) ####
    # loginctl lock-session → hypridle general.lock_cmd'yi (hyprlock) tetikler
    # (org.freedesktop.login1 Lock sinyali); SUPER+L de aynı yoldan geçer.
    # Suspend YOK: s2h zinciri zaten logind'de kurulu (power.nix), ikinci bir
    # yazar çakışır.
    services.hypridle = {
      enable = true;
      systemdTarget = "hyprland-session.target";
      settings = {
        general = {
          lock_cmd = "hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
        listener = [
          {
            timeout = 300; # 5 dk
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 600; # 10 dk
            on-timeout = "loginctl lock-session";
          }
        ];
      };
    };

    #### Polkit GUI ajanı ####
    # Repoda hiç polkit ajanı yok — GNOME'un gnome-shell'e gömülü ajanı bugüne
    # kadar bunu sağlıyordu. Ajan olmadan 1Password'ün "sistem kimlik
    # doğrulaması", Mullvad ve fan-mode dışındaki her polkit isteği sessizce
    # reddedilir (polkit daemon'ın kendisi networkmanager.nix'ten geliyor,
    # yalnız GUI onay penceresi eksikti).
    systemd.user.services.hyprpolkitagent = {
      Unit = {
        Description = "Hyprland polkit kimlik doğrulama ajanı";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };
  };
}
