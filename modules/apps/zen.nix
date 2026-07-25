# Zen Browser — Firefox tabanlı
# (Helium'un yerine: Chromium tabanı istenen özelleştirmeleri desteklemiyordu)
{ inputs, ... }:

{
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true; # güncellemeler nix'ten gelir
      DisableTelemetry = true;
    };
  };

  # Profil adamadan zen hedefi no-op + her rebuild'de "profileNames boş" uyarısı
  # basıyor → kapat. Aşağıdaki reçete uygulanırken true'ya çevrilir.
  stylix.targets.zen-browser.enable = false;

  # ── Zen renk/saydamlık teması: BİLİNÇLİ ADIM olarak bekliyor ──────────────
  # Stylix'in zen hedefi userChrome/userContent CSS'ini yalnız HM-YÖNETİMLİ bir
  # `programs.zen-browser.profiles.<ad>` altına yazabiliyor (profil olmadan hiç
  # uygulanmıyor — build sırasındaki "profileNames boş" uyarısının sebebi bu).
  #
  # SORUN: kullanıcının ZATEN gerçek verili bir zen profili var —
  # ~/.config/zen/r1lawe90.Default Profile (yer imleri/geçmiş/açık sekmeler).
  # profiles.ini'de Default=1. HM'de yeni bir profil tanımlamak bu profiles.ini'yi
  # bir store symlink'iyle değiştirir; zen ise profiles.ini'yi runtime'da YAZAR
  # → read-only symlink çakışması (bu repoda vesktop/vscodium'daki mutable-copy
  # sorununun aynısı) + yanlışlıkla boş profile düşme riski.
  #
  # GÜVENLİ YOL (kullanıcı onayıyla): mevcut profili HM'ye ADIYLA adapte et —
  # attr adı klasör adıyla birebir aynı olmalı ki HM userChrome'u mevcut profilin
  # İÇİNE symlink'lesin, yenisini yaratmasın:
  #
  #   stylix.targets.zen-browser.enable = true;   # yukarıdaki false'ı kaldır
  #   stylix.targets.zen-browser.profileNames = [ "r1lawe90.Default Profile" ];
  #   programs.zen-browser.profiles."r1lawe90.Default Profile" = {
  #     settings."zen.workspaces.continue-where-left-off" = true;
  #   };
  #
  # Uygulamadan ÖNCE: profiles.ini gerekirse mutable-copy aktivasyonuyla
  # korunmalı (vesktop.nix deseni). Switch sonrası zen'in AYNI profille (yer
  # imleri yerinde) açıldığını DOĞRULA. Not: Hyprland active_opacity zaten
  # zen penceresini compositor seviyesinde camsı yapıyor — renk teması bu adımın
  # asıl kazancı, saydamlık değil.
}
