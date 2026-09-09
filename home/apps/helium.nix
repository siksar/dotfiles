# Helium — Chromium tabanlı, gizlilik odaklı tarayıcı (imputnet).
#
# TARİHÇE, çünkü bu dosya bir geri dönüş: Helium 2 Tem 2026'da flake input olarak
# eklenmiş (06db607), 4 Tem'de Zen lehine düşürülmüştü. Gerekçesi hâlâ zen.nix'in
# ikinci satırında duruyor — "Chromium tabanı istenen özelleştirmeleri
# desteklemiyordu". 3 Eyl 2026'da kullanıcı isteğiyle geri geldi. Zen'in YERİNE
# değil, YANINDA; firefox.nix ile aynı ilişki, aynı kural: öntanımlı tarayıcı
# DEĞİŞMEZ, xdg mime varsayılanlarına dokunulmuyor, http/https hâlâ zen'e gidiyor.
#
# BEDELİ AÇIK YAZILIYOR — bu depo "ikinci Chromium yığını"nı iki kez reddetti:
# downloads.nix'te motrix (+280 MiB), ve deezer-enhanced (edfbb3c ile kaldırıldı).
# Halihazırdaki tek istisna usr/netflix.nix'in Widevine için çektiği google-chrome'du.
# Bu dosya o kuralın bilinçli İKİNCİ istisnası: kural yanlışlandığı için değil,
# kullanıcı bedeli bilerek kabul ettiği için duruyor. Kuralı silme — istisnayı say.
#
# PAKETLEME: .deb'den dpkg + patchelf + wrapGAppsHook3 ile açılıyor, kaynaktan
# derleme YOK (Caelestia/quickshell gibi bir maliyet getirmez). Bağımlılıklarında
# libva/wayland/pipewire tanımlı, yani VAAPI donanım kod çözme yolu hazır.
#
# WAYLAND: ekstra bayrak GEREKMİYOR. Upstream sarmalayıcı NIXOS_OZONE_WL'i bizzat
# okuyor (helium.nix:259 → --ozone-platform-hint=auto), configuration.nix da o
# değişkeni sistem geneli "1" yapıyor. Yani nixpkgs'in Electron/Chromium
# sarmalayıcılarıyla aynı davranış, elle --ozone-platform eklemeye gerek yok.
{ inputs, ... }:

{
  imports = [ inputs.helium-browser.homeModules.default ];

  programs.helium = {
    enable = true;

    # UYARI (upstream modülün kendi notu): Chromium tabanlı tarayıcılar
    # KULLANICI seviyesindeki policy dosyasını (~/.config/helium/policies/managed/)
    # her zaman güvenilir biçimde okumaz. Bu üçü kritik değil — okunmazsa kayıp
    # sadece varsayılan davranışa dönmek olur. Zorlaması gereken bir policy
    # çıkarsa doğru yer bu dosya değil, upstream'in nixosModules.default'u.
    policies = {
      MetricsReportingEnabled     = false; # telemetri (zen.nix'teki DisableTelemetry karşılığı)
      DefaultBrowserSettingEnabled = false; # "beni varsayılan yap" uyarısı — zen varsayılan kalsın
      # Güç bütçesiyle doğrudan ilgili: kapatıldıktan sonra arka planda süreç
      # bırakmasın. Chromium ailesi varsayılanda bunu yapar; bu depoda boşta
      # dönen hiçbir şey istenmiyor (bkz. system/kernel/sched.nix tasarım notu).
      BackgroundModeEnabled       = false;
    };
  };
}
