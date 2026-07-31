# Omarchy'nin waybar temalarının varsaydığı komutları NixOS karşılıklarına
# çeviren ince kabuk katmanı. Bilerek `home.packages`'a değil, YALNIZ waybar
# systemd unit'inin PATH'ine eklenir (bkz. hm.nix `waybar-launch`) — "omarchy-*"
# isimleri kullanıcı kabuğuna sızmasın diye.
{ pkgs }:

let
  bin = name: text:
    pkgs.writeShellScriptBin name ''
      #!/usr/bin/env bash
      set -euo pipefail
      ${text}
    '';

  script = name: text: pkgs.writeShellScript name text;

  omarchy-menu = bin "omarchy-menu" ''
    case "''${1:-}" in
      power)
        choice=$(printf '%s\n' "Kilitle" "Uyku" "Yeniden Başlat" "Kapat" "Oturumu Kapat" \
          | ${pkgs.rofi}/bin/rofi -dmenu -p "Güç") || exit 0
        case "$choice" in
          Kilitle) loginctl lock-session ;;
          # `suspend` DEĞİL: düz suspend, sleep.conf'taki 25 dk'lık hibernate
          # sayacını hiç başlatmaz (bkz. modules/hardware/power.nix) → makine
          # s2idle'da sonsuza kalıp pil yer.
          Uyku) systemctl suspend-then-hibernate ;;
          "Yeniden Başlat") systemctl reboot ;;
          Kapat) systemctl poweroff ;;
          "Oturumu Kapat") hyprctl dispatch exit ;;
        esac
        ;;
      *)
        exec ${pkgs.rofi}/bin/rofi -show drun
        ;;
    esac
  '';

  omarchy-launch-or-focus-tui = bin "omarchy-launch-or-focus-tui" ''
    case "''${1:-}" in
      wiremix) exec pavucontrol ;;
      *) exec ghostty -e "''${1:-btop}" ;;
    esac
  '';

  omarchy-launch-wifi = bin "omarchy-launch-wifi" ''exec ghostty -e nmtui'';
  omarchy-launch-bluetooth = bin "omarchy-launch-bluetooth" ''exec ghostty -e bluetuith'';

  omarchy-launch-floating-terminal-with-presentation =
    bin "omarchy-launch-floating-terminal-with-presentation" ''exec ghostty -e "$@"'';

  # gpu-screen-recorder'ın toggle mantığı — bölgesiz, tam ekran kaydı.
  omarchy-cmd-screenrecord = bin "omarchy-cmd-screenrecord" ''
    dir="''${XDG_VIDEOS_DIR:-$HOME/Videos}"
    mkdir -p "$dir"
    if pgrep -x gpu-screen-recorder >/dev/null; then
      pkill -INT -x gpu-screen-recorder
      notify-send -a "Ekran Kaydı" "Durduruldu"
      exit 0
    fi
    out="$dir/kayit-$(date +%Y%m%d-%H%M%S).mp4"
    notify-send -a "Ekran Kaydı" "Başladı" "$out"
    gpu-screen-recorder -w screen -f 60 -a default_output -o "$out" &
    disown
  '';

  omarchy-toggle-notification-silencing = bin "omarchy-toggle-notification-silencing" ''
    exec swaync-client -d
  '';

  # hypridle.service'i durdurup başlatarak boşta kilidi/DPMS'i aç-kapa eder.
  omarchy-toggle-idle = bin "omarchy-toggle-idle" ''
    if systemctl --user is-active --quiet hypridle.service; then
      systemctl --user stop hypridle.service
      notify-send "Boşta kilidi" "Kapatıldı"
    else
      systemctl --user start hypridle.service
      notify-send "Boşta kilidi" "Açıldı"
    fi
  '';

  # Omarchy'nin güncelleme denetleyicisi yok — boş çıktı + başarısız çıkış
  # waybar'ın custom modülünü gizlemesine yol açar (istenen davranış).
  omarchy-update-available = bin "omarchy-update-available" ''exit 1'';
  omarchy-update = bin "omarchy-update" ''
    notify-send "Güncelleme" "nixos-rebuild üzerinden yönetiliyor"
  '';

  screen-recording-indicator = script "screen-recording-indicator" ''
    #!/usr/bin/env bash
    if pgrep -x gpu-screen-recorder >/dev/null; then
      echo '{"text":"","class":"active"}'
    else
      echo '{"text":""}'
    fi
  '';

  notification-silencing-indicator = script "notification-silencing-indicator" ''
    #!/usr/bin/env bash
    state=$(swaync-client -D 2>/dev/null || echo false)
    if [ "$state" = "true" ]; then
      echo '{"text":"","class":"active"}'
    else
      echo '{"text":""}'
    fi
  '';

  # hypridle kapalıyken (omarchy-toggle-idle ile durdurulduğunda) görünür —
  # diğer indicator'larla aynı desen: sapma varsa göster, varsayılan boşta gizli.
  idle-indicator = script "idle-indicator" ''
    #!/usr/bin/env bash
    if systemctl --user is-active --quiet hypridle.service; then
      echo '{"text":""}'
    else
      echo '{"text":"","class":"active"}'
    fi
  '';
in
pkgs.symlinkJoin {
  name = "waybar-omarchy-compat";
  paths = [
    omarchy-menu
    omarchy-launch-or-focus-tui
    omarchy-launch-wifi
    omarchy-launch-bluetooth
    omarchy-launch-floating-terminal-with-presentation
    omarchy-cmd-screenrecord
    omarchy-toggle-notification-silencing
    omarchy-toggle-idle
    omarchy-update-available
    omarchy-update
  ];
  postBuild = ''
    mkdir -p $out/default/waybar/indicators
    ln -s ${screen-recording-indicator} $out/default/waybar/indicators/screen-recording.sh
    ln -s ${notification-silencing-indicator} $out/default/waybar/indicators/notification-silencing.sh
    ln -s ${idle-indicator} $out/default/waybar/indicators/idle.sh
  '';
}
