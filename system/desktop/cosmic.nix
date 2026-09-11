# COSMIC (COSMIC Epoch) — System76'nın Rust'la sıfırdan yazdığı masaüstü,
# 2 Eyl 2026. Pop!_OS'un GNOME eklentisi (`pop-shell`) yamama döneminin ardılı:
# bileşken `cosmic-comp` (Smithay), arayüz toolkit'i GTK/Qt değil `iced`.
#
# NEDEN VAR: 2 Eyl 2026'da "ana masaüstü adayı" olarak tam kalitede kuruldu;
# Eylül 2026'da Hyprland/Caelestia ağaçtan çıkınca ADAY DEĞİL, VARSAYILAN oldu
# (configuration.nix: defaultSession = "cosmic"). `desktop.cosmic.enable = false;`
# artık geri alma kolu değil — kapatırsan geriye yalnız Plasma kalır.
#
# OYUN — 2 Eyl'de "kapsam dışı", 11 EYL 2026'DA ÖLÇÜLDÜ VE KORKU ASILSIZ ÇIKTI.
# Eski not "COSMIC_DRM_ALLOW_DEVICES yalnız iGPU'ya izin verdiği için gamerun'ın
# PRIME offload'ı COSMIC'te çalışmaz" diyordu. Değişken yalnız COMPOSITOR'ın hangi
# DRM node'unu açacağını söyler; oyunun kendi süreci etkilenmez. Canlı COSMIC
# oturumunda ölçüldü (XDG_CURRENT_DESKTOP=COSMIC, değişken oturumda AKTİF):
#   vulkaninfo --summary           → hem RADV/860M hem NVIDIA RTX 5060 listeleniyor
#   GR_NOPERF=1 gamerun vulkaninfo → GPU1 = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
#   GR_NOPERF=1 gamerun env        → __NV_PRIME_RENDER_OFFLOAD=1 + _PROVIDER=NVIDIA-G0
# Aynı anda dGPU boştayken /sys/.../0000:64:00.0/power_state = D3cold, yani guard
# idle tasarrufunu da bozmuyor. İkisi birden çalışıyor.
#
# PLASMA'DAN İKİ FARKI VAR, ikisi de bilinçli:
#   1. Session wrapper YOK. plasma.nix'teki sarmalayıcı, HM'in
#      QT_QPA_PLATFORMTHEME=qt6ct değeri Breeze'i çökerttiği için vardı.
#      COSMIC iced/GTK tabanlı, Qt değil — o çekişme burada yok, upstream'in
#      `cosmic-session` oturum paketi doğrudan kullanılıyor.
#   2. udev kuralı YOK — bkz. aşağıdaki DRM guard notu.
{ config, lib, ... }:

let
  cfg = config.desktop.cosmic;
in
{
  options.desktop.cosmic.enable = lib.mkEnableOption
    "COSMIC masaustu — VARSAYILAN oturum (defaultSession configuration.nix.te)";

  config = lib.mkIf cfg.enable {
    # Oturumun tamamını upstream modülü kuruyor: cosmic-comp/panel/settings/launcher/
    # osd/idle/notifications + xdg-desktop-portal-cosmic + sessionPackages girdisi.
    # GREETER'I BU DOSYA AÇMAZ — modül `services.displayManager.enable`'a hiç
    # dokunmuyor; greeter seçimi system/desktop/login.nix'te verildi.
    #
    # `defaultSession` ÇAKIŞMASI YOK: COSMIC modülü onu hiç yazmıyor; configuration.nix
    # düz (mkDefault'suz) "cosmic" veriyor ve plasma6'nın mkDefault "plasma"sını yener.
    services.desktopManager.cosmic.enable = true;

    # xwayland.enable (varsayılan true) BİLEREK dokunulmadan bırakıldı — kullanıcı
    # kararı, 1 Eyl 2026. Gerekçe ÖLÇÜM: o an açık 6 pencereden 3'ü
    # XWayland'di ve üçü de Steam'di; workstation uygulamalarının tamamı zaten native
    # Wayland (NIXOS_OZONE_WL configuration.nix'te sistem geneli). Yani XWayland'i
    # kapatmanın workstation'a kazandıracağı bir şey yok, oyun fazında ise geri
    # açılması gerekirdi. Saflık doğrulaması: COSMIC'te `xlsclients` BOŞ dönmeli.

    #### dGPU uykuda kalsın (4.28W idle bütçesi) ####
    # KWIN_DRM_DEVICES (plasma.nix) ile AYNI
    # gerekçe: bileşken NVIDIA dGPU'nun DRM node'unu açarsa o açık fd kartın
    # RTD3/D3cold'a girmesini bloke eder ve idle taban ~4.3W'tan ~7W'a çıkar.
    #
    # ANCAK SÖZDİZİMİ FARKLI — bu dosyaya diğer üçünün notunu KOPYALAMA, aktif hata
    # olur. cosmic-comp/src/utils/env.rs okundu (dev_list_var + try_parse_dev_from_str):
    #   * Liste ayırıcısı VİRGÜL (`value.split(',')`), iki nokta DEĞİL.
    #   * Kabul edilen dört sözdiziminden ÜÇÜ iki nokta İÇERMEK ZORUNDA:
    #       "0xVVVV:0xDDDD"  → PCI vendor:device      (kullanılan)
    #       "major:minor"    → char cihaz numarası
    #       "pci-0000:65:00.0" → /dev/dri/by-path/<ad>-render okunur
    #       "<ad>"           → /dev/dri/<ad> yolu
    #   Yani Plasma'nın "değer iki nokta İÇEREMEZ" kuralı burada TERSİNE döner.
    #
    # BU YÜZDEN udev SYMLINK'İ YOK (kwin-igpu desenini tekrarlama):
    # PCI kimliğiyle eşleşmek boot sırasından zaten bağımsız, symlink gereksiz bir
    # dolaylılık olurdu.
    #
    # Değer ÖLÇÜLDÜ (1 Eyl 2026) — DeviceIdentifier::Id::matches() render node'un
    # /sys/dev/char/<major>:<minor>/device/{vendor,device} dosyalarını okuyor:
    #   AMD Radeon 860M  iGPU  65:00.0  renderD128  226:128 → 0x1002 / 0x1114  ← izinli
    #   NVIDIA RTX 5060  dGPU  64:00.0  renderD129  226:129 → 0x10de / 0x2d19
    #
    # Değişken environment.sessionVariables ile PAM üzerinden oturuma girer, yani
    # cosmic-session compositor'ı exec etmeden ÖNCE oradadır. Plasma oturumuna da
    # sızar; maliyeti SIFIR — bu değişkeni yalnız cosmic-comp okur (KWIN_DRM_DEVICES
    # de bugün aynı şekilde sızıyor ve etkisiz).
    environment.sessionVariables.COSMIC_DRM_ALLOW_DEVICES = "0x1002:0x1114";

    #### Karantina sınırı — COSMIC oturumunun DIŞINDA da koşacak olanlar ####
    # Kural (kök CLAUDE.md): system/ altına idle'da koşan/yoklayan bir şey EKLENMEZ.
    # COSMIC modülünün getirdiği servisler mevcut sisteme karşı tek tek ölçüldü;
    # acpid/upower/accounts-daemon/geoclue2/power-profiles-daemon/networkmanager/
    # bluetooth/gvfs ZATEN açıktı → yeni maliyet yok. Yalnız şu ikisi yeni:
    #
    # avahi: mDNS/Bonjour daemon'ı (ağ yazıcısı, SMB/NAS, Chromecast otomatik keşfi).
    # Modül `mkDefault true` yapıyor ama bu makinede HİÇ KURULU DEĞİLDİ (not-found) ve
    # onu isteyen bir tüketici de yok — yani kazanç sıfır, bedel kalıcı bir daemon.
    # Ağ yazıcısı eklenirse BU SATIR geri açılır (elle IP ile erişim yine mümkün).
    services.avahi.enable = false;

    # orca: ekran okuyucu. Yine mkDefault ve yine sistemde hiç yoktu.
    services.orca.enable = false;

    #### Bilinen sızıntılar — kapatılmadı, kayda geçti ####
    # 1) xdg.portal.configPackages — plasma6 ve cosmic modüllerinin İKİSİ DE mkDefault
    #    kullanıyor (doğrulandı), yani eşit öncelikte BİRLEŞİYORLAR;
    #    xdg-desktop-portal-cosmic kendiliğinden kaydoluyor, elle eklemek gerekmiyor.
    #    Portal SEÇİMİ .portal dosyasındaki UseIn= ile masaüstü başına yapılır, yani
    #    iki oturum birbirini bozmamalı — ama ekran paylaşımı bozulursa İLK bakılacak
    #    yer burasıdır.
    # 2) environment.sessionVariables.X11_{BASE,EXTRA}_RULES_XML — modül koşulsuz
    #    yazıyor, her oturuma girer. Zararsız: yalnız libcosmic/xkb tarafı okur.
    # 3) xdg.icons.fallbackCursorThemes = mkDefault [ "Cosmic" ] — yalnız FALLBACK;
    #    Stylix imleci açıkça veriyor, o kazanır.
    # 4) fonts.packages += fira, noto-fonts, open-sans — yalnız closure büyümesi.
    #
    #### TEMA: BİLEREK YÖNETİLMİYOR — bkz. Documentation/desktop.md ####
    # Stylix'in NixOS hedefleri arasında `cosmic` YOK (doğrulandı), ve bir köprü de
    # KURULMADI. Gerekçe kullanıcı kararı: COSMIC'in görünümü tamamen kendi ayar
    # menüsünden yönetilsin, imperatif kalsın. cosmic-config iki katmanlı —
    # libcosmic'in ConfigGet::get() önce ~/.config/cosmic/<ad>/v<N>/<key>'e bakar,
    # bulamazsa $XDG_DATA_DIRS/cosmic/... sistem varsayılanına düşer. Yani KULLANICI
    # KATMANI HER ZAMAN KAZANIR.
    #
    # BUNUN SONUCU BİR YASAK: ~/.config/cosmic altına Nix'ten hiçbir şey yazılmayacak
    # — ne home.file, ne xdg.configFile, ne activation script. Oraya bir store
    # symlink'i koymak dosyayı salt-okunur yapar ve ayar menüsü SESSİZCE kaydedemez
    # hâle gelir. Sistem varsayılanı gerçekten gerekirse tek meşru yol
    # /share/cosmic/<ad>/v<N>/<key>'dir (modül zaten environment.pathsToLink'e ekliyor).
  };
}
