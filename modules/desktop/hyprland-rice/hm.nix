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

  # Bu modülün kurduğu dizin (aşağıda home.file) — repo duvar kağıtları +
  # kullanıcının elle attıkları (recursive olduğundan dizin yazılabilir)
  wallDir = "${config.home.homeDirectory}/Pictures/Wallpapers";

  # Hyprland rice'ının kendi varsayılan duvar kağıdı — BİLEREK Stylix'ten
  # (config.stylix.image) bağımsız: rice kendi içinde tam kendi kendine yeterli
  # kalsın diye. İlk renk tohumu ve theme-apply --restore fallback'i burayı
  # kullanır; SUPER+T ile her zaman değiştirilebilir.
  defaultWallpaper = ../wallpapers/misty-forest.jpg;

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
    FALLBACK="${defaultWallpaper}"
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
  # (ilk açılış); OSC yalnız çalışma anında üzerine boyar.
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
  waybarThemes = import ./waybar-themes.nix { inherit pkgs lib; };
  waybarCompat = import ./waybar-omarchy-compat.nix { inherit pkgs; };

  # --- Rofi teması (adi1090x/rofi type-5/style-4 portu) ---
  # style4:     üst kaynak + mono renk katmanı birleştirilmiş tek .rasi
  # monoColors: aynı paletin @değişken sürümü (wallpaper-grid.rasi import eder)
  # İkisi de waybar-mono.css'ten beslenir — waybar temalarıyla tek renk kaynağı.
  rofiThemes = import ./rofi-themes.nix { inherit pkgs lib; };

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
  options.rice.hyprland.enable = lib.mkOption {
    type = lib.types.bool;
    # Gömülü HM: sistemdeki rice.hyprland.enable'ı osConfig ile izler —
    # tek anahtar configuration.nix'te. Standalone `hms` yolunda osConfig
    # olmadığından varsayılan false; gerekirse home.nix'te elle açılır.
    default = osConfig.rice.hyprland.enable or false;
    defaultText = lib.literalExpression "osConfig.rice.hyprland.enable or false";
    description = "Hyprland + Matugen rice'ının HM katmanı (waybar, rofi, swaync, swww, cava, tema motoru)";
  };

  options.rice.hyprland.waybarTheme = lib.mkOption {
    type = lib.types.str;
    default = osConfig.rice.hyprland.waybarTheme or "current";
    defaultText = lib.literalExpression ''osConfig.rice.hyprland.waybarTheme or "current"'';
    description = "Waybar temasının varsayılanı — bkz. waybar-themes.nix ve `waybar-theme --list`.";
  };

  config = lib.mkIf cfg.enable {
    # Tema duvar kağıtları (recursive: kullanıcı dizine kendi dosyasını da
    # atabilir). SUPER+T'nin wallpaper-picker'ı ve --random burayı okur.
    home.file."Pictures/Wallpapers" = {
      source = ../wallpapers;
      recursive = true;
    };

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
      pkgs.matugen # 4.0.0 — Material You (HCT) renk üretimi
      pkgs.awww # 0.12.1 — animasyonlu duvar kağıdı daemon'u (eski adı swww)
      pkgs.cava # 0.10.7 — ses görselleştirici (autostart YOK: idle bütçesi)
      pkgs.libnotify
      pkgs.playerctl # bazı waybar temalarının custom/media modülü
      pkgs.adwaita-icon-theme
      pkgs.grim
      pkgs.slurp
      pkgs.satty
      theme-apply
      wallpaper-picker
      theme-sequences-apply
      waybar-theme
      hypr-screenshot
    ];

    # Yeni terminaller tema paletini bash başlangıcında alır (HYPRLAND_INSTANCE_
    # SIGNATURE guard'ı: yalnız Hyprland oturumunda, TTY/başka bağlamda hiç
    # çalışmasın). mkBefore ŞART — shell.nix'in fastfetch'i bu satırdan SONRA
    # koşmalı ki logo/renk halkaları tema paletiyle çizilsin.
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

        # Klavye aydınlatması — duvar kağıdının baskın rengine döner.
        # Olay-güdümlü: yalnız tema değişince tek bir yazma olur, idle'da
        # hiçbir şey dönmez (4.28W bütçesi). Animasyon çalışıyorsa döngü
        # durumu 0.5 sn'de bir tazelediği için renk canlı geçer.
        [templates.keyboard]
        input_path = '${cfgHome}/matugen/templates/keyboard-color'
        output_path = '${cfgHome}/kbd-rgb/color'
        post_hook = 'kbd-rgb set "$(cat ${cfgHome}/kbd-rgb/color)" >/dev/null 2>&1 || true'

        [templates.terminal]
        input_path = '${cfgHome}/matugen/templates/terminal-sequences'
        output_path = '${cfgHome}/theme-switcher/sequences'
        post_hook = '${theme-sequences-apply}/bin/theme-sequences-apply --all || true'

        # hyprlock.conf `source` ile bunu en başta okur (hyprlang $değişken).
        # hook yok — hyprlock her açılışta dosyayı taze okur.
        [templates.hyprlock]
        input_path = '${cfgHome}/matugen/templates/hyprlock-colors.conf'
        output_path = '${cfgHome}/hypr/hyprlock-colors.conf'
      '';

      "matugen/templates/hypr-colors.lua".source = ./templates/hypr-colors.lua;
      "matugen/templates/waybar-colors.css".source = ./templates/waybar-colors.css;
      "matugen/templates/rofi-colors.rasi".source = ./templates/rofi-colors.rasi;
      "matugen/templates/swaync-colors.css".source = ./templates/swaync-colors.css;
      "matugen/templates/cava-config".source = ./templates/cava-config;
      "matugen/templates/terminal-sequences".source = ./templates/terminal-sequences;
      "matugen/templates/keyboard-color".source = ./templates/keyboard-color;
      "matugen/templates/hyprlock-colors.conf".source = ./templates/hyprlock-colors.conf;

      # Ana rofi teması — adi1090x/rofi type-5/style-4 portu. Üst kaynak dosya
      # + mono renk katmanı build-time'da TEK dosyada birleştirilir
      # (rofi-themes.nix); programs.rofi.theme buna mutlak yolla işaret eder.
      # Renkler literal hex olarak gömülü, @import YOK — rofi 2.0 gradient
      # içinde @değişken'i ayrıştıramıyor (gerekçe rofi-themes.nix'te).
      "rofi/type-5-style-4.rasi".source = rofiThemes.style4;

      # waybar-mono paletinin @değişken sürümü — wallpaper-grid.rasi bunu
      # import eder. matugen'in colors.rasi'siyle AYNI değişken adlarını taşır:
      # rofi'yi duvar kağıdına göre değişen renklere döndürmek istersen
      # aşağıdaki import satırında dosya adını colors.rasi yapman yeter.
      "rofi/mono-colors.rasi".source = rofiThemes.monoColors;

      # wallpaper-picker'ın ikon grid teması. @import MUTLAK yol: bu dosya
      # store'a symlink'lenir, göreli import store dizininde arardı.
      "rofi/wallpaper-grid.rasi".text = ''
        @import "${cfgHome}/rofi/mono-colors.rasi"

        /* Launcher (type-5/style-4) ile aynı mono paleti — waybar'ın V-temaları
         * ve bu grid tek renk ailesinde kalsın diye. rofi 2.0'ın dahili
         * varsayılan teması Solarized LIGHT olduğundan * tabanı + element
         * durumları açıkça override edilmezse grid öğeleri beyaz görünür
         * (kanıt: rofi -dump-theme). */
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

    #### Rofi (2.0 — Wayland yerli) ####
    programs.rofi = {
      enable = true;
      terminal = "ghostty";
      font = "JetBrainsMono Nerd Font 12";
      extraConfig."show-icons" = true;
      # DİKKAT: buraya writeText türevi (attrset) verilemez — HM modülü onu
      # rasi attrset'i sanıp çevirmeye kalkar ("Unhandled value type set").
      # Mutlak yol dizesi ver; dosyanın kendisi aşağıda xdg.configFile'da.
      theme = "${cfgHome}/rofi/type-5-style-4.rasi";
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
    # swaync yalnız Hyprland oturumunda çalışsın (HM modülü generic
    # graphical-session.target'a bağlar → mkForce ile daralt)
    systemd.user.services.swaync.Install.WantedBy =
      lib.mkForce [ "hyprland-session.target" ];

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
    # Renk dosyaları hiç yoksa matugen'i rice'ın kendi varsayılan duvar
    # kağıdıyla (defaultWallpaper — Stylix'ten bağımsız) bir kez koştur —
    # ilk Hyprland girişinde waybar/swaync renksiz başlamasın.
    # post_hook'lar oturum dışında zararsız (hepsi `|| true` korumalı).
    home.activation.hyprRiceSeedColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${cfgHome}/hypr/colors.lua" ]; then
        verboseEcho "hyprland-rice: ilk renk tohumu (matugen + rice varsayılan duvar kağıdı)"
        mkdir -p "${cfgHome}/hypr" "${cfgHome}/waybar" "${cfgHome}/rofi" \
                 "${cfgHome}/swaync" "${cfgHome}/cava"
        run ${lib.getExe pkgs.matugen} -c "${cfgHome}/matugen/config.toml" \
          image "${defaultWallpaper}" ${matugenArgs} --source-color-index 0 \
          || verboseEcho "matugen tohumu başarısız — ilk girişte theme-apply --restore telafi eder"
      fi
    '';
  };
}
