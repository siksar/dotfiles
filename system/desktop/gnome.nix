# GNOME — KARANTİNALI ikinci oturum (16 Eyl 2026). KDE Plasma'nın yerine geldi.
#
# Sözleşme plasma.nix'ten devralındı: varsayılan oturuma (COSMIC) HİÇ dokunmadan
# greeter'a ayrı bir girdi ekler, `desktop.gnome.enable = false;` ile tek satırda
# geri alınır. Oturumun tamamını upstream modül (services.desktopManager.gnome)
# kurar; bu dosyanın işi yalnız o modülün BU MAKİNEYE özgü kenarlarını yamamak.
#
# NEDEN KARANTİNA: masaüstü burada sadece pencere yöneticisi değil, güç zincirinin
# halkası (dGPU'yu D3cold'da tutan DRM guard) ve o zincir ÖLÇÜMLE kuruldu.
# Karar kriteri yine ölçüm: Documentation/aerox16/power.md yöntemi
# (120 s sakinleşme + 6×10 s örnek) → GNOME oturumunda idle 4.28 W ± gürültü.
#
# GREETER DEĞİŞMEZ: giriş ekranı COSMIC greeter (login.nix). GNOME modülü GDM'i
# ZORLAMIYOR — `services.displayManager.gdm.enable = true` satırı yalnız
# `nixos-generate-config` şablonunda (gnome.nix:250, okundu). `defaultSession` de
# etkilenmez: plasma6'nın aksine GNOME modülü ona hiç dokunmuyor.
{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.gnome;
in
{
  options.desktop.gnome.enable = lib.mkEnableOption
    "GNOME — karantinali ikinci oturum (greeter'da ayri girdi)";

  config = lib.mkIf cfg.enable {
    services.desktopManager.gnome.enable = true;

    #### Karantina sınırı 1 — dGPU uykuda kalsın (4.28W bütçesi) ####
    # ÜÇÜNCÜ SÖZDİZİMİ. COSMIC ve Plasma birer ORTAM DEĞİŞKENİ okur
    # (COSMIC_DRM_ALLOW_DEVICES virgüllü liste, KWIN_DRM_DEVICES ':' içeremeyen
    # yol); mutter'da böyle bir değişken YOK — bir udev ETİKETİ okur.
    # `mutter-device-ignore` string'i libmutter-18.so.0'da doğrulandı
    # (mutter 50.4, flake pin'inden çekilip binary'de arandı).
    #
    # Gerekçe aynı: compositor NVIDIA'nın DRM node'unu açarsa o açık fd kartın
    # RTD3/D3cold'a girmesini bloke eder, idle tabanı ~4.3W'tan ~7W'a çıkar.
    #
    # DRIVERS eşleşmesi, kart numarası DEĞİL: card0/card1 boot sırasına göre yer
    # değiştirebilir. Bu makinede ölçüldü (16 Eyl 2026): card0 = nvidia
    # (0000:64:00.0), card1 = amdgpu (0000:65:00.0).
    #
    # DOĞRULAMA (GNOME oturumunda, desktop.md'deki üç adımın karşılığı):
    #   cat /sys/bus/pci/devices/0000:64:00.0/power_state   → D3cold
    #   ls -l /proc/$(pgrep -x gnome-shell)/fd | grep dri   → yalnız card1
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="nvidia", TAG+="mutter-device-ignore"
    '';

    #### Karantina sınırı 2 — oturum DIŞINA taşan servisler ####
    # Kural (system/desktop/CLAUDE.md): oturumun İÇİNDE yaşayan varsayılanında
    # bırakılır, sistem geneline SIZAN kapatılır. GNOME'un sızdırdıkları
    # Plasma'nınkinden çok daha fazla — hepsi upstream'de `mkDefault`, düz `false`
    # onları yener, mkForce gerekmez.

    # Dosya indeksleyici + veritabanı. CLAUDE.md kural 6'nın açık ihlali:
    # boşta CPU ve disk yakar, üstelik $HOME'u COSMIC'teyken de tarayabilir.
    services.gnome.localsearch.enable = false;
    services.gnome.tinysparql.enable = false;

    # Ağa açılan üç servis — hiçbiri istenmiyor, üçü de oturumdan bağımsız koşar.
    services.gnome.rygel.enable = false; # DLNA/UPnP medya SUNUCUSU
    services.dleyna.enable = false; # DLNA istemci köprüsü
    services.gnome.gnome-user-share.enable = false; # WebDAV dosya paylaşımı
    services.gnome.gnome-remote-desktop.enable = false; # RDP/VNC sunucusu

    # geoclue2 BURADA KAPATILMIYOR: bu repoda kendi dosyası var
    # (system/net/geoclue.nix, düz `true`) ve orada ölçülmüş — D-Bus aktivasyonlu,
    # boşta koşmuyor, idle bütçesine etkisi sıfır. Buraya `false` yazmak eval'i
    # çakışmayla düşürür (16 Eyl 2026'da bir build bu yüzden düştü).

    # avahi: cosmic.nix zaten `false` diyor. Burada TEKRAR ediliyor çünkü karantina
    # kuralı "iki oturum birbirine dayanmasın" — COSMIC bir gün çıkarsa GNOME
    # avahi'yi geri açmamalı. İki düz `false` çakışma DEĞİL (types.bool eşit
    # değerleri birleştirir).
    services.avahi.enable = false;

    # Ekran okuyucu: COSMIC tarafında da kapatılmış olan bileşen.
    services.orca.enable = false;

    # ibus/fcitx sistem geneli ortam değişkenleri yazar (GTK_IM_MODULE vb.) ve
    # COSMIC oturumuna da girer. Türkçe klavye xkb ile çözülü, IM gerekmiyor.
    i18n.inputMethod.enable = false;

    # Tarayıcıya native-messaging host'u kuran köprü ve ilk-açılış sihirbazı:
    # ikisi de kalıcı sistem dosyası bırakır, karşılığı yok.
    services.gnome.gnome-browser-connector.enable = false;
    services.gnome.gnome-initial-setup.enable = false;

    # İlk açılış turu: her yeni kullanıcıda bir kez açılan tanıtım penceresi.
    environment.gnome.excludePackages = [ pkgs.gnome-tour ];

    #### Bilinen sızıntılar — kapatılmadı, kayda geçti ####
    # 1) services.gnome.evolution-data-server.enable — modül DÜZ `true` yazıyor
    #    (gnome.nix:338), yani kapatmak `mkForce` ister. Kapatılmadı: D-Bus
    #    aktivasyonlu, GNOME'a girilmedikçe uyanmaz, takvim/saat widget'ı ona
    #    bağlı. Ölçülebilir boşta maliyeti yok.
    # 2) xdg.portal.extraPortals += xdg-desktop-portal-gnome. Portal seçimi
    #    `.portal` dosyasındaki `UseIn=` ile masaüstü başına yapılır → COSMIC'te
    #    devreye girmez. Plasma'da da aynı sızıntı kayda geçmişti; ekran paylaşımı
    #    COSMIC'te bozulursa İLK bakılacak yer burası.
    # 3) services.hardware.bolt ve services.colord açık bırakıldı: ikisi de D-Bus
    #    aktivasyonlu, boşta koşmaz; bolt'un karşılığı bu makinede gerçek donanım
    #    (Thunderbolt).
    #
    # ÖLÇÜLMEMİŞ, DENEMENİN ASIL SORUSU (Plasma'dan devreden soru, powerdevil
    # yerine artık gsd-power): GNOME oturumundayken gnome-settings-daemon hem
    # sysfs parlaklığı hem PPD profilini kendi mantığıyla sürer;
    # power-display.nix'in ppd_apply() doğrula-ve-zorla döngüsü onunla yarışır.
    # COSMIC'te hiçbir etkisi yok. GNOME'da ne olduğunu ÖLÇ, tahmin etme.
    #
    # FN TUŞLARI ÇAKIŞMASI (Documentation/aerox16/fn-keys.md): GNOME
    # KEY_MICMUTE ve KEY_TOUCHPAD_TOGGLE'ı kendisi işler. `aero-fn-bridge`
    # servisi `--act` ile koştuğu için aynı basış İKİ kez işlenir (köprünün
    # wpctl'i + GNOME'unki) ve mikrofon aynı yere döner. Köprü bu yüzden
    # gnome-shell koşarken eylemi atlar — kontrol fn-bridge.pl'de.
  };
}
