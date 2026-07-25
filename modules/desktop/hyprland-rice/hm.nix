# Hyprland + Matugen dinamik tema rice'ı — HM katmanı
#
# Mimari (enes-less/theme-switcher'ın NixOS'a uyarlanmış portu):
#
#   SUPER+T → wallpaper-picker (rofi ikon grid'i)
#                └→ theme-apply <resim>
#                     ├→ swww img (animasyonlu geçiş — renkler üretilirken
#                     │   kullanıcı duvar kağıdını hemen görür)
#                     └→ matugen image (Material You/HCT renk üretimi)
#                          ├→ ~/.config/hypr/colors.lua      → hyprctl reload
#                          ├→ ~/.config/waybar/colors.css    → waybar restart
#                          ├→ ~/.config/rofi/colors.rasi     → (rofi her açılışta okur)
#                          ├→ ~/.config/swaync/colors.css    → swaync-client --reload-css
#                          └→ ~/.config/cava/config          → pkill -USR2 cava
#
# Referans repodaki bash+jq+sed çift şablon katmanı bilinçli olarak atıldı:
# orada statik JSON temaları da desteklemek için gerekiyordu; burada tek
# "dinamik" tema var, matugen'in kendi şablon motoru yeterli.
#
# matugen çıktıları HM yönetiminde DEĞİL (runtime'da üzerine yazılır) —
# vesktop'taki mutable-copy hilesine bu yüzden gerek yok; checkLinkTargets
# bu dosyaları hiç görmez. İlk tohum home.activation'da.
{ config, lib, pkgs, osConfig ? { }, ... }:

let
  cfg = config.rice.hyprland;
  cfgHome = config.xdg.configHome;

  # gnome-hm.nix'in kurduğu dizin — repo duvar kağıtları + kullanıcının
  # elle attıkları (recursive olduğundan dizin yazılabilir)
  wallDir = "${config.home.homeDirectory}/Pictures/Wallpapers";

  # Referans repo ile aynı matugen kipi: koyu + Material You "tonal spot".
  # NOT: matugen HCT renk uzayı kullanır (Material You standardı) — "Oklab"
  # değil; ikisi de algısal-düzgün uzaylardır, ayrıntı: docs/hyprland-rice.md
  #
  # --source-color-index BURADA YOK ama her çağrıda VERİLMEK ZORUNDA (matugen
  # 4.0.0): matugen bir resimden BİRDEN ÇOK aday kaynak renk çıkarıp seçimi
  # ETKİLEŞİMLİ (ok tuşları) sorar. Tema motoru matugen'i HER ZAMAN TTY'siz
  # koşturur (hl.exec_cmd, systemd user servisi, home.activation) → seçici
  # "IO error: not a terminal" ile patlar, HİÇ renk dosyası üretilmez → waybar
  # colors.css bulamayıp start-limit-hit ile ölür.
  # theme-apply adayı KROMAYA göre kendisi seçer (aşağıda); activation tohumu
  # index 0 kullanır (bir kereliğine kozmetik).
  matugenArgs = "-m dark -t scheme-tonal-spot";

  # --- Tema motoru çekirdeği (apply-theme.sh portu) ---
  theme-apply = pkgs.writeShellScriptBin "theme-apply" ''
    set -euo pipefail

    WALL_DIR="${wallDir}"
    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/theme-switcher"
    STATE="$STATE_DIR/current-wallpaper"
    FALLBACK="${config.stylix.image}"
    mkdir -p "$STATE_DIR"

    usage() { echo "kullanım: theme-apply <resim> | --random | --restore" >&2; exit 1; }

    # awww-daemon normalde systemd servisi (hyprland-session.target); henüz
    # ayağa kalkmadıysa kısa süre bekle.
    # NOT: nixpkgs bu revizyonda swww'yi awww'ya yeniden adlandırdı — binary
    # adları da awww/awww-daemon oldu (aynı 0.12.1, CLI birebir aynı).
    ensure_swww() {
      ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && return 0
      systemctl --user start awww.service 2>/dev/null || true
      for _ in $(seq 1 40); do
        ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && return 0
        sleep 0.05
      done
      echo "uyarı: awww-daemon hazır değil, duvar kağıdı atlandı" >&2
      return 1
    }

    MODE="apply"
    WP="''${1:-}"
    case "$WP" in
      "") usage ;;
      --restore)
        MODE="restore"
        WP="$(cat "$STATE" 2>/dev/null || true)"
        [ -f "$WP" ] || WP="$FALLBACK"
        ;;
      --random)
        # -L ŞART: HM duvar kağıtlarını ~/Pictures/Wallpapers'a store SYMLINK'i
        # olarak koyar; -L olmadan '-type f' symlink'leri görmez → "resim yok".
        WP="$(find -L "$WALL_DIR" -maxdepth 1 -type f \
          \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
          | shuf -n1 || true)"
        [ -n "$WP" ] || { echo "hata: $WALL_DIR içinde resim yok" >&2; exit 1; }
        ;;
    esac
    [ -f "$WP" ] || { echo "hata: resim bulunamadı: $WP" >&2; exit 1; }

    # 1) Önce duvar kağıdı — renkler üretilirken geçiş animasyonu görünsün
    #    (geçiş seti referans repodan)
    if ensure_swww; then
      transitions=(outer wipe grow)
      angles=(0 29 90 151 180 209 270 331)
      t=''${transitions[$RANDOM % ''${#transitions[@]}]}
      a=''${angles[$RANDOM % ''${#angles[@]}]}
      ${pkgs.awww}/bin/awww img "$WP" \
        --transition-type "$t" --transition-angle "$a" \
        --transition-duration 0.75 --transition-fps 165 >/dev/null 2>&1 || true
    fi

    # 2) Renk üretimi — matugen şablonları işler, post_hook'lar bileşenleri
    #    tazeler. restore kipinde yalnız renkler eksikse koşar (login'de
    #    gereksiz hyprctl reload titremesi olmasın).
    if [ "$MODE" != "restore" ] || [ ! -f "${cfgHome}/hypr/colors.lua" ]; then
      # ADAY SEÇİMİ (miasma bug'ı, 16 Tem): --source-color-index 0 baskın
      # rengi seçer; koyu/soluk duvar kağıtlarında baskın renk hep nötr koyu
      # gri-mavi → HER resim aynı maviye çalan paleti veriyordu (ölçüldü:
      # miasma index0 #383c43→mavi, index1 #8c9373→zeytin yeşili). Adayları
      # --dry-run ile gez (yazma/hook yok), EN KROMATİK olanı (max−min RGB)
      # seç. Aday sayısı resme göre değişir; geçersiz index'te matugen hata
      # verir → döngü kırılır.
      best=0; bestc=-1
      for i in 0 1 2 3 4 5; do
        hex=$(${lib.getExe pkgs.matugen} image "$WP" --dry-run -j hex \
                --source-color-index "$i" ${matugenArgs} 2>/dev/null \
              | ${pkgs.jq}/bin/jq -r '.colors.source_color.default.color' \
              || true)
        case "$hex" in "#"??????) ;; *) break ;; esac
        r=$((16#''${hex:1:2})); g=$((16#''${hex:3:2})); b=$((16#''${hex:5:2}))
        mx=$r; if [ $g -gt $mx ]; then mx=$g; fi; if [ $b -gt $mx ]; then mx=$b; fi
        mn=$r; if [ $g -lt $mn ]; then mn=$g; fi; if [ $b -lt $mn ]; then mn=$b; fi
        if [ $((mx - mn)) -gt $bestc ]; then bestc=$((mx - mn)); best=$i; fi
      done
      ${lib.getExe pkgs.matugen} image "$WP" ${matugenArgs} --source-color-index "$best"
    fi

    printf '%s\n' "$WP" > "$STATE"
  '';

  # --- Duvar kağıdı seçici (wallpaper-picker.sh portu: rofi ikon grid'i) ---
  wallpaper-picker = pkgs.writeShellScriptBin "wallpaper-picker" ''
    set -euo pipefail

    WALL_DIR="${wallDir}"
    notify() { ${pkgs.libnotify}/bin/notify-send "Tema motoru" "$1"; }

    [ -d "$WALL_DIR" ] || { notify "Duvar kağıdı dizini yok: $WALL_DIR"; exit 1; }

    # -L ŞART: duvar kağıtları HM store-symlink'i (yukarıdaki --random notu);
    # -L olmadan grid boş gelir. %f yine WALL_DIR'daki adı basar (hedefi değil).
    mapfile -d "" -t files < <(
      find -L "$WALL_DIR" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        -printf '%f\0' | sort -z
    )
    [ "''${#files[@]}" -gt 0 ] || { notify "$WALL_DIR boş"; exit 1; }

    # rofi ikon protokolü: girdi\0icon\x1f<resim-yolu>
    input=""
    for f in "''${files[@]}"; do
      input+="''${f}\0icon\x1f''${WALL_DIR}/''${f}\n"
    done

    choice="$(printf '%b' "$input" | ${pkgs.rofi}/bin/rofi -dmenu -i \
      -p "Duvar kağıdı" -theme "${cfgHome}/rofi/wallpaper-grid.rasi")" || exit 0
    [ -n "$choice" ] || exit 0

    exec ${theme-apply}/bin/theme-apply "$WALL_DIR/$choice"
  '';

  # --- Terminal ANSI paleti uygulayıcı (pywal deseni) ---
  # matugen'in ürettiği OSC dizilerini terminallere basar:
  #   argümansız → mevcut terminale (bash başlangıcı, yeni pencereler)
  #   --all      → TÜM açık PTY'lere (tema değişince canlı yeniden boyama)
  # Diziler emülatör tarafından yorumlanır, ekrana BASILMAZ — açık TUI'ler
  # (vim, claude) bozulmaz. Ghostty'nin statik Stylix teması taban kalır
  # (GNOME oturumu + ilk açılış); OSC yalnız çalışma anında üzerine boyar.
  theme-sequences-apply = pkgs.writeShellScriptBin "theme-sequences-apply" ''
    SEQ_FILE="${cfgHome}/theme-switcher/sequences"
    [ -r "$SEQ_FILE" ] || exit 0
    # '#' yorum satırları atılır; kalan \n'ler silinir ki PTY'ye yeni satır
    # basılmasın (açık terminali kaydırırdı). \033/\\ kaçışlarını %b çözer.
    seq=$(grep -v '^#' "$SEQ_FILE" | tr -d '\n')
    [ -n "$seq" ] || exit 0
    if [ "''${1:-}" = "--all" ]; then
      for pts in /dev/pts/[0-9]*; do
        [ -w "$pts" ] && printf '%b' "$seq" > "$pts" 2>/dev/null || true
      done
    else
      printf '%b' "$seq"
    fi
  '';

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
in
{
  options.rice.hyprland.enable = lib.mkOption {
    type = lib.types.bool;
    # Gömülü HM: sistemdeki rice.hyprland.enable'ı osConfig ile izler —
    # tek anahtar configuration.nix'te. Standalone `hms` yolunda osConfig
    # olmadığından varsayılan false; gerekirse home.nix'te elle açılır.
    default = osConfig.rice.hyprland.enable or false;
    defaultText = lib.literalExpression "osConfig.rice.hyprland.enable or false";
    description = "Hyprland + Matugen rice'ının HM katmanı (waybar, rofi, swaync, swww, cava, tema motoru)";
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
    };

    home.packages = [
      pkgs.matugen # 4.0.0 — Material You (HCT) renk üretimi
      pkgs.awww # 0.12.1 — animasyonlu duvar kağıdı daemon'u (eski adı swww)
      pkgs.cava # 0.10.7 — ses görselleştirici (autostart YOK: idle bütçesi)
      pkgs.libnotify
      theme-apply
      wallpaper-picker
      theme-sequences-apply
    ];

    # Yeni terminaller tema paletini bash başlangıcında alır. YALNIZ Hyprland
    # oturumunda: GNOME'da ghostty statik Stylix temasında kalmalı (oradaki
    # duvar kağıdı Stylix'in). mkBefore ŞART — shell.nix'in fastfetch'i bu
    # satırdan SONRA koşmalı ki logo/renk halkaları tema paletiyle çizilsin.
    programs.bash.initExtra = lib.mkBefore ''
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        ${theme-sequences-apply}/bin/theme-sequences-apply
      fi
    '';
    # JetBrainsMono Nerd Font zaten sistem genelinde: configuration.nix:41

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
        autostart = ./lua/autostart.lua;
        binds = ./lua/binds.lua;
        main = ./lua/main.lua;
        rules = ./lua/rules.lua;
        theme = ./lua/theme.lua;
      };
    };

    #### Matugen — tema motorunun merkezi ####
    xdg.configFile = {
      "matugen/config.toml".text = ''
        # HM üretir — elle düzenleme home.nix tarafında yapılır.
        # Duvar kağıdını matugen DEĞİL theme-apply (swww) basar; matugen
        # yalnız renk dosyalarını yazar, post_hook'lar bileşenleri tazeler.
        [config]

        [templates.hypr]
        input_path = '${cfgHome}/matugen/templates/hypr-colors.lua'
        output_path = '${cfgHome}/hypr/colors.lua'
        post_hook = 'hyprctl reload >/dev/null 2>&1 || true'

        [templates.waybar]
        input_path = '${cfgHome}/matugen/templates/waybar-colors.css'
        output_path = '${cfgHome}/waybar/colors.css'
        post_hook = 'systemctl --user try-restart waybar.service || true'

        [templates.rofi]
        input_path = '${cfgHome}/matugen/templates/rofi-colors.rasi'
        output_path = '${cfgHome}/rofi/colors.rasi'
        # hook yok — rofi her açılışta dosyayı taze okur

        [templates.swaync]
        input_path = '${cfgHome}/matugen/templates/swaync-colors.css'
        output_path = '${cfgHome}/swaync/colors.css'
        post_hook = 'swaync-client --reload-css >/dev/null 2>&1 || true'

        [templates.cava]
        input_path = '${cfgHome}/matugen/templates/cava-config'
        output_path = '${cfgHome}/cava/config'
        post_hook = 'pkill -USR2 -x cava || true'

        [templates.terminal]
        input_path = '${cfgHome}/matugen/templates/terminal-sequences'
        output_path = '${cfgHome}/theme-switcher/sequences'
        post_hook = '${theme-sequences-apply}/bin/theme-sequences-apply --all || true'
      '';

      "matugen/templates/hypr-colors.lua".source = ./templates/hypr-colors.lua;
      "matugen/templates/waybar-colors.css".source = ./templates/waybar-colors.css;
      "matugen/templates/rofi-colors.rasi".source = ./templates/rofi-colors.rasi;
      "matugen/templates/swaync-colors.css".source = ./templates/swaync-colors.css;
      "matugen/templates/cava-config".source = ./templates/cava-config;
      "matugen/templates/terminal-sequences".source = ./templates/terminal-sequences;

      # Ana rofi (drun) teması — programs.rofi.theme buna mutlak yolla işaret
      # eder. @import MUTLAK yol: dosya store'a symlink'lenir, göreli import
      # store dizininde arardı.
      "rofi/zixar-rice.rasi".text = ''
        @import "${cfgHome}/rofi/colors.rasi"

        /* rofi 2.0'ın dahili varsayılan teması Solarized LIGHT'tır
         * (background #fdf6e3, krem). Stillemediğimiz her widget o açık rengi
         * miras alır; ÖZELLİKLE daha-özel durum selektörü 'element normal.normal'
         * generic 'element' kuralımızı ezerek liste öğelerini beyaz yapar. Bu
         * yüzden * tabanını VE tüm element durumlarını (normal/alternate/selected
         * × normal/urgent/active) açıkça override ediyoruz; yoksa arama kutusu ve
         * uygulama listesi beyaz-üstüne-beyaz görünür (kanıt: rofi -dump-theme). */
        * {
            background-color: @bg;
            text-color: @fg;
        }
        window {
            width: 40%;
            background-color: @bg;
            border: 2px;
            border-color: @accent;
            border-radius: 12px;
            padding: 12px;
        }
        mainbox { background-color: transparent; }
        inputbar {
            children: [ prompt, entry ];
            background-color: @bg-alt;
            text-color: @fg;
            padding: 8px;
            border-radius: 8px;
        }
        prompt { text-color: @accent; background-color: transparent; }
        entry  { text-color: @fg; background-color: transparent; placeholder-color: @fg-dim; }
        listview {
            lines: 8;
            spacing: 4px;
            padding: 8px 0px 0px;
            background-color: transparent;
        }
        element {
            padding: 6px;
            border-radius: 8px;
            background-color: transparent;
            text-color: @fg;
        }
        element normal.normal    { background-color: transparent; text-color: @fg; }
        element alternate.normal { background-color: transparent; text-color: @fg; }
        element selected.normal  { background-color: @accent;     text-color: @on-accent; }
        element normal.urgent    { background-color: transparent; text-color: @urgent; }
        element selected.urgent  { background-color: @urgent;      text-color: @bg; }
        element normal.active    { background-color: transparent; text-color: @accent; }
        element selected.active  { background-color: @accent;      text-color: @on-accent; }
        element-icon { background-color: transparent; size: 1.2em; }
        element-text { background-color: transparent; text-color: inherit; }
      '';

      # wallpaper-picker'ın ikon grid teması. @import MUTLAK yol: bu dosya
      # store'a symlink'lenir, göreli import store dizininde arardı.
      "rofi/wallpaper-grid.rasi".text = ''
        @import "${cfgHome}/rofi/colors.rasi"

        /* Aynı rofi-2.0-Solarized-light tuzağı için zixar-rice.rasi'deki nota bak:
         * * tabanı + element durumları açıkça override edilmezse grid öğeleri
         * beyaz görünür. */
        * {
            background-color: @bg;
            text-color: @fg;
        }
        window {
            width: 70%;
            background-color: @bg;
            border: 2px;
            border-color: @accent;
            border-radius: 12px;
            padding: 16px;
        }
        mainbox { background-color: transparent; }
        inputbar {
            children: [ prompt, entry ];
            background-color: @bg-alt;
            text-color: @fg;
            padding: 8px;
            border-radius: 8px;
        }
        prompt { text-color: @accent; background-color: transparent; }
        entry  { text-color: @fg; background-color: transparent; placeholder-color: @fg-dim; }
        listview {
            columns: 4;
            lines: 2;
            spacing: 12px;
            padding: 12px 0px 0px;
            background-color: transparent;
        }
        element {
            orientation: vertical;
            padding: 8px;
            border-radius: 10px;
            background-color: transparent;
            text-color: @fg-dim;
        }
        element normal.normal    { background-color: transparent; text-color: @fg-dim; }
        element alternate.normal { background-color: transparent; text-color: @fg-dim; }
        element selected.normal  { background-color: @accent;     text-color: @on-accent; }
        element-icon { background-color: transparent; size: 160px; }
        element-text {
            background-color: transparent;
            horizontal-align: 0.5;
            text-color: inherit;
        }
      '';
    };

    #### Waybar ####
    programs.waybar = {
      enable = true;
      systemd = {
        enable = true;
        # graphical-session.target GNOME oturumunda DA aktifleşir — waybar
        # GNOME'a sızmasın diye yalnız Hyprland'in target'ına bağlanır.
        # (HM'de `target` string'i `targets` listesine dönüştü.)
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

    #### Rofi (2.0 — Wayland yerli) ####
    programs.rofi = {
      enable = true;
      terminal = "ghostty";
      font = "JetBrainsMono Nerd Font 12";
      extraConfig."show-icons" = true;
      # DİKKAT: buraya writeText türevi (attrset) verilemez — HM modülü onu
      # rasi attrset'i sanıp çevirmeye kalkar ("Unhandled value type set").
      # Mutlak yol dizesi ver; dosyanın kendisi aşağıda xdg.configFile'da.
      theme = "${cfgHome}/rofi/zixar-rice.rasi";
    };

    #### SwayNC ####
    services.swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "top";
        control-center-width = 400;
        notification-window-width = 400;
      };
      style = ''
        @import "${cfgHome}/swaync/colors.css";
      '' + builtins.readFile ./swaync-style.css;
    };
    # swaync yalnız Hyprland oturumunda çalışsın — GNOME kendi bildirim
    # sistemini kullanıyor (HM modülü graphical-session.target'a bağlar,
    # o GNOME'da da aktif olur → mkForce ile daralt)
    systemd.user.services.swaync.Install.WantedBy =
      lib.mkForce [ "hyprland-session.target" ];

    #### awww (eski adı swww) — duvar kağıdı daemon'u (HM'de hazır modülü yok) ####
    systemd.user.services.awww = {
      Unit = {
        Description = "awww wallpaper daemon (Hyprland oturumu)";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    #### İlk kurulum tohumu ####
    # Renk dosyaları hiç yoksa matugen'i Stylix duvar kağıdıyla bir kez
    # koştur — ilk Hyprland girişinde waybar/swaync renksiz başlamasın.
    # post_hook'lar oturum dışında zararsız (hepsi `|| true` korumalı).
    home.activation.hyprRiceSeedColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${cfgHome}/hypr/colors.lua" ]; then
        verboseEcho "hyprland-rice: ilk renk tohumu (matugen + stylix duvar kağıdı)"
        mkdir -p "${cfgHome}/hypr" "${cfgHome}/waybar" "${cfgHome}/rofi" \
                 "${cfgHome}/swaync" "${cfgHome}/cava"
        run ${lib.getExe pkgs.matugen} -c "${cfgHome}/matugen/config.toml" \
          image "${config.stylix.image}" ${matugenArgs} --source-color-index 0 \
          || verboseEcho "matugen tohumu başarısız — ilk girişte theme-apply --restore telafi eder"
      fi
    '';
  };
}
