# Sway rice scriptleri — vyrx-dev/dotfiles Scripts/'un NixOS'a uyarlanmış
# alt kümesi (docs/sway-rice.md'de tam eşleme tablosu var). noctalia'nın
# karşıladığı scriptler (powermenu, fuzzel-emoji, battery-monitor,
# set-wallpaper, toggle-wlsunset, webapp-install/remove) buraya alınmadı.
{ pkgs, lib, binds }:

let
  # Mod+G cheatsheet'inin veri kaynağı: binds listesinden index-eşlemeli
  # görüntü + eylem dosyaları. fuzzel --dmenu --index SEÇİLEN SATIRIN
  # sırasını döndürür, metnini değil — böylece "--locked XF86AudioMute" gibi
  # boşluk içeren key kombinasyonlarını parse etmeye gerek kalmaz.
  cheatsheetDisplay = pkgs.writeText "sway-cheatsheet-display" (
    lib.concatMapStringsSep "\n" (bnd: "${bnd.keys}\t[${bnd.group}] ${bnd.desc}") binds
  );
  cheatsheetActions = pkgs.writeText "sway-cheatsheet-actions" (
    lib.concatMapStringsSep "\n" (bnd: bnd.action) binds
  );
in
rec {
  sway-cheatsheet = pkgs.writeShellApplication {
    name = "sway-cheatsheet";
    runtimeInputs = [ pkgs.fuzzel pkgs.util-linux pkgs.sway ];
    text = ''
      mapfile -t actions < ${cheatsheetActions}
      idx=$(column -t -s $'\t' ${cheatsheetDisplay} | fuzzel --dmenu --index --prompt 'kısayol> ') || exit 0
      [ -z "$idx" ] && exit 0
      swaymsg -- "''${actions[$idx]}"
    '';
  };

  sway-screenshot = pkgs.writeShellApplication {
    name = "sway-screenshot";
    runtimeInputs = [ pkgs.grim pkgs.slurp pkgs.satty pkgs.libnotify pkgs.coreutils ];
    text = ''
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      out="$dir/screenshot-$(date +%Y%m%d-%H%M%S).png"

      if [ "''${1:-}" = "fullscreen" ]; then
        grim "$out"
      else
        geom=$(slurp -d) || exit 0
        grim -g "$geom" "$out"
      fi

      notify-send -a "Ekran Görüntüsü" "Kaydedildi" "$out"
      satty -f "$out" --output-filename "$out"
    '';
  };

  sway-screenrecord = pkgs.writeShellApplication {
    name = "sway-screenrecord";
    runtimeInputs = [ pkgs.gpu-screen-recorder pkgs.libnotify pkgs.procps pkgs.slurp pkgs.coreutils ];
    text = ''
      dir="''${XDG_VIDEOS_DIR:-$HOME/Videos}"
      mkdir -p "$dir"

      if pgrep -x gpu-screen-recorder >/dev/null; then
        pkill -INT -x gpu-screen-recorder
        notify-send -a "Ekran Kaydı" "Durduruldu"
        exit 0
      fi

      out="$dir/kayit-$(date +%Y%m%d-%H%M%S).mp4"
      args=(-w screen -f 60 -a default_output -o "$out")

      case "''${1:-}" in
        --with-desktop-audio) : ;;
        --with-microphone-audio) args+=(-a default_input) ;;
        --region)
          geom=$(slurp) || exit 0
          args=(-w "$geom" -f 60 -a default_output -o "$out")
          ;;
      esac

      notify-send -a "Ekran Kaydı" "Başladı" "$out"
      gpu-screen-recorder "''${args[@]}" &
      disown
    '';
  };

  launch-webapp = pkgs.writeShellApplication {
    name = "launch-webapp";
    runtimeInputs = [ pkgs.chromium ];
    text = ''
      if [ $# -lt 1 ]; then
        echo "kullanım: launch-webapp <url>" >&2
        exit 1
      fi
      url="$1"
      class="webapp-$(echo "$url" | tr -c 'a-zA-Z0-9' '-' | tr -s '-')"
      exec chromium --app="$url" --class="$class" --name="$class"
    '';
  };

  beats = pkgs.writeShellApplication {
    name = "beats";
    runtimeInputs = [ pkgs.fuzzel pkgs.mpv pkgs.procps ];
    text = ''
      declare -A stations=(
        ["Lofi Girl"]="https://www.youtube.com/watch?v=jfKfPfyJRdk"
        ["SomaFM Groove Salad"]="https://ice1.somafm.com/groovesalad-256-mp3"
        ["SomaFM Drone Zone"]="https://ice1.somafm.com/dronezone-256-mp3"
        ["Chillhop"]="https://www.youtube.com/watch?v=5yx6BWlEVcY"
      )

      if pgrep -f 'mpv --title=sway-beats' >/dev/null; then
        pkill -f 'mpv --title=sway-beats'
        exit 0
      fi

      name=$(printf '%s\n' "''${!stations[@]}" | fuzzel --dmenu --prompt 'istasyon> ') || exit 0
      [ -z "$name" ] && exit 0
      mpv --title=sway-beats --no-video "''${stations[$name]}" &
      disown
    '';
  };

  game-menu = pkgs.writeShellApplication {
    name = "game-menu";
    runtimeInputs = [ pkgs.fuzzel pkgs.glib pkgs.gnugrep pkgs.gawk ];
    text = ''
      mapfile -t games < <(
        grep -l '^Categories=.*Game' \
          "$HOME"/.local/share/applications/*.desktop \
          /run/current-system/sw/share/applications/*.desktop \
          2>/dev/null
      )
      [ ''${#games[@]} -eq 0 ] && { notify-send "Oyun bulunamadı"; exit 0; }

      declare -A names
      for f in "''${games[@]}"; do
        n=$(grep -m1 '^Name=' "$f" | cut -d= -f2-)
        names["$n"]="$f"
      done

      sel=$(printf '%s\n' "''${!names[@]}" | fuzzel --dmenu --prompt 'oyun> ') || exit 0
      [ -z "$sel" ] && exit 0
      gio launch "''${names[$sel]}"
    '';
  };

  toggle-output = pkgs.writeShellApplication {
    name = "toggle-output";
    runtimeInputs = [ pkgs.sway pkgs.jq ];
    text = ''
      name="''${1:-}"
      if [ -z "$name" ]; then
        # İsim verilmemişse: eDP-1 dışındaki İLK çıktıyı hedefle (harici monitör).
        name=$(swaymsg -t get_outputs | jq -r '[.[] | select(.name != "eDP-1")][0].name // empty')
        [ -z "$name" ] && { notify-send "Harici çıktı bulunamadı"; exit 0; }
      fi

      active=$(swaymsg -t get_outputs | jq -r --arg n "$name" '.[] | select(.name==$n) | .active')
      if [ "$active" = "true" ]; then
        swaymsg output "$name" disable
      else
        swaymsg output "$name" enable
      fi
    '';
  };

  kanshi-switch = pkgs.writeShellApplication {
    name = "kanshi-switch";
    runtimeInputs = [ pkgs.gum pkgs.kanshi ];
    text = ''
      profile=$(printf '%s\n' laptop-only laptop-harici harici-only | gum choose) || exit 0
      [ -z "$profile" ] && exit 0
      kanshictl switch "$profile"
    '';
  };

  run-scrcpy = pkgs.writeShellApplication {
    name = "run-scrcpy";
    runtimeInputs = [ pkgs.scrcpy pkgs.libnotify pkgs.procps pkgs.util-linux ];
    text = ''
      case "''${1:-}" in
        mirror)
          scrcpy
          ;;
        webcam)
          if ! lsmod | grep -q '^v4l2loopback'; then
            pkexec modprobe v4l2loopback video_nr=2 card_label=AndroidCam exclusive_caps=1
          fi
          notify-send -a scrcpy "Webcam modu: /dev/video2"
          scrcpy --v4l2-sink=/dev/video2 --no-video-playback --no-audio-playback
          ;;
        *)
          echo "kullanım: run-scrcpy mirror|webcam" >&2
          exit 1
          ;;
      esac
    '';
  };

  sway-theme-sequences = pkgs.writeShellApplication {
    name = "sway-theme-sequences";
    runtimeInputs = [ pkgs.coreutils pkgs.findutils ];
    text = ''
      seq_file="$HOME/.local/state/sway-rice/terminal-sequences"
      [ -f "$seq_file" ] || exit 0
      for pty in /dev/pts/[0-9]*; do
        [ -w "$pty" ] || continue
        cat "$seq_file" > "$pty" 2>/dev/null || true
      done
    '';
  };

  nixos-generation-age = pkgs.writeShellApplication {
    name = "nixos-generation-age";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      mtime=$(stat -c %Y /nix/var/nix/profiles/system)
      now=$(date +%s)
      days=$(( (now - mtime) / 86400 ))
      echo "$days gün önce"
    '';
  };
}
