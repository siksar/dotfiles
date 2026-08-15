# Serpantinum — karantinalı Quickshell/Hyprland rice denemesi (ilyamiro/serpantinum).
# Bu modül yalnız HM tarafı: üstakım kaynağını pinler+yamalar ve $HOME'a dağıtır.
# Caelestia'ya (asıl oturum, bkz. ../caelestia/default.nix) HİÇ dokunmaz — karantina
# kuralı home/desktop/CLAUDE.md'de: home.packages/dconf/hypridle/easyeffects gibi HER
# ŞEY GLOBAL olan HM seçenekleri buradan yasak, aksi halde Caelestia oturumuna sızar.
# Üstakım v2.0 duyurusuyla kısa ömürlü kabul ediliyor — bu yüzden yama sayısı minimal
# tutuldu (yalnız bu sistemde gerçekten kırık/çakışan şeyler), üstakımı yeniden yazmak
# değil.
{ config, lib, pkgs, osConfig ? { }, ... }:

let
  cfg = config.desktop.serpantinum;

  # Duvar kağıdı koleksiyonu — sistem tarafıyla (system/desktop/serpantinum.nix)
  # PAYLAŞILAN veri. İki modül birbirini import edemediği için lib/'de duruyor; iki
  # taraf da aynı türetimi çözer, store'da tek kopya. Burada yalnız `.default`
  # kullanılıyor (autostart yedeği); dizinin kendisi WALLPAPER_DIR ile sistem
  # tarafından veriliyor.
  wallpapers = import ../../../lib/serpantinum-wallpapers.nix { inherit pkgs; };

  # Kaynak pinli + yamalı — applyPatches src'yi yazılabilir bir kopyaya alır,
  # postPatch o kopyanın kökünde (repo kökü) koşar.
  src = pkgs.applyPatches {
    name = "serpantinum-src";
    src = pkgs.fetchFromGitHub {
      owner = "ilyamiro";
      repo = "serpantinum";
      rev = "5d4451f7ab55ddaced9ba350b6dba5dd2932aeb1";
      hash = "sha256-dnPSMHeRnIef1k05msB7gRHapYjSWMLeu/qdaFK3F9o=";
    };
    postPatch = ''
      # nixpkgs'te swww awww olarak yeniden adlandırıldı, ikili adı da değişti
      sed -i 's/swww-daemon/awww-daemon/' config/sessions/hyprland/config/autostart.conf
      # bu betik üstakım deposunda YOK (404) — her açılışta exec-once sessizce başarısız olurdu
      sed -i '/settings_watcher\.sh/d' config/sessions/hyprland/config/autostart.conf
      # enable kalıcı — bu satır Caelestia oturumuna da sızar, karantina kuralını bozar
      sed -i '/enable --now easyeffects/d' config/sessions/hyprland/config/autostart.conf
      # dconf global — Stylix'in imleç temasını ezer
      sed -i '/gsettings.*cursor-theme/d' config/sessions/hyprland/config/autostart.conf
      # dconf global — Stylix'in imleç boyutunu ezer
      sed -i '/gsettings.*cursor-size/d' config/sessions/hyprland/config/autostart.conf
      # hyprpolkitagent: bu oturum hyprland-session.target'ı açmıyor, Caelestia'nınki
      # ajanı bağlanamaz — olmadan 1Password sistem kimlik doğrulaması sessizce
      # reddedilir. Mutlak yol ZORUNLU: pkgs.hyprpolkitagent'ta bin/ YOK, yalnız
      # libexec/hyprpolkitagent var — bare `hyprpolkitagent` PATH'te asla çözülmez,
      # exec-once sessizce no-op geçer (15 Ağu doğrulandı). `systemctl --user start
      # hyprpolkitagent.service` (Caelestia'nın session.nix'inin kurduğu birim)
      # kasıtlı olarak TERCİH EDİLMEDİ — serpantinum'u HM katmanında Caelestia'nın
      # birim adına bağımlı kılardı; bu repoda tam bu yönde bir bağımlılık zaten bir
      # kez kırıldı (bkz. lib/serpantinum-wallpapers.nix'in "karantina kuralı" notu).
      # swayosd-server: keybindings.conf swayosd-client çağırıyor ama sunucu
      # üstakımda global bir HM modülünden geliyordu (burada yasak), bu yüzden
      # exec-once'a taşındı.
      #
      # Duvar kağıdı: üstakım hiçbir yerde ilk açılışta `awww img` ÇAĞIRMIYOR — yalnız
      # WallpaperPicker.qml (kullanıcı elle açınca) `swww img` kullanıyor. Taze bir
      # `$HOME`'da awww-daemon boş ekranla başlıyor, hiçbir şey göstermiyor (12 Ağu
      # canlı oturumda doğrulandı). `sleep 1`: daemon IPC soketini bağlamadan `awww img`
      # gelirse bağlantı reddedilir — yaygın swww/awww deseni. `restore` ÖNCE denenir:
      # awww kendi ~/.cache/awww/<sürüm>/<çıkış> dosyasında son set edilen duvar kağıdını
      # tutuyor, böylece kullanıcının WallpaperPicker'dan seçtiği bir önceki oturumdan
      # KORUNUYOR; yalnız cache boş/geçersizse (gerçek ilk açılış) koleksiyonun resmi
      # varsayılanına (lib/serpantinum-wallpapers.nix'in `default`'u) düşülüyor. Yol
      # artık $HOME'da DEĞİL store'da — Caelestia'nın ~/Pictures/Wallpapers dizinine
      # olan eski bağımlılık kaldırıldı (karantina).
      printf '%s\n' \
        'exec-once = ${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent' \
        'exec-once = swayosd-server' \
        'exec-once = sleep 1 && (awww restore || awww img ${wallpapers.default})' \
        >> config/sessions/hyprland/config/autostart.conf

      # aynı swww→awww yeniden adlandırması — duvar kağıdı seçicinin mevcut duvar
      # kağıdını bulma yolu. Bu TEK sed'in ötesinde ağaçta 4 dosyada ~15 swww/
      # swww-daemon çağrısı DAHA var (qs_manager.sh burada 1, WallpaperPicker.qml'de
      # 6 `swww img`, Config.qml ve MonitorPopup.qml'de monitör yeniden yapılandırma
      # dalında 4'er "swww kill ; ... swww-daemon &" — 15 Ağu grep ile sayıldı).
      # Hiçbiri kırık DEĞİL: system/desktop/serpantinum.nix'teki swwwCompat kabuğu
      # `swww`/`swww-daemon` adlarını `awww`'a sembolik bağlıyor ve awww CLI'ı
      # img/query/restore + --transition-* + -o bayraklarında ölçülerek uyumlu
      # bulundu. Yani swwwCompat "her ihtimale karşı" bir kabuk DEĞİL — YÜK TAŞIYOR:
      # kaldırılırsa duvar kağıdı seçicisi ve monitör yeniden yapılandırma aynı anda
      # ölür.
      sed -i 's/swww query/awww query/' config/sessions/hyprland/scripts/qs_manager.sh

      # SUPER+F tarayıcı bind'i. İkilinin adı `zen` DEĞİL `zen-beta` (zen-browser-flake
      # paketi böyle kuruyor; .desktop dosyası da zen-beta.desktop, Exec=zen-beta) —
      # önceki hâl `exec, zen` yazıyordu ve bind SESSİZCE hiçbir şey yapmıyordu
      # (Hyprland exec'i /bin/sh'a veriyor, "command not found" yalnız oturum
      # günlüğüne düşüyor). 15 Ağu'da `which zen` boş dönüşüyle yakalandı.
      # NOT: "beta" burada bir kararsızlık işareti değil, Zen'in YAYIN kanalının adı
      # (nightly kanalı `twilight`) — flake başka bir "stable" varyant sunmuyor.
      sed -i 's/exec, firefox$/exec, zen-beta/' config/sessions/hyprland/config/keybindings.conf
      # Telegram kurulu değil
      sed -i '/exec, Telegram$/d' config/sessions/hyprland/config/keybindings.conf
      # obsidian kurulu değil
      sed -i '/exec, obsidian$/d' config/sessions/hyprland/config/keybindings.conf
      # Fn+F7 Wayland'de keysym üretmiyor — bind olmadan bu oturumda fan kontrolü hiç
      # yok. kbd-rgb parlaklık bind'leri home/desktop/wm/binds.lua:67-68'in eşleniği.
      # Pencere kapatma: $mainMod+Q Caelestia'daki gibi boş DEĞİL — üstakım onu
      # zaten qs_manager.sh'ye (müzik popup'ı) bağlamış (hyprctl binds ile 12 Ağu
      # doğrulandı). $mainMod+1 de dolu (çalışma alanı 1). Q'nun bir sıra altı, aynı
      # sütun — $mainMod+A — boş, oraya kondu.
      printf '%s\n' \
        'bind = $mainMod ALT, M, exec, systemctl start --no-block fan-mode-cycle.service' \
        'bind = $mainMod ALT, C, exec, kbd-rgb bright -10' \
        'bind = $mainMod ALT, V, exec, kbd-rgb bright +10' \
        'bind = $mainMod, A, killactive,' \
        >> config/sessions/hyprland/config/keybindings.conf

      # SUPER+D uygulama menüsü NixOS'ta yarı boştu: app_fetcher.py XDG_DATA_DIRS'i hiç
      # okumuyor, tarayacağı dizinleri elle sabitlemiş — listede `~/.nix-profile/share/
      # applications` ve `/run/current-system/sw/share/applications` (sistem paketleri)
      # var ama `/etc/profiles/per-user/<kullanıcı>/share/applications` YOK. Oysa HM'in
      # home.packages'ına giren HER uygulama tam oraya iniyor.
      # KAÇ girdi eksikti — SABİT bir sayı değil, ölçüm anına bağlı: `~/.nix-profile/
      # share/applications` bu sistemde artık VAR (21 .desktop, `hms` standalone HM
      # yolunun profiline işaret ediyor) — "bu sistemde yok" teşhisi yanlıştı. 15 Ağu'da
      # patch'li/patch'siz app_fetcher.py karşılaştırmasıyla ölçülen fark 48→50 (2),
      # daha önce aynı yöntemle 34→50 (16) ölçülmüştü — hangi ~/.nix-profile durumunda
      # hangi ölçümün alındığı kayıtlı değil, o yüzden "eksik olan N uygulama" diye tek
      # bir sayı vermiyoruz. Yamanın gerekçesi sayıdan bağımsız: eksik olan yol sabit
      # (`/etc/profiles/per-user/<kullanıcı>/share/applications`), sistem paketleri
      # göründüğü için "sadece zen yok" gibi okunan bir eksiklikti (15 Ağu, kullanıcı
      # bildirimi → dizin listesi ile karşılaştırılarak teşhis edildi).
      #
      # Genel XDG_DATA_DIRS taraması YERİNE tek bir düz yol ekleniyor: değişken bu
      # oturumun ortamında var olsa da (ly → PAM zinciri) buna dayanmak, hatanın
      # sessizce geri gelebileceği bir koşul yaratır — eksik olan yol tam olarak
      # budur ve sabit yol her koşulda çözülür. Kullanıcı adı config'ten geliyor,
      # elle yazılmıyor.
      sed -i "s|^\( *\)'/run/current-system/sw/share/applications'|\1'/run/current-system/sw/share/applications',\n\1'/etc/profiles/per-user/${config.home.username}/share/applications'|" \
        config/sessions/hyprland/scripts/quickshell/applauncher/app_fetcher.py

      # repo Caelestia tarafında general.apps.terminal = ["ghostty"], kitty kurulu değil
      sed -i 's/= kitty$/= ghostty/' config/sessions/hyprland/config/variables.conf

      # SUPER+W duvar kağıdı seçici PANELİ boş: `find "$SRC_DIR" -type f` sembolik
      # bağları EŞLEŞTİRMİYOR (POSIX -type, -L olmadan sembolik bağın kendi tipine
      # bakar, hedefine değil) — bu repoda `~/Pictures/Wallpapers/*` TAMAMEN sembolik
      # bağ (home.file → Nix store, Caelestia'nınkiler DAHİL, obsidian-dunes.jpg'ye
      # özgü değil). Sonuç: kaynak taraması hep boş dönüyor, thumbnail üretim döngüsü
      # hiçbir dosya görmüyor, .manifest boş kalıyor, panelde hiçbir wallpaper
      # görünmüyor — 13 Ağu canlı oturumda `find` çıktısını izole çalıştırıp
      # doğrulandı. `-L` sembolik bağı hedefine göre çözer, sorunu kökten kapatır.
      sed -i 's|find "\$SRC_DIR" -maxdepth 1 -type f|find -L "$SRC_DIR" -maxdepth 1 -type f|' \
        config/sessions/hyprland/scripts/qs_manager.sh

      # Aynı fonksiyonda AYRI bir hata: find filtresi hiç ".webp" içermiyor — script'in
      # kendi webp→jpg dönüştürme dalı (extension=="webp" ise magick ile çevirip
      # orijinali silen blok) bu yüzden hiç TETİKLENMİYOR, ölü kod. Bu repoda
      # lib/wallpapers/berserk-guts.webp tam bunun kurbanı — 13 Ağu canlı oturumda
      # izole `find` çıktısıyla doğrulandı (webp'siz liste dönüyordu).
      sed -i 's|-o -iname "\*.gif" -o -iname "\*.mp4"|-o -iname "*.webp" -o -iname "*.gif" -o -iname "*.mp4"|' \
        config/sessions/hyprland/scripts/qs_manager.sh

      # Kilit ekranı arka planı DONMUŞ durumdaydı. WallpaperPicker.qml duvar kağıdını
      # uygularken onu `cp … current_wallpaper.png` ile kopyalıyor ve Lock.qml (satır
      # 115, `staticWallpaperPath`) TAM O dosyayı okuyor. Ama kaynak bir nix store
      # dosyası olduğunda (~/Pictures/Wallpapers'ın tamamı store symlink'i) `cp`
      # hedefi store'un salt-okunur modunu (444) alıyor; SONRAKİ her `cp` "permission
      # denied" ile düşüyor ve satır sonundaki `|| true` bunu sessizce yutuyor.
      # 15 Ağu'da ölçüldü: dosya 444 modunda ve 13 Ağu 00:16'dan kalma, oysa duvar
      # kağıdı o tarihten sonra defalarca değişmiş — yani kilit ekranı haftalardır
      # eski görseli gösteriyormuş.
      # WALLPAPER_DIR store'a taşındığı için bu ARTIK KALICI olurdu (koleksiyondaki
      # her dosya 444). `--remove-destination` hedefi kopyalamadan önce siliyor,
      # böylece eski dosyanın izni hiç yolu kesmiyor — bu repoda zaten kullanılan
      # desen (serpantinumMutableConfigs aktivasyonu aynı bayrağı kullanıyor).
      sed -i '/current_wallpaper\.png/s/cp "/cp --remove-destination "/' \
        config/sessions/hyprland/scripts/quickshell/wallpaper/WallpaperPicker.qml

      # MatugenColors.qml `cat /tmp/qs_colors.json` OKUYORDU — /tmp'yi
      # systemd-tmpfiles 10 günde temizliyor (q /tmp 1777 root root 10d,
      # systemd-tmpfiles-clean.timer aktif), dosya silinince hiçbir şey onu yeniden
      # üretmiyordu (aşağıdaki config.toml'un output_path'i artık ~/.local/state/
      # serpantinum/ altında, kalıcı). `Process.command` bir argv dizisi, shell
      # DEĞİL — düz "~/…" ya da "$HOME/…" string'i genişlemez, Quickshell.env("HOME")
      # ile elle birleştirmek gerekiyor (Config.qml:14/Caching.qml:6 ile aynı deyim;
      # bu dosya `import Quickshell` zaten ediyor, ek import gerekmedi).
      sed -i 's|command: \["cat", "/tmp/qs_colors.json"\]|command: ["cat", Quickshell.env("HOME") + "/.local/state/serpantinum/qs_colors.json"]|' \
        config/sessions/hyprland/scripts/quickshell/MatugenColors.qml

      # matugen_reload.sh KARANTİNAYI DELİYOR: sonundaki "GTK Live-Reload Hack"
      # bloğu `gsettings set org.gnome.desktop.interface gtk-theme/color-scheme`
      # çağırıyor — bu GLOBAL dconf durumu, home/desktop/CLAUDE.md'deki yasak
      # tablosunun tam olarak "dconf.settings" satırı. Serpantinum'da duvar kağıdı
      # değiştirmek Caelestia oturumunun GTK temasını da (Stylix'in yazdığı hedefi)
      # ezerdi. Şimdiye kadar ısırmamasının tek sebebi matugen zincirinin hiç
      # ateşlememesiydi; zincir çalışır çalışmaz ısıracaktı. Bloğu tamamen çıkar —
      # GTK teması bu repoda Stylix'in işi, oturum betiğinin değil.
      sed -i '/^# GTK Live-Reload Hack$/,/^fi$/d' \
        config/sessions/hyprland/scripts/quickshell/wallpaper/matugen_reload.sh

      # WallpaperPicker.qml'in KENDİ `matugen image` çağrıları (3 yer — arama sonucu
      # indirilen/önbellekteki için 2, yerel seçim için 1) hiçbiri --prefer= VERMİYOR.
      # Sonuç: kullanıcı bir duvar kağıdına TIKLADIĞINDA arka planı awww değiştiriyor
      # ama renk/tema zinciri (matugen → matugen_reload.sh) her seferinde sessizce
      # başarısız oluyor — hiç görsel hata yok, script `|| true` ile yutuyor (13 Ağu
      # canlı oturumda tam zinciri elle koşturup doğrulandı). Sistem başlangıcındaki
      # aynı sınıf hata (bkz. system/desktop/serpantinum.nix'in matugen bloğu) burada
      # QML kaynağının İÇİNDE, env değişkeniyle düzeltilemiyor — kaynağı yamalamak
      # gerekiyor.
      sed -i 's|matugen image "\$FINAL_THUMB"|matugen image "$FINAL_THUMB" --prefer=saturation|g; s|matugen image "''${escThumb}"|matugen image "''${escThumb}" --prefer=saturation|' \
        config/sessions/hyprland/scripts/quickshell/wallpaper/WallpaperPicker.qml

      # weather.sh varsayılanı: $(dirname "$0")/.env — yani ~/.config/hypr/scripts/
      # ALTINDA. O dizin xdg.configFile ile TEK PARÇA Nix store'a symlink (aşağıdaki
      # "hypr/scripts".source), yani salt-okunur — bir OpenWeather API anahtarını
      # oraya YAZMAK mümkün değil, ayrıca Nix store dünya-okunabilir + bu repo git'e
      # commit ediliyor, ikisi de bir sır için yanlış yer. Bunun yerine Nix'in HİÇ
      # dokunmadığı $HOME/.config/serpantinum/weather.env'e yönlendiriliyor — anahtar
      # oraya AYRI (bu postPatch'in dışında, elle) yazılıyor, ne store'da ne git'te
      # görünür.
      sed -i 's|ENV_FILE="\$(dirname "\$0")/.env"|ENV_FILE="$HOME/.config/serpantinum/weather.env"|' \
        config/sessions/hyprland/scripts/quickshell/calendar/weather.sh

      # Üstakım kendi laptopunun çözünürlüğünü sabit kodlamış (1920x1080@144) — bu
      # makinenin gerçek paneli BOE NE160QDM-NYJ, 2560x1600@165 (README.md donanım
      # tablosu, home/desktop/wm/main.lua'nın Caelestia tarafındaki aynı satırı,
      # system/kernel/power-display.nix'in AC modu — hepsi bu değerde SENKRON).
      # 12 Ağu canlı oturumda `hyprctl monitors` ile doğrulandı: panel 1080p'de
      # 144Hz'de değil, native 2560x1600@165'te çalışıyor, availableModes listesinin
      # ilk/en yüksek girdisi de bu. monitors.conf.template BOŞ (Settings GUI monitör
      # satırını dinamik yazıyor, statik dosyayı düzeltmek yeterli).
      sed -i 's/1920x1080@144/2560x1600@165/' config/sessions/hyprland/config/monitors.conf

      # Hyprland 0.56 (bu pindeki commit 5c9377c, v0.56.1) layer/window kural
      # motorunu YENİDEN YAZDI — `windowrulev2` artık içeriğe bakmadan her zaman
      # "deprecated" hatası veriyor, `layerrule`/`windowrule` her alanı artık
      # "isim değer" (boşlukla ayrılmış) biçiminde istiyor, bayrak efektler
      # (float/center/immediate/blur/no_anim/keep_aspect_ratio) açık "1" değeri
      # gerektiriyor, eşleştirme artık "class:X"/"title:X" değil "match:class X"/
      # "match:title X"/"match:namespace X". Kaynak: Hyprland
      # src/desktop/rule/{layerRule,windowRule}/*EffectContainer.cpp'deki
      # EFFECT_STRINGS listeleri (noanim→no_anim, ignorealpha→ignore_alpha,
      # keepaspectratio→keep_aspect_ratio) + src/config/legacy/ConfigManager.cpp
      # (handleWindowrule/handleLayerrule, satır 2016-2094) — canlı
      # `hyprctl configerrors` ile doğrulandı.
      sed -i \
        -e 's/^layerrule = noanim, \(.*\)$/layerrule = no_anim 1, match:namespace \1/' \
        -e 's/^layerrule = blur, \(.*\)$/layerrule = blur 1, match:namespace \1/' \
        -e 's/^layerrule = ignorealpha \([0-9.]*\), \(.*\)$/layerrule = ignore_alpha \1, match:namespace \2/' \
        config/sessions/hyprland/config/rules.conf
      sed -i \
        -e 's/^windowrulev2 = immediate, class:\(.*\)$/windowrule = immediate 1, match:class \1/' \
        -e 's/^windowrulev2 = keepaspectratio, class:\(.*\)$/windowrule = keep_aspect_ratio 1, match:class \1/' \
        -e 's/^windowrulev2 = float, title:\(.*\)$/windowrule = float 1, match:title \1/' \
        -e 's/^windowrulev2 = center, title:\(.*\)$/windowrule = center 1, match:title \1/' \
        -e 's/^windowrulev2 = size \([0-9]* [0-9]*\), title:\(.*\)$/windowrule = size \1, match:title \2/' \
        -e 's/^windowrulev2 = animation \([a-zA-Z]*\), title:\(.*\)$/windowrule = animation \1, match:title \2/' \
        config/sessions/hyprland/config/rules.conf
    '';
  };

  hyprDir = "${src}/config/sessions/hyprland";

  # ~/.config/hypr/config/*.conf — üstakım kaynağında bu dizin altında TÜMÜ (find ile
  # doğrulandı, 12 Ağu): autostart/env/keybindings/monitors/rules/settings/variables.
  # hyprland.conf hepsini ~/.config/hypr/config/<ad>.conf mutlak yoluyla `source`luyor.
  confFiles = [
    "autostart.conf"
    "env.conf"
    "keybindings.conf"
    "monitors.conf"
    "rules.conf"
    "settings.conf"
    "variables.conf"
  ];

  # ~/.config/hypr/templates/*.template — üstakımın "Settings" Quickshell popup'ı bu
  # şablonlardan yukarıdaki config/*.conf dosyalarını runtime'da yeniden üretiyor
  # (üst satırlarında "AUTOGENERATED FROM SETTINGS.JSON" yazıyor) — bu yüzden hem
  # şablonlar hem ürettikleri dosyalar mutable-copy'ye muhtaç.
  templateFiles = [
    "autostart.conf.template"
    "keybinds.conf.template"
    "monitors.conf.template"
    "settings.conf.template"
  ];

  # Runtime'da yazılabilir kalması gereken tüm dosyaların ~/.config'e göreli yolları —
  # hem backup temizliği hem symlink→kopya dönüşümü aynı listeyi kullanır.
  mutableRelPaths = map (f: "hypr/config/${f}") confFiles
    ++ map (f: "hypr/templates/${f}") templateFiles;

  mutableFileList = lib.concatMapStringsSep " " (p: ''"${p}"'') mutableRelPaths;
in
{
  options.desktop.serpantinum.enable = lib.mkOption {
    type = lib.types.bool;
    default = osConfig.desktop.serpantinum.enable or false;
    defaultText = lib.literalExpression "osConfig.desktop.serpantinum.enable or false";
    description = "Serpantinum karantinali Quickshell rice denemesinin HM katmani (dosya dagitimi, matugen)";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile =
      {
        # Ana Hyprland girişi — sistem tarafındaki oturum sarmalayıcısı bunu okur
        # (bkz. system/desktop/serpantinum.nix). Kendi ~/.config/hypr/hyprland.lua'sı
        # (Caelestia'nın oturumu) ile ÇAKIŞMASIN diye ayrı bir basename'de.
        "hypr/serpantinum.conf".source = "${hyprDir}/hyprland.conf";

        # Betikler — runtime'da yazılmıyor, düz symlink yeterli.
        "hypr/scripts".source = "${hyprDir}/scripts";

        # matugen şablonları — üstakımın 13 şablonundan yalnız bu ikisi kullanılıyor:
        # Quickshell'in kendi renk JSON'u ve Hyprland'ın colors.conf'u. Kalan 11'i
        # (GTK/Qt/Discord/Firefox/nvim/kitty/cava/swayosd/websites) Caelestia+Stylix'in
        # zaten yazdığı yüzeylerle çakışıyor ya da oturumlar arası sızıyor — bilerek
        # dışlandı.
        "matugen/templates/qs_colors.json.template".source =
          "${src}/config/programs/matugen/templates/qs_colors.json.template";
        "matugen/templates/hyprland.conf.template".source =
          "${src}/config/programs/matugen/templates/hyprland.conf.template";

        # config.toml elle yazılıyor (üstakımınki 13 şablon tanımlıyor, yukarıdaki
        # gerekçeyle yalnız bu iki hedef bırakıldı). Sistem tarafı bu şablonları
        # `matugen image <duvarkağıdı>` ile tetikliyor, yalnız colors.conf yoksa.
        "matugen/config.toml".text = ''
          [config]
          reload_apps = false

          # /tmp DEĞİL: systemd-tmpfiles /tmp'yi 10 günde temizliyor (q /tmp 1777 root
          # root 10d, systemd-tmpfiles-clean.timer aktif) ve bu dosya $HOME'da hiç
          # KALICI kopyası olmayan tek renk kaynağı — silinince MatugenColors.qml boş
          # döner ve hiçbir şey onu yeniden üretmez (system/desktop/serpantinum.nix'teki
          # ilk-açılış guard'ı yalnız colors.conf'a bakıyor, bu dosyaya değil). Caelestia
          # da aynı sınıf türetilmiş veriyi ~/.local/state/caelestia/theme/ altında
          # tutuyor (home/desktop/CLAUDE.md) — burada da aynı XDG-state emsali izlendi.
          [templates.quickshell]
          input_path = "~/.config/matugen/templates/qs_colors.json.template"
          output_path = "~/.local/state/serpantinum/qs_colors.json"

          [templates.hyprland]
          input_path = "~/.config/matugen/templates/hyprland.conf.template"
          output_path = "~/.config/hypr/colors.conf"
        '';
      }
      // lib.listToAttrs (
        map (f: lib.nameValuePair "hypr/config/${f}" { source = "${hyprDir}/config/${f}"; }) confFiles
      )
      // lib.listToAttrs (
        map (f: lib.nameValuePair "hypr/templates/${f}" { source = "${hyprDir}/templates/${f}"; }) templateFiles
      );

    # --- Mutable-copy hilesi (nixy deseni, caelestia/default.nix:206-220 ile aynı) ---
    # Üstakımın Settings popup'ı config/*.conf + templates/*.template dosyalarına
    # runtime'da yazıyor; HM symlink'i kalırsa yazamaz (nix store salt-okunur).
    # checkLinkTargets linkGeneration'dan ÖNCE koşar ve bayat bir .hm-backup'ta hata
    # verir — bu yüzden temizlik entryBefore["checkLinkTargets"], symlink→yazılabilir
    # kopya dönüşümü entryAfter["linkGeneration"] olmak ZORUNDA (sıra tersine
    # dönerse switch her seferinde kırılır). Çoğul dosya seti tek bir `for` döngüsüyle
    # kapsanıyor — caelestia'nın tekil-dosya desenini yedi kez tekrarlamaktan daha
    # temiz.
    home.activation.serpantinumCleanBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for rel in ${mutableFileList}; do
        run rm -f "$HOME/.config/$rel.hm-backup"
      done
    '';
    home.activation.serpantinumMutableConfigs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      for rel in ${mutableFileList}; do
        f="$HOME/.config/$rel"
        if [ -L "$f" ]; then
          run cp --remove-destination "$(readlink -f "$f")" "$f"
          run chmod u+w "$f"
        fi
      done
    '';
  };
}
