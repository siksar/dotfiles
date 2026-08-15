# Firefox — baştan sona deklaratif ikinci tarayıcı (zen.nix'in YERİNE değil, YANINDA).
#
# Neden ayrı dosya, neden zen'den farklı davranıyor: zen.nix'i felç eden şey teknik bir
# eksik değil, VERİ — kullanıcının zaten dolu bir profili var (~/.config/zen/
# r1lawe90.Default Profile) ve HM'de profil tanımlamak profiles.ini'yi store symlink'ine
# çevirdiği için oraya dokunmak yer imlerini riske atıyor. Burada o risk YOK: ~/.mozilla
# hiç oluşmamış (15 Ağu doğrulandı, dizin mevcut değil), yani profili HM'nin baştan
# doğurması tamamen güvenli. Bu yüzden zen'de "bilinçli adım olarak bekleyen" her şey
# (Stylix teması, pref yönetimi) burada ilk günden açık.
#
# Öntanımlı tarayıcı DEĞİŞTİRİLMEZ — xdg mime varsayılanlarına dokunulmuyor, http/https
# hâlâ zen'e gidiyor. Bu dosya yalnız firefox'u KURAR.
#
# Bu dosya usr/firefox.nix'in YERİNİ ALDI (15 Ağu 2026). Orası konfigürasyonsuz tek
# satırlık bir `programs.firefox.enable = true;`ti; ikisi birlikte İKİ ayrı firefox
# kuruyordu (/run/current-system/sw/bin + /etc/profiles/per-user/zixar/bin, PATH'te
# HM'ninki kazanıyor) ve politika/pref/tema sahipliği ikiye bölünüyordu. Firefox
# artık tek sahipli: bu dosya. Sistem geneli firefox gerekirse önce burayı oku —
# usr/'a geri koymak bu dosyadaki her şeyi sessizce etkisiz KILMAZ ama iki kurulum
# sorununu geri getirir.
{ ... }:

{
  programs.firefox = {
    enable = true;

    # ── policies: kurumsal politika JSON'u ────────────────────────────────────
    # Determinizmin asıl kaldıracı bu. `settings` (aşağıda) bir prefs katmanı ve
    # kullanıcı arayüzden geçici olarak değiştirebilir; policies profilden BAĞIMSIZ
    # uygulanır ve about:config/arayüz üzerinden geri alınamaz — hangi profille
    # açılırsa açılsın aynı sonuç. Yani "kesin olsun" istenen şeyler buraya,
    # "varsayılan olsun" istenenler settings'e.
    policies = {
      DisableAppUpdate = true; # güncelleme nix'ten gelir (zen.nix ile aynı gerekçe)
      DisableTelemetry = true;
      DisableFirefoxStudies = true; # Shield/Normandy uzaktan deney dağıtımı
      DisablePocket = true;
      DisableFirefoxAccounts = false; # sync gerekebilir, kapatmak tek yönlü acı
      DisableFormHistory = false;
      DontCheckDefaultBrowser = true; # her açılışta "varsayılan yapayım mı" sorusu yok
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false; # parola yöneticisi 1Password (bkz. Documentation/1password.md)
      PasswordManagerEnabled = false;

      # Firefox'un KENDİ DoH'ı (TRR) BİLİNÇLİ kapalı — bu makinede DNS zaten
      # şifreli: uygulama → 127.0.0.53 (resolved) → 127.0.0.2 (dnscrypt) → NextDNS
      # (system/net/censorship.nix). Firefox kendi TRR'ını açarsa o zinciri
      # TAMAMEN atlar: NextDNS profil filtresi devre dışı kalır ve sansür katmanının
      # ölçülmüş davranışı yalnız bu uygulamada değişir. Sistem çözücüsünü kullan.
      DNSOverHTTPS = {
        Enabled = false;
        Locked = true;
      };

      EnableTrackingProtection = {
        Value = true;
        Locked = false;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;

      # settings → profile user.js olarak yazılır. Firefox runtime'da prefs.js'e yazar
      # ama user.js HER AÇILIŞTA yeniden uygulanır; yani buradaki bir değeri arayüzden
      # değiştirmek yalnız o oturum sürer, restart'ta geri döner. İstenen davranış bu:
      # tarayıcı ayarı repo'da, makinede değil.
      settings = {
        # Donanım video kod çözme — AMD 860M iGPU'da VA-API. Güç bütçesi (4.28W idle
        # kuralı değil ama aynı mantık) açısından önemli: yazılım kod çözme YouTube'da
        # CPU'yu boşuna Zen5c çekirdeklerinde koşturur.
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;

        # Telemetri/veri toplama — policies'in kapsamadığı kalanlar
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "browser.ping-centre.telemetry" = false;

        # Yeni sekme sayfası: sponsorlu içerik/öneri akışı kapalı
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.feeds.section.topstories" = false;

        # İlk açılış gürültüsü
        "browser.aboutConfig.showWarning" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.startup.homepage" = "about:home";

        # Wayland'de düzgün ölçekleme + dokunmatik yüzey kinetik kaydırma
        "gfx.webrender.all" = true;
        "apz.gtk.kinetic_scroll.enabled" = true;

        # userChrome.css'in okunması — Stylix'in firefox hedefi tam olarak oraya
        # yazıyor, bu pref olmadan yazdığı CSS sessizce yok sayılır.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };
    };
  };

  # Stylix firefox hedefi: profil ADI olmadan no-op + her rebuild'de uyarı basar
  # (zen.nix'teki "profileNames boş" uyarısının aynısı). Burada profil HM-yönetimli
  # olduğu için ad biliniyor — hedef ilk günden açık.
  stylix.targets.firefox = {
    enable = true;
    profileNames = [ "default" ];
  };
}
