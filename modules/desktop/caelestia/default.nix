# Caelestia — shell (bar/launcher/bildirim/kilit) + cli (runtime tema motoru)
# Tema geçişi rebuild İSTEMEZ: launcher'da ">scheme " ile anlık değişir.
# Şema seçimi ~/.local/state/caelestia/scheme.json'da kalıcıdır.
{ inputs, lib, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;

  # Discord istemcisi olarak Vesktop kullanılıyor
  cli-pkg = inputs.caelestia-cli.packages.${system}.default.override {
    discordBin = "vesktop";
  };

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
    # UWSM graphical-session.target'ı aktive eder → systemd servisi güvenli
    # (çökmede otomatik restart + shell.json değişiminde restart trigger)
    systemd.enable = true;

    settings = {
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
      };
    };
  };

  # Caelestia'nın dconf ile ayarladığı GTK/ikon temalarının paketleri
  home.packages = with pkgs; [
    adw-gtk3
    papirus-icon-theme
  ];

  # Launcher pano geçmişi
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Varsayılan duvar kağıdı
  home.file."Pictures/Wallpapers/everforest.png".source = ../wallpapers/everforest.png;

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
  home.activation.caelestiaCleanBackups = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
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
