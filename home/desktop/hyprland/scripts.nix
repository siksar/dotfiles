# MODÜL DEĞİL, fonksiyon. home.packages'a girmez (GNOME/COSMIC'e sızmasın);
# Lua/waybar store yoluyla çağırır.
{ pkgs }:

let
  osdNotify = ''
    id_file="''${XDG_RUNTIME_DIR:-/tmp}/hypr-osd.id"
    osd() { # $1 metin, $2 çubuk değeri (0-100; boşsa çubuk yok)
      local id=0
      [ -r "$id_file" ] && id=$(cat "$id_file")
      local args=(-a OSD -c osd -u low -t 1200 -e -p -r "$id")
      [ -n "''${2:-}" ] && args+=(-h "int:value:$2")
      notify-send "''${args[@]}" "$1" > "$id_file"
    }
  '';
in
{
  # Başlatıcı: layer-shell LD_PRELOAD ile (libwayland'dan önce); launcher.py bunları çocuklardan siler.
  launcher =
    let
      python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
      typelibs = pkgs.lib.makeSearchPath "lib/girepository-1.0" (map (p: p.out or p) (with pkgs; [
        gtk4
        gtk4-layer-shell
        glib
        gobject-introspection
        pango
        gdk-pixbuf
        harfbuzz
        graphene
      ]));
    in
    pkgs.runCommand "hypr-launcher"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = "hypr-launcher";
      } ''
      install -Dm644 ${./launcher/launcher.py} $out/share/hypr-launcher/launcher.py
      makeWrapper ${python}/bin/python3 $out/bin/hypr-launcher \
        --add-flags $out/share/hypr-launcher/launcher.py \
        --set GI_TYPELIB_PATH ${typelibs} \
        --set LD_PRELOAD ${pkgs.gtk4-layer-shell}/lib/libgtk4-layer-shell.so
    '';

  osd = pkgs.writeShellApplication {
    name = "hypr-osd";
    runtimeInputs = with pkgs; [ wireplumber brightnessctl libnotify coreutils gawk ];
    text = osdNotify + ''
      case "''${1:-}" in
        volume)
          case "''${2:-}" in
            up)   wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
                  wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
            down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
            mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
          esac
          out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
          pct=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<<"$out")
          if [[ $out == *MUTED* ]]; then
            osd "󰝟  Ses kapalı"
          else
            osd "󰕾  Ses %$pct" "$pct"
          fi
          ;;
        mic)
          # Fn+F4'ü fn-bridge (system/arch/aerox16) KENDİSİ çeviriyor; burada
          # yalnız durum gösterilir. Toggle burada da yapılsaydı mikrofon aynı
          # yere dönerdi (gnome.nix "FN TUŞLARI ÇAKIŞMASI" ile aynı tuzak).
          # Köprü tuşu eylemden ÖNCE üretiyor → kısa bekleme.
          sleep 0.2
          if [[ $(wpctl get-volume @DEFAULT_AUDIO_SOURCE@) == *MUTED* ]]; then
            osd "󰍭  Mikrofon kapalı"
          else
            osd "󰍬  Mikrofon açık"
          fi
          ;;
        brightness)
          case "''${2:-}" in
            up)   brightnessctl -q -e4 -n2 set 5%+ ;;
            down) brightnessctl -q -e4 -n2 set 5%- ;;
          esac
          pct=$(brightnessctl -m | awk -F, '{ gsub("%", "", $4); print $4 }')
          osd "󰃠  Parlaklık %$pct" "$pct"
          ;;
        *) echo "kullanım: hypr-osd volume up|down|mute | mic | brightness up|down" >&2; exit 2 ;;
      esac
    '';
  };

  screenshot = pkgs.writeShellApplication {
    name = "hypr-screenshot";
    runtimeInputs = with pkgs; [ grimblast satty wl-clipboard coreutils ];
    text = ''
      dir="$HOME/Pictures/Screenshots"
      mkdir -p "$dir"
      export XDG_SCREENSHOTS_DIR="$dir"
      case "''${1:-area}" in
        area)   grimblast --notify --freeze copysave area ;;
        screen) grimblast --notify copysave output ;;
        window) grimblast --notify copysave active ;;
        # Bölge → satty (ok, kutu, metin, bulanıklaştırma). Enter = panoya +
        # dosyaya kaydet ve çık; Esc = vazgeç. Dosya adındaki %… satty'nin
        # kendi chrono biçimi (shell date değil).
        edit)
          grimblast --freeze save area - \
            | satty --filename - \
                --output-filename "$dir/%Y-%m-%d_%H-%M-%S-satty.png" \
                --copy-command wl-copy \
                --actions-on-enter save-to-clipboard,save-to-file \
                --early-exit all
          ;;
        *) echo "kullanım: hypr-screenshot area|screen|window|edit" >&2; exit 2 ;;
      esac
    '';
  };

  nightLight = pkgs.writeShellApplication {
    name = "hypr-nightlight";
    runtimeInputs = with pkgs; [ libnotify systemd ];
    text = ''
      hc=hyprctl   # Hyprland'in kendi ortamından (PATH) — oturum dışında anlamsız
      off() { [ "$($hc hyprsunset identity get 2>/dev/null)" = "true" ]; }
      case "''${1:-toggle}" in
        # Waybar karosu (bar.nix custom/nightlight): durum değişince sinyal 11.
        status)
          if off; then
            printf '{"text":"󰖨  Gece ışığı","class":"off","tooltip":"Gece ışığı kapalı\\nTakvim: 21:00 → 4500 K, 07:00 → doğal\\nTıkla: aç"}\n'
          else
            printf '{"text":"󰖔  Gece ışığı","class":"on","tooltip":"Gece ışığı açık\\nTıkla: kapat (bir sonraki takvim sınırına kadar)"}\n'
          fi
          ;;
        toggle)
          if off; then
            $hc hyprsunset temperature 4500 >/dev/null
            notify-send -a "Gece ışığı" -e -t 1500 "󰖔  Gece ışığı açık · 4500 K"
          else
            $hc hyprsunset identity >/dev/null
            notify-send -a "Gece ışığı" -e -t 1500 "󰖨  Gece ışığı kapalı"
          fi
          systemctl --user kill --signal=SIGRTMIN+11 waybar.service || true
          ;;
      esac
    '';
  };

  # Waybar modülleri olay güdümlü (signal). Fan/dGPU betikleri 5 sn'de bir koşar →
  # forksuz (`read` yerleşik). hwmon numarası kayar → ada göre bulunur.
  fanStatus = pkgs.writeShellApplication {
    name = "hypr-fan-status";
    runtimeInputs = [ ];
    text = ''
      mode=unknown
      for f in /sys/bus/wmi/devices/ABBC0F75-*/fan_mode; do
        [ -r "$f" ] || continue
        read -r mode 2>/dev/null < "$f" || mode=unknown
      done
      r1=0 r2=0 temp=0
      for h in /sys/class/hwmon/hwmon*; do
        name=
        read -r name 2>/dev/null < "$h/name" || continue
        [ "$name" = aero_eg61h ] || continue
        read -r r1 2>/dev/null < "$h/fan1_input" || r1=0
        read -r r2 2>/dev/null < "$h/fan2_input" || r2=0
        t=0
        read -r t 2>/dev/null < "$h/temp1_input" || t=0
        temp=$(( t / 1000 ))
      done
      case "$mode" in
        quiet)      label="Sessiz" ;;
        balanced)   label="Dengeli" ;;
        responsive) label="Duyarlı" ;;
        gaming)     label="Oyun" ;;
        turbo)      label="Turbo" ;;
        *)          label="$mode" ;;
      esac
      printf '{"text":"󰈐  %s","class":"%s","tooltip":"Fan modu: %s\\nFan 1: %s rpm · Fan 2: %s rpm\\nEC sıcaklığı: %s°C\\nTıkla: sonraki mod"}\n' \
        "$label" "$mode" "$label" "$r1" "$r2" "$temp"
    '';
  };

  # runtime_status sysfs okuması dGPU'yu uyandırmaz (nvidia-smi uyandırırdı).
  dgpuStatus = pkgs.writeShellApplication {
    name = "hypr-dgpu-status";
    runtimeInputs = [ ];
    text = ''
      st=unknown
      read -r st 2>/dev/null < /sys/bus/pci/devices/0000:64:00.0/power/runtime_status || st=unknown
      if [ "$st" = active ]; then
        printf '{"text":"󰢮","class":"active","tooltip":"NVIDIA RTX 5060 uyanık"}\n'
      else
        printf '{"text":"","class":"%s"}\n' "$st"
      fi
    '';
  };

  # Sinyal systemd üzerinden: süreç adı `.waybar-wrapped`, pkill -x waybar bulmaz.
  dnd = pkgs.writeShellApplication {
    name = "hypr-dnd";
    runtimeInputs = with pkgs; [ mako systemd gnugrep ];
    text = ''
      on() { makoctl mode | grep -qx do-not-disturb; }
      case "''${1:-status}" in
        toggle)
          makoctl mode -t do-not-disturb >/dev/null
          systemctl --user kill --signal=SIGRTMIN+8 waybar.service || true
          ;;
        # Waybar: açılan paneldeki karo ve kapalı adadaki küçük işaret (mini:
        # yalnız AÇIKKEN görünür; boş metin modülü gizler).
        status)
          if on; then
            printf '{"text":"󰂛  Rahatsız etme","class":"on","tooltip":"Rahatsız etme AÇIK — bildirimler geçmişe düşüyor\\nSol tık: kapat · Sağ tık: hepsini temizle"}\n'
          else
            printf '{"text":"󰂚  Rahatsız etme","class":"off","tooltip":"Bildirimler açık\\nSol tık: sustur · Sağ tık: hepsini temizle"}\n'
          fi
          ;;
        mini)
          if on; then
            printf '{"text":"󰂛","class":"on","tooltip":"Rahatsız etme açık"}\n'
          else
            printf '{"text":"","class":"off"}\n'
          fi
          ;;
      esac
    '';
  };

  # Klavye ışığı yalnız yanıyorsa söndürülür ve işaretlenir; sönük olan dönüşte yakılmaz.
  kbdIdle =
    let
      kbd-rgb = pkgs.callPackage ../../../system/drivers/input/keyboard-rgb/package.nix { };
    in
    pkgs.writeShellApplication {
      name = "hypr-kbd-idle";
      runtimeInputs = [ kbd-rgb pkgs.gnugrep ];
      text = ''
        mark="''${XDG_RUNTIME_DIR:-/tmp}/hypr-kbd-idle"
        case "''${1:-}" in
          off)
            if kbd-rgb status --json 2>/dev/null | grep -q '"on":true'; then
              kbd-rgb off >/dev/null 2>&1 && : > "$mark"
            fi
            ;;
          on)
            if [ -e "$mark" ]; then
              rm -f "$mark"
              kbd-rgb on >/dev/null 2>&1 || true
            fi
            ;;
        esac
      '';
    };

  # Copilot tuşu sesli asistanı (ayrıntı voice.py). CSS/JS uzantı olarak: yeniden yüklemede kalıcı.
  claudeVoice =
    let
      sessionJs = builtins.replaceStrings [ "@CHAT_CSS@" ]
        [ (builtins.toJSON (builtins.readFile ./claude-voice/chat.css)) ]
        (builtins.readFile ./claude-voice/session.js);
      extension = pkgs.runCommand "claude-voice-extension" { } ''
        mkdir $out
        cp ${pkgs.writeText "panel.css" (builtins.readFile ./claude-voice/panel.css)} $out/panel.css
        cp ${pkgs.writeText "panel.js" (builtins.readFile ./claude-voice/panel.js)} $out/panel.js
        cp ${pkgs.writeText "manifest.json" (builtins.toJSON {
          manifest_version = 3;
          name = "claude-voice panel";
          version = "1";
          content_scripts = [{
            matches = [ "https://claude.ai/*" ];
            css = [ "panel.css" ];
            run_at = "document_start";
          } {
            matches = [ "https://claude.ai/*" ];
            js = [ "panel.js" ];
            run_at = "document_idle";
          }];
        })} $out/manifest.json
      '';
    in
    pkgs.writers.writePython3Bin "claude-voice"
      {
        libraries = [ pkgs.python3Packages.websocket-client ];
        flakeIgnore = [ "E501" ];
      }
      (builtins.replaceStrings [ "@chromium@" "@extension@" "@session_js@" ]
        [ (pkgs.lib.getExe pkgs.chromium) "${extension}" (builtins.toJSON sessionJs) ]
        (builtins.readFile ./claude-voice/voice.py));
}
