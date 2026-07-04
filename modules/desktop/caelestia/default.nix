# Caelestia — shell (bar/launcher/bildirim/kilit) + cli (runtime tema motoru)
# Tema geçişi rebuild İSTEMEZ: launcher'da ">scheme " ile anlık değişir.
# Şema seçimi ~/.local/state/caelestia/scheme.json'da kalıcıdır.
{ inputs, lib, pkgs, config, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  # Şema geçişi sonrası koşan hook:
  # 1) tuigreet temasını yazar (greeter son temayla açılır)
  # 2) pywalfox'u tetikler (Firefox canlı boyanır)
  postHook = pkgs.writeShellScript "caelestia-post-hook" ''
    if [ -w /var/cache/tuigreet/theme.conf ]; then
      c() { printf '%s' "$SCHEME_COLOURS" | ${lib.getExe pkgs.jq} -r --arg k "$1" '.[$k]'; }
      printf 'border=#%s;text=#%s;prompt=#%s;action=#%s;button=#%s;container=#%s;input=#%s' \
        "$(c primary)" "$(c onSurface)" "$(c primary)" "$(c secondary)" \
        "$(c primary)" "$(c surface)" "$(c surfaceContainerHigh)" \
        > /var/cache/tuigreet/theme.conf
    fi
    ${pkgs.pywalfox-native}/bin/pywalfox update >/dev/null 2>&1 || true
  '';

  # Discord istemcisi olarak Vesktop kullanılıyor.
  # Özel şemalar (schemes/*.txt) paket verisine gömülür — böylece
  # `caelestia scheme set -n <isim>` ve launcher'daki seçici görür.
  cli-pkg =
    (inputs.caelestia-cli.packages.${system}.default.override {
      discordBin = "vesktop";
    }).overrideAttrs (old: {
      postUnpack = (old.postUnpack or "") + ''
        for f in ${./schemes}/*.txt; do
          name=$(basename "$f" .txt)
          mkdir -p "$sourceRoot/src/caelestia/data/schemes/$name/main"
          cp "$f" "$sourceRoot/src/caelestia/data/schemes/$name/main/dark.txt"
        done
      '';
    });

  # İlk açılış varsayılanları — runtime seçimlerini ASLA ezmez (state varsa dokunmaz)
  defaultsGuard = pkgs.writeShellScript "caelestia-defaults" ''
    state="$HOME/.local/state/caelestia"
    if [ ! -f "$state/scheme.json" ]; then
      ${cli-pkg}/bin/caelestia scheme set -n everforest -f medium -m dark
    fi
    if [ ! -f "$state/wallpaper/path.txt" ] && [ -f "$HOME/Pictures/Wallpapers/everforest.png" ]; then
      ${cli-pkg}/bin/caelestia wallpaper -f "$HOME/Pictures/Wallpapers/everforest.png"
    fi
  '';

  # Hyprland için build-time fallback şema: ilk boot'ta (henüz scheme set
  # çalışmadan) source edilen dosya var olsun diye everforest'ten üretilir.
  fallbackScheme = pkgs.runCommand "caelestia-fallback-scheme.conf" { } ''
    sed 's/^\([A-Za-z_0-9]*\) \(.*\)$/$\1 = \2/' \
      ${inputs.caelestia-cli}/src/caelestia/data/schemes/everforest/medium/dark.txt > $out
  '';
in
{
  imports = [ inputs.caelestia-shell.homeManagerModules.default ];

  programs.caelestia = {
    enable = true;
    # Shell'in gömülü CLI'ı da bizimki olsun — launcher'daki şema seçici
    # `caelestia scheme list`i wrapper PATH'inden çözer
    package = inputs.caelestia-shell.packages.${system}.with-cli.override {
      caelestia-cli = cli-pkg;
    };
    # UWSM graphical-session.target'ı aktive eder → systemd servisi güvenli
    # (çökmede otomatik restart + shell.json değişiminde restart trigger)
    systemd.enable = true;

    settings = {
      # Shell yüzeylerinde hafif saydamlık (bar, launcher, dashboard...)
      appearance.transparency = {
        enabled = true;
        base = 0.85;
        layers = 0.4;
      };
      general.apps.terminal = [ "ghostty" ];
      general.idle = {
        lockBeforeSleep = true;
        inhibitWhenAudio = true;
        timeouts = [
          { timeout = 300; idleAction = "lock"; }
          { timeout = 480; idleAction = "dpms off"; returnAction = "dpms on"; }
        ];
      };
      paths.wallpaperDir = "~/Pictures/Wallpapers";
    };

    cli = {
      enable = true;
      package = cli-pkg;
      settings.theme = {
        # nixy'nin tersine: runtime tema motoru AÇIK — anlık sistem geneli geçiş
        enableTerm = true; # açık terminallere OSC dizileri
        enableHypr = true; # hypr/scheme/current.conf (border renkleri)
        enableDiscord = true; # vesktop tema CSS'i (canlı)
        enableGtk = true; # gtk.css + dconf (adw-gtk3-dark, Papirus)
        enableQt = true;
        enableBtop = true;
        enableFuzzel = true; # emoji seçici fuzzel'ı da temalı
        # Kapalılar:
        enableChromium = false; # sudo -n gerektirir
        enableSpicetify = false; # Spotify yok (Deezer kullanılıyor)
        enableHtop = false; # htoprc'yi komple ezer
        enableNvtop = false;
        enableWarp = false;
        enableZed = false;
        enablePandora = false;
        enableCava = false;
        postHook = "${postHook}";
      };
    };
  };

  # Pywalfox için pywal formatında renk template'i — şema geçişinde
  # ~/.local/state/caelestia/theme/wal-colors.json olarak render edilir
  xdg.configFile."caelestia/templates/wal-colors.json".text = ''
    {
      "special": {
        "background": "#{{ background.hex }}",
        "foreground": "#{{ onBackground.hex }}",
        "cursor": "#{{ secondary.hex }}"
      },
      "colors": {
        "color0": "#{{ term0.hex }}",
        "color1": "#{{ term1.hex }}",
        "color2": "#{{ term2.hex }}",
        "color3": "#{{ term3.hex }}",
        "color4": "#{{ term4.hex }}",
        "color5": "#{{ term5.hex }}",
        "color6": "#{{ term6.hex }}",
        "color7": "#{{ term7.hex }}",
        "color8": "#{{ term8.hex }}",
        "color9": "#{{ term9.hex }}",
        "color10": "#{{ term10.hex }}",
        "color11": "#{{ term11.hex }}",
        "color12": "#{{ term12.hex }}",
        "color13": "#{{ term13.hex }}",
        "color14": "#{{ term14.hex }}",
        "color15": "#{{ term15.hex }}"
      }
    }
  '';

  # pywalfox render edilmiş dosyayı pywal yolundan okur
  home.file.".cache/wal/colors.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.local/state/caelestia/theme/wal-colors.json";

  # Pywalfox native-messaging manifest'i (Firefox eklentisi ↔ pywalfox köprüsü)
  # force: `pywalfox install` üstüne yazarsa da deklaratif sürüm kazanır
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".force = true;
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text = builtins.toJSON {
    name = "pywalfox";
    description = "Pywalfox native host";
    path = "${pkgs.writeShellScript "pywalfox-host" ''
      exec ${pkgs.pywalfox-native}/bin/pywalfox start
    ''}";
    type = "stdio";
    allowed_extensions = [ "pywalfox@frewacom.org" ];
  };


  # Caelestia'nın dconf ile ayarladığı GTK/ikon temalarının paketleri
  # + pywalfox CLI (debug için elle de çağrılabilir)
  home.packages = with pkgs; [
    adw-gtk3
    papirus-icon-theme
    pywalfox-native
  ];

  # Launcher pano geçmişi
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Tema duvar kağıtları (recursive: kullanıcı dizine kendi dosyasını da atabilir)
  home.file."Pictures/Wallpapers" = {
    source = ../wallpapers;
    recursive = true;
  };

  # --- Guard 1: hyprland şema fallback'i (yalnızca dosya yoksa) ---
  home.activation.caelestiaHyprFallback = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.config/hypr/scheme/current.conf" ]; then
      run mkdir -p "$HOME/.config/hypr/scheme"
      run cp ${fallbackScheme} "$HOME/.config/hypr/scheme/current.conf"
      run chmod u+w "$HOME/.config/hypr/scheme/current.conf"
    fi
  '';

  # --- Guard 2: btop tema seçimi (yalnızca config yoksa; btop config'ini
  # runtime'da kendisi yazdığı için HM symlink'i ile yönetilemez) ---
  home.activation.caelestiaBtopSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.config/btop/btop.conf" ]; then
      run mkdir -p "$HOME/.config/btop"
      run printf 'color_theme = "caelestia"\ntheme_background = False\n' > "$HOME/.config/btop/btop.conf"
    fi
  '';

  # --- Mutable-copy hilesi: runtime'da yazılan HM-yönetimli config'ler ---
  # Shell, shell.json'a (GUI ayarları) runtime'da yazar; HM symlink'i kalırsa
  # yazamaz, symlink'i değiştirirse sonraki switch çakışır. Çözüm (nixy deseni):
  # switch sonrası symlink'i yazılabilir kopyayla değiştir, bayat backup'ları önceden sil.
  # NOT: checkLinkTargets, linkGeneration'dan ÖNCE koşar ve bayat backup'ta
  # hata verir — temizlik ondan da önce yapılmalı
  home.activation.caelestiaCleanBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f "$HOME/.config/caelestia/shell.json.hm-backup" \
              "$HOME/.config/vesktop/settings.json.hm-backup" \
              "$HOME/.config/vesktop/settings/settings.json.hm-backup"
  '';
  home.activation.caelestiaMutableConfigs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for f in "$HOME/.config/caelestia/shell.json" \
             "$HOME/.config/vesktop/settings.json" \
             "$HOME/.config/vesktop/settings/settings.json"; do
      if [ -L "$f" ]; then
        run cp --remove-destination "$(readlink -f "$f")" "$f"
        run chmod u+w "$f"
      fi
    done
  '';

  # --- İlk açılış varsayılanları (idempotent) ---
  # exec-once yerine ExecStartPre: shell ilk state'i kendisi yazmadan ÖNCE
  # koşması garanti olur (aksi halde CLI kod-varsayılanı catppuccin kazanır).
  systemd.user.services.caelestia.Service.ExecStartPre = "${defaultsGuard}";
}
