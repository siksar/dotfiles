# Waybar — bar'ın kendisi + 16 temalı çalışma-anı geçiş sistemi.
#
# Temalar store'dan DOĞRUDAN koşar (`waybar -c <dir>/config.jsonc -s …`);
# HM'in ~/.config/waybar/{config,style.css} symlink'lerine hiç dokunulmaz.
# Bu yüzden tema değişimi REBUILD İSTEMEZ: `waybar-theme --pick` / SUPER+W.
#
# UYARI: aşağıdaki ExecStart mkForce'u HM'in `programs.waybar` modülünün
# `waybar` adlı bir unit ve `Service.ExecStart` anahtarı üretmesine bağlı.
# HM yükseltmesinden sonra hâlâ doğru birimi hedeflediğini doğrula.
{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.hyprland;
  cfgHome = config.xdg.configHome;

  # --- Fan profili durumu (waybar custom/fan modülü) ---
  # Kaynak repodaki power-profiles-daemon modülünün ikamesi: burada güç profili
  # yerine aorus-laptop'un fan_mode sysfs'ini gösterir (PPD sistemde açık ama
  # bu modül fan modunu izler, güç profilini değil). waybar'ın beklediği JSON'u
  # basar. Modül interval="once"+signal=8 ile
  # çalışır — idle'da HİÇ poll etmez; fan-mode-cycle.service mod değişince
  # SIGRTMIN+8 gönderir (gigabyte-wmi.nix).
  fan-status = pkgs.writeShellScriptBin "fan-status" ''
    P=/sys/devices/platform/aorus_laptop/fan_mode
    cur=$(cat "$P" 2>/dev/null || echo "?")
    case "$cur" in
      0) icon="󰈐"; name="Dengeli"; class="balanced" ;;
      1) icon="󰤄"; name="Sessiz";  class="quiet"    ;;
      2) icon="󰓅"; name="Gaming";  class="gaming"   ;;
      5) icon="󰈸"; name="Turbo";   class="turbo"    ;;
      *) icon="󰈐"; name="?";       class="balanced" ;;
    esac
    printf '{"text":"%s","tooltip":"Fan profili : %s","class":"%s"}\n' \
      "$icon" "$name" "$class"
  '';

  # --- Waybar çoklu tema sistemi (atif-1402/minimal-waybar-themes portları) ---
  # waybarThemes: { "V1" = <derivation>; … } — her biri build-time'da yeniden
  # yazılmış bağımsız config.jsonc/style.css dizini (bkz. waybar-themes.nix).
  # waybarCompat: omarchy-* shim'leri, YALNIZ waybar-launch'un PATH'ine girer.
  waybarThemes = import ./themes.nix { inherit pkgs lib; };
  waybarCompat = import ./omarchy-compat.nix { inherit pkgs; };

  # ExecStart override — HM'in ürettiği ~/.config/waybar/{config,style.css}
  # symlink'lerine hiç dokunmadan, rofi/state dosyasıyla seçilen temayı store
  # yolundan çalıştırır. "current" (veya bilinmeyen bir state) → argümansız
  # `waybar`, yani HM modülünün ürettiği bar (mevcut Anto98765 portu).
  waybar-launch = pkgs.writeShellScript "waybar-launch" ''
    set -euo pipefail
    export PATH="${waybarCompat}/bin:$PATH"
    export OMARCHY_PATH="${waybarCompat}"

    stateFile="${config.xdg.stateHome}/waybar-theme/current"
    theme="${cfg.waybarTheme}"
    [ -r "$stateFile" ] && theme="$(cat "$stateFile")"

    case "$theme" in
  ${lib.concatStrings (
    lib.mapAttrsToList (name: drv: ''
      ${name}) exec ${pkgs.waybar}/bin/waybar -c ${drv}/config.jsonc -s ${drv}/style.css ;;
    '') waybarThemes
  )}
      *) exec ${pkgs.waybar}/bin/waybar ;;
    esac
  '';

  # waybar-theme --list/--pick/--reset/<ad> — rebuild'siz geçiş. `home.packages`'a
  # girer (waybar-launch'un aksine, bu kullanıcı kabuğundan çağrılmalı).
  waybar-theme = pkgs.writeShellScriptBin "waybar-theme" ''
    set -euo pipefail
    stateDir="${config.xdg.stateHome}/waybar-theme"
    stateFile="$stateDir/current"
    names="current ${lib.concatStringsSep " " (lib.attrNames waybarThemes)}"

    case "''${1:-}" in
      ""|--show)
        if [ -r "$stateFile" ]; then cat "$stateFile"; else echo "current"; fi
        ;;
      --list)
        printf '%s\n' $names
        ;;
      --reset)
        rm -f "$stateFile"
        systemctl --user restart waybar.service
        ;;
      --pick)
        choice=$(printf '%s\n' $names | rofi -dmenu -p "Waybar teması") || exit 0
        [ -z "$choice" ] && exit 0
        exec "$0" "$choice"
        ;;
      -h|--help)
        echo "kullanım: waybar-theme [--list|--show|--reset|--pick|<tema-adı>]"
        ;;
      *)
        match=0
        for n in $names; do [ "$n" = "$1" ] && match=1; done
        if [ "$match" -ne 1 ]; then
          echo "bilinmeyen tema: $1 (bkz. waybar-theme --list)" >&2
          exit 1
        fi
        mkdir -p "$stateDir"
        printf '%s' "$1" > "$stateFile"
        systemctl --user restart waybar.service
        ;;
    esac
  '';
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ waybar-theme ];

    #### Waybar ####
    programs.waybar = {
      enable = true;
      systemd = {
        enable = true;
        # graphical-session.target generic bir systemd target'ı — waybar
        # yalnız bu oturumda aktifleşsin diye Hyprland'in kendi target'ına
        # bağlanır. (HM'de `target` string'i `targets` listesine dönüştü.)
        targets = [ "hyprland-session.target" ];
      };
      # Düzen — Anto98765/My-Hyprland-Rice portu: transparan tam genişlik bar,
      # koyu pill gruplar. Solda start grubu (menü+RAM) + tepsi, ortada numaralı
      # workspace'ler, sağda control grubu (ağ·ses·pil) + fan profili + saat.
      # cava YOK (kaynak tasarımda da yok) — idle bütçesi (4.28W) geri kazanıldı.
      settings.mainBar = {
        layer = "top";
        modules-left = [ "group/start" "tray" ];
        modules-center = [ "hyprland/workspaces" ];
        modules-right = [ "group/control" "custom/fan" "clock" ];

        "group/start" = {
          modules = [ "custom/appmenu" "memory" ];
          orientation = "horizontal";
        };
        "group/control" = {
          modules = [ "network" "pulseaudio" "battery" ];
          orientation = "horizontal";
        };

        # Uygulama menüsü — kaynaktaki launcher.sh yerine mevcut rofi
        # (tema programs.rofi.theme'den). İkon: Arch logosu yerine Nix karı.
        "custom/appmenu" = {
          format = "{icon}";
          format-icons.default = "󱄅";
          on-click = "rofi -show drun";
          tooltip = false;
        };
        memory = {
          format = "   {}% ";
          interval = 30; # varsayılanla aynı — idle bütçesi için bilinçli görünür
          on-click = "ghostty -e btop"; # kaynakta kitty; bizde ghostty
        };
        tray = {
          icon-size = 21;
          spacing = 10;
        };

        # Workspace'ler: NUMARASIZ boş kapsüller (kullanıcı isteği — kaynakta
        # 1-5 numaralıydı), her monitörde 5 kalıcı. Kapsül boyutunu CSS
        # padding/min-width verir; aktif olan border ile genişler.
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons.default = "";
          sort-by-number = true;
          persistent-workspaces."*" = 5;
        };

        network = {
          # kaynaktaki interface="wlo1" hardcode'u atıldı (bizde wlan0, waybar
          # otomatik bulur); on-click-right networkmanager_dmenu kurulu değil.
          # IP/gateway hiçbir format/tooltip'te YOK (kullanıcı isteği —
          # kaynakta ethernet formatı {ipaddr}/{cidr} gösteriyordu)
          format = "";
          format-wifi = "";
          format-ethernet = "󰈀";
          format-disconnected = ""; # boş format modülü gizler
          tooltip-format = "{ifname} 󰊗";
          tooltip-format-wifi = "{essid}  ";
          tooltip-format-ethernet = "{ifname} ";
          tooltip-format-disconnected = "Bağlantı yok  ";
          max-length = 50;
          on-click = "swaync-client -t -sw";
        };
        pulseaudio = {
          format = "{icon}";
          format-bluetooth = "{icon}";
          format-muted = "";
          format-icons = {
            headphone = " ";
            hands-free = " ";
            headset = "";
            phone = "";
            phone-muted = "";
            portable = "";
            car = "";
            default = [ "" "" ];
          };
          tooltip-format = "Ses düzeyi : {volume}%";
          scroll-step = 1;
          on-click = "swaync-client -t -sw";
          on-click-middle = "pactl set-sink-mute @DEFAULT_SINK@ toggle";
          on-click-right = "pavucontrol";
        };
        battery = {
          bat = "BAT1"; # firmware BAT1 verir (CLAUDE.md güç notu)
          interval = 30; # idle bütçesi: 30 sn yeterli
          # kaynak repoda state adı 'mid' ama CSS'i '.med' arıyordu (upstream
          # bug) — burada ikisi de 'mid'.
          states = { charged = 100; mid = 40; critical = 20; };
          format = "{capacity}";
          format-charging = "";
          format-plugged = "";
          format-icons = [ "󰁺" "󰁼" "󰁾" "󰂀" "󰁹" ];
          tooltip-format = "Pil : {capacity} %\nKalan : {time}";
          on-click = "swaync-client -t -sw";
        };

        # Fan profili — kaynaktaki power-profiles-daemon modülünün yerine fan
        # modunu (aorus fan_mode) gösterir. Sinyal tabanlı: idle'da poll YOK;
        # fan-mode-cycle.service mod değişince SIGRTMIN+8 yollar
        # (gigabyte-wmi.nix). Tıklama SUPER+M ile aynı yol (polkit şifresiz).
        "custom/fan" = {
          exec = "${fan-status}/bin/fan-status";
          return-type = "json";
          interval = "once";
          signal = 8;
          on-click = "systemctl start --no-block fan-mode-cycle.service";
        };

        clock = {
          format = "{:%I : %M %p}";
          format-alt = "{:%d %m %Y}"; # tıklayınca tarih
          interval = 60; # kaynakta 1 sn — format dakika çözünürlüklü, israftı
          tooltip = false;
        };
      };
      # Renk importu MUTLAK yolla başa eklenir (style.css store'a symlink'li —
      # göreli @import store'da arardı)
      style = ''
        @import "${cfgHome}/waybar/colors.css";
      '' + builtins.readFile ./waybar-style.css;
    };
    # Çoklu tema geçişi: HM'in ürettiği unit'in ExecStart'ı waybar-launch ile
    # değiştirilir — targets/systemd.enable bloğu YUKARIDA aynen kalıyor
    # (oturum kapsamlama bu ayardan gelir, burada dokunulmuyor). HM'in kendi
    # waybar modülü unit'i değiştirirse bu override'ın hâlâ doğru birimi
    # hedeflediğini doğrula.
    systemd.user.services.waybar.Service.ExecStart = lib.mkForce "${waybar-launch}";
  };
}
