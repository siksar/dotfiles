# Tema motoru — PAYLAŞILAN VERİ, modül DEĞİL.
#
# Neden ayrı: matugen renkleri waybar/rofi/swaync/hyprland/terminal/klavyeye
# dağıtan `theme-apply` birden çok modülün ihtiyaç duyduğu tek parça. Modül
# olsaydı diğerleri ona erişemezdi (HM modülleri birbirinin let'ini göremez);
# saf fonksiyon olunca herkes `import ./engine.nix { … }` ile alır.
#
# Tüketiciler: theme/matugen.nix (paketler + activation), wm/binds.lua (SUPER+T).
{ pkgs, lib, config }:

let
  cfgHome = config.xdg.configHome;

  # theme/matugen.nix'in home.file ile kurduğu dizin — repo duvar kağıtları +
  # kullanıcının elle attıkları (recursive olduğundan dizin yazılabilir)
  wallDir = "${config.home.homeDirectory}/Pictures/Wallpapers";

  # Hyprland rice'ının kendi varsayılan duvar kağıdı — BİLEREK Stylix'ten
  # (config.stylix.image) bağımsız: rice kendi içinde tam kendi kendine yeterli
  # kalsın diye. İlk renk tohumu ve theme-apply --restore fallback'i burayı
  # kullanır; SUPER+T ile her zaman değiştirilebilir.
  defaultWallpaper = ../../../lib/wallpapers/misty-forest.jpg;

  # Referans repo ile aynı matugen kipi: koyu + Material You "tonal spot".
  # NOT: matugen HCT renk uzayı kullanır (Material You standardı) — "Oklab"
  # değil; ikisi de algısal-düzgün uzaylardır, ayrıntı: Documentation/desktop.md
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
in
{
  inherit theme-apply wallpaper-picker theme-sequences-apply
          defaultWallpaper matugenArgs;
}
