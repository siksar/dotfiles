# Medya yığını — sway rice'ın parçası (vyrx-dev/dotfiles portu).
{ config, lib, pkgs, ... }:

lib.mkIf config.rice.sway.enable {
  # network.startWhenNeeded = systemd socket activation: ilk bağlantıya kadar
  # sıfır maliyet, GNOME oturumunda hiç tetiklenmez (idle bütçesine dokunmaz —
  # aynı gerekçeyle hyprland-rice'ta cava autostart'ı da kapalı bırakılmıştı).
  services.mpd = {
    enable = true;
    musicDirectory = "${config.home.homeDirectory}/Music";
    network.startWhenNeeded = true;
    extraConfig = ''
      audio_output {
        type "pulse"
        name "PipeWire"
      }
      audio_output {
        type "fifo"
        name "cava"
        path "/tmp/mpd.fifo"
        format "44100:16:2"
      }
    '';
  };

  # programs.rmpc.config tipi types.lines (ham RON metni) — attrset DEĞİL.
  programs.rmpc = {
    enable = true;
    config = ''
      #![enable(implicit_some)]
      #![enable(unwrap_newtypes)]
      #![enable(unwrap_variant_newtypes)]
      (
          address: "127.0.0.1:6600",
          volume_step: 5,
          max_fps: 30,
          on_song_change: ["fetch-lyrics"],
      )
    '';
  };

  home.packages = with pkgs; [
    mpv
    yt-dlp
    cava # otomatik başlamaz — Alt+c ile elle (idle bütçesi)
    (pkgs.writeShellApplication {
      name = "fetch-lyrics";
      runtimeInputs = [ pkgs.curl pkgs.jq pkgs.gnused pkgs.libnotify ];
      # DİKKAT: rmpc'nin on_song_change hook'una ne ile çağırdığı (argv mı,
      # env değişkenleri mi) burada DOĞRULANMADI — ilk gerçek şarkı
      # değişiminde `rmpc` çalışırken bu script'in aldığı argümanları/env'i
      # kontrol et (ör. `env > /tmp/rmpc-hook-debug` ekleyip tekrar dene).
      text = ''
        # rmpc on_song_change hook'u: LRCLIB'den senkronize söz çeker.
        artist="''${1:-}"; title="''${2:-}"; out="''${3:-}"
        [ -z "$artist" ] || [ -z "$title" ] && exit 0
        lrc="$HOME/Music/lyrics/''${out}.lrc"
        [ -f "$lrc" ] && exit 0
        mkdir -p "$HOME/Music/lyrics"
        resp=$(curl -sG "https://lrclib.net/api/get" \
          --data-urlencode "artist_name=$artist" \
          --data-urlencode "track_name=$title") || exit 0
        synced=$(echo "$resp" | jq -r '.syncedLyrics // empty')
        [ -z "$synced" ] && exit 0
        echo "$synced" > "$lrc"
      '';
    })
  ];
}
