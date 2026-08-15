# Serpantinum — KARANTİNALI ikinci oturum denemesi (github.com/ilyamiro/serpantinum,
# bir Quickshell/Hyprland rice'ı). Mevcut Caelestia oturumuna (desktop.hyprland.enable)
# HİÇ dokunmadan ly'de üçüncü bir girdi olarak eklenir — deneme başarısız olursa
# desktop.serpantinum.enable = false; ile tek satırda geri alınır.
#
# HM tarafı (home/desktop/serpantinum/default.nix, ayrı bir ajanın işi) bu bayrağı
# osConfig.desktop.serpantinum.enable üzerinden izler ve $HOME'a rice ağacını
# yerleştirir (~/.config/hypr/serpantinum.conf, scripts/, config/*.conf, templates/*,
# ~/.config/matugen/config.toml). Bu dosya o ağacın VARLIĞINI VARSAYAR, oluşturmaz.
{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.serpantinum;

  # swww nixpkgs'te "awww" oldu (binary'ler de: awww, awww-daemon; swww/swww-daemon
  # YOK). Üstakım script'lerinde swww/swww-daemon çağrıları kalmış olabilir (biri
  # yamalandı, biri yamalanmadıysa) — küçük bir uyumluluk kabuğu her ikisini de karşılar.
  swwwCompat = pkgs.runCommand "swww-compat" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.awww}/bin/awww $out/bin/swww
    ln -s ${pkgs.awww}/bin/awww-daemon $out/bin/swww-daemon
  '';

  # Üstakımın kendi duvar kağıdı deposu — HM tarafıyla PAYLAŞILAN veri, bkz.
  # lib/serpantinum-wallpapers.nix (neden lib/'de olduğu ve hangi görselin varsayılan
  # olduğu orada anlatılıyor). Varsayılan artık Caelestia'nın ~/Pictures/Wallpapers
  # dizininden ÖDÜNÇ ALINMIYOR, doğrudan koleksiyondan geliyor: görsel sonuç aynı,
  # bağımlılık yönü düzeldi (karantina kuralı — iki oturum birbirinin dosyasına
  # dayanmamalı).
  wallpapers = import ../../lib/serpantinum-wallpapers.nix { inherit pkgs; };

  # Oturumun tüm eksik çalışma-zamanı bağımlılıkları — home.packages'A KONMAZ (Caelestia
  # oturumunun PATH'i/closure atfı temiz kalsın diye), yalnız bu sarmalayıcının PATH'ine.
  #
  # "EKSİK" kelimesi sözleşme: aşağıdaki `export PATH=…:$PATH` mirası KESMEZ, önüne
  # ekler. ly → PAM (pam_env, /etc/pam/environment) oturuma /run/current-system/sw/bin
  # ve /etc/profiles/per-user/<kullanıcı>/bin'i zaten veriyor, o yüzden sistem
  # profilinden gelenler (curl, xdg-open, awk, sed, grep, find, xargs, pgrep, pkill,
  # hyprctl, systemctl, wpctl, powerprofilesctl, iw, kbd-rgb) ve HM profilinden gelenler
  # (zen-beta, nautilus, easyeffects) BİLEREK burada değil — üstakım script/QML'lerinde
  # çağrılıyor olmaları bir eksiklik DEĞİL. 15 Ağu'da tam bir ikili taraması yapıldı:
  # curl ve xdg-open "eksik" sanıldı, ikisi de canlı oturumda çalışıyordu (curl NixOS'un
  # corePackageNames'inde, xdg-utils services.graphical-desktop'tan geliyor). Bir şeyi
  # buraya eklemeden önce üç PATH'te de yokluğunu doğrula.
  runtimeDeps = with pkgs; [
    quickshell # nixpkgs 0.3.0 — binary cache'ten, Caelestia'nın git pin'inden bağımsız
    awww # GERÇEK isim — swwwCompat yalnız `swww`/`swww-daemon` diye SEMBOLİK bağ üretiyor,
    # `awww`/`awww-daemon`'ın kendisini PATH'e KOYMUYOR. autostart.conf'un
    # `exec-once = awww-daemon` satırı (swww-daemon'dan yeniden adlandırılmış) bu paket
    # burada olmadan PATH'te hiç bulunamıyordu — exec-once sessizce no-op geçiyordu,
    # Hyprland hata basmıyor (12 Ağu: `pgrep awww` boş döndü, canlı oturumda hiç
    # duvar kağıdı görünmüyordu, kök neden buydu).
    swwwCompat
    matugen
    jq
    psmisc # killall — matugen_reload.sh'in ilk satırı (kitty tema canlı-yenileme),
    # 13 Ağu canlı oturumda "killall: command not found" ile yakalandı
    inotify-tools
    imagemagick
    ffmpeg
    python3
    playerctl
    cliphist
    swayosd
    hypridle
    cava
    mpvpaper
    pamixer
    acpi
    bc
    lm_sensors
    libnotify
    fd
    ripgrep
    wl-clipboard
    socat
    brightnessctl
    bluez
    networkmanager
    coreutils
    dbus
    nerd-fonts.jetbrains-mono

    # screenshot.sh'in REQUIRED_CMDS'i hepsi-ya-hiç: tek biri eksikse dört Print
    # bind'i de (normal/--edit/--full/--full --edit) "Missing Dependencies" ile
    # düşüyordu (15 Ağu). pipewire-pulse çalışıyor ama `pactl` İKİLİSİNİ o VERMİYOR —
    # gerçek kaynağı `pulseaudio` paketinin istemci araçları. pulseaudio'yu yalnız
    # ekran görüntüsü için eklediğini sanıp silme: aynı ağaçtaki volume_listener.sh
    # (autostart'ta exec-once!), bluetooth_panel_logic.sh, music_info.sh,
    # audio_wait.sh, audio_control.sh, get_audio_state.py de `pactl` çağırıyor — o
    # olmadan ses/bluetooth paneli de sessizce kırıktı.
    grim
    satty
    zbar # ikili adı zbarimg, paket adı değil
    gpu-screen-recorder
    pulseaudio # yalnız pactl için — closure'da zaten var (0 MiB marjinal, ölçüldü)
  ];

  # Oturumun tek giriş noktası — ly'nin .desktop Exec='i bunu çağırır.
  sessionWrapper = pkgs.writeShellScriptBin "serpantinum-session" ''
    export PATH=${lib.makeBinPath runtimeDeps}:$PATH

    # dGPU'yu D3cold'da tutmak için — Caelestia bunu systemd unit environment'ından alıyor
    # (programs.caelestia.systemd.environment); bu oturum quickshell'i exec-once ile
    # başlatıyor, asılacak systemd unit'i YOK, o yüzden burada olmak ZORUNDA.
    # AQ_DRM_DEVICES burada TEKRARLANMAZ — session.nix'ten environment.sessionVariables
    # ile PAM üzerinden zaten geliyor (aquamarine config'ten önce okuyor, iki oturuma da
    # aynı şekilde giriyor).
    export __GLX_VENDOR_LIBRARY_NAME=mesa
    export __EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json

    # SUPER+W duvar kağıdı seçicisinin kaynağı. Bu TEK değişken hem qs_manager.sh'i
    # (`SRC_DIR="''${WALLPAPER_DIR:-…}"`, satır 39) hem WallpaperPicker.qml'i
    # (`Quickshell.env("WALLPAPER_DIR")`, satır 538) besliyor — ikisi de aynı ismi
    # okuyor, ikinci bir ayar noktası YOK.
    #
    # Varsayılanı (~/Pictures/Wallpapers) ezmek BİLİNÇLİ: orası Caelestia'nın 16
    # küratörlü duvar kağıdının dizini ve iki oturum aynı listeyi paylaşmamalı.
    # Ayrıca seçici `-maxdepth 1` tarıyor, yani alt dizin İŞE YARAMIYOR — koleksiyonu
    # oraya alt klasör olarak koymak (kullanıcının elle klonladığı hâli) hiçbir zaman
    # görünmeyecekti; kök neden buydu.
    #
    # `videos/` kapsam DIŞI: aynı `-maxdepth 1` yüzünden tek dizin seçilebiliyor ve
    # script mp4'ü mpvpaper ile canlı duvar kağıdı olarak açıyor — bu oturumun idle
    # maliyeti zaten kabul edilmiş bir istisna, üstüne sürekli video kod çözme
    # eklemek ayrı bir karar. images/ seçildi.
    export WALLPAPER_DIR=${wallpapers.imagesDir}

    # Bu satır YALNIZ QtMultimedia için (UpdaterPopup.qml + WallpaperPicker.qml import
    # ediyor, 30 QML dosyasının tamamı tarandı — grep'te başka kullanan yok, 15 Ağu).
    # QtQuick.Effects/QtCore/QtQuick.Controls'ün bu satırla İLGİSİ YOK — quickshell'in
    # kendi sarmalayıcısının NIXPKGS_QT6_QML_IMPORT_PATH'inden geliyorlar. qt5compat ve
    # qtwebsockets önceden buradaydı, hiçbir QML dosyası import ETMİYORDU — kaldırıldı.
    # qtwebengine BİLİNÇLİ dışarıda (Documentation/desktop.md'de not edilecek): ~1-2 GiB
    # closure, yalnız movie/DDG-arama widget'ları kullanıyor. "Type unavailable" görülürse
    # buraya qt6.qtwebengine eklenir.
    export QML2_IMPORT_PATH="${pkgs.qt6.qtmultimedia}/lib/qt-6/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

    # İlk açılış: renk zinciri hiç koşmadıysa matugen'i bir kez tetikle (defaultWallpaper,
    # yukarıdaki let bloğunda). Sonraki her açılışta ~/.config/hypr/colors.conf
    # zaten var — DOKUNULMAZ (kullanıcının seçtiği son duvar kağıdı/şema kalır).
    # Dosya-var-mı koruması KALDIRILDI: yol artık store'da ve bu sarmalayıcının bir
    # derleme bağımlılığı, yani var olmaması mümkün değil (önceki hâlde $HOME'daki bir
    # dosyaydı, orada koruma anlamlıydı).
    # --prefer=saturation ZORUNLU: bu görsel tek baskın (koyu/monokrom) tonlu olsa
    # bile matugen terminal olmadan (exec-once ortamı) HİÇBİR görüntüde otomatik seçim
    # yapmıyor, --prefer olmadan her zaman hata veriyor (12 Ağu doğrulandı: fark etmeksizin
    # aynı "Multiple source colors found... terminal not detected" hatası) — önceki hâlde
    # `|| true` bu hatayı SESSİZCE yutuyordu, colors.conf hiç oluşmuyordu, hyprland.conf'un
    # `source = colors.conf` satırı "globbing error: found no match" veriyordu, bu da
    # $active_border/$inactive_border'ın tanımsız kalıp settings.conf'ta rengi parse
    # edememesine kaskad oluyordu (12 Ağu, canlı oturumda `hyprctl configerrors` ile
    # teşhis edildi).
    if [ ! -f "$HOME/.config/hypr/colors.conf" ]; then
      matugen image "${wallpapers.default}" --prefer=saturation || true
    fi

    # BİLİNÇLİ olarak start-hyprland DEĞİL, ham Hyprland binary'si (makeWrapper
    # çıktısı — yalnız PATH ekleyip .Hyprland-wrapped'i exec ediyor, uwsm/systemd'den
    # habersiz). system/desktop/CLAUDE.md'nin "çalışmayan düz Hyprland girişi" dediği
    # kırık üçüncü taraf, ly'nin Exec='ı start-hyprland yapan hyprland.desktop'ı —
    # başarısızlığın kaynağı start-hyprland'in kendisiydi, ham Hyprland değil (12 Ağu
    # doğrulandı: `strings` start-hyprland'de değil, yalnız uwsm.desktop'ın kendi
    # Exec='ında "uwsm start" geçiyor). O yüzden burada uwsm'i VE start-hyprland'i
    # ikisini de atlayıp doğrudan derleyiciyi çağırmak en güvenli yol.
    exec ${config.programs.hyprland.package}/bin/Hyprland --config "$HOME/.config/hypr/serpantinum.conf"
  '';

  # ly'nin listeleyeceği oturum girdisi. DesktopNames=Hyprland: aquamarine/xdg-portal
  # bazı algılamalarda bunu XDG_CURRENT_DESKTOP için kullanıyor — hyprland.desktop'ın
  # kendi deseniyle tutarlı (nixpkgs'in hyprland paketinin ürettiği .desktop'a bak).
  sessionDesktop = pkgs.runCommand "serpantinum-session-desktop" {
    # services.displayManager.sessionPackages'ın tip denetimi bunu şart koşuyor:
    # ".desktop" dosyasının basename'iyle EŞLEŞMEK ZORUNDA (module bunu doğruluyor,
    # bkz. nixos/modules/services/display-managers/default.nix installedSessions).
    passthru.providedSessions = [ "serpantinum" ];
  } ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/serpantinum.desktop <<EOF
    [Desktop Entry]
    Name=Serpantinum
    Comment=Karantinali Quickshell/Hyprland rice denemesi (github.com/ilyamiro/serpantinum)
    Exec=${sessionWrapper}/bin/serpantinum-session
    Type=Application
    DesktopNames=Hyprland
    EOF
  '';
in
{
  options.desktop.serpantinum.enable = lib.mkEnableOption
    "Serpantinum — karantinali Quickshell rice denemesi (ly'de ayri oturum girdisi)";

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = config.desktop.hyprland.enable;
      message = "desktop.serpantinum, programs.hyprland + AQ_DRM_DEVICES icin desktop.hyprland.enable'a bagimli";
    }];

    services.displayManager.sessionPackages = [ sessionDesktop ];
  };
}
