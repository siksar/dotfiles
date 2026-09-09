# KDE Plasma 6 — KARANTİNALI dördüncü oturum denemesi (24 Ağu 2026).
#
# Serpantinum'la (system/desktop/serpantinum.nix) aynı sözleşme: mevcut Caelestia
# oturumuna (desktop.hyprland.enable) HİÇ dokunmadan ly'ye ayrı bir girdi ekler,
# `desktop.plasma.enable = false;` ile tek satırda geri alınır. Serpantinum'dan
# farkı, burada sarmalayıcı/rice ağacı YAZILMAZ — upstream nixpkgs modülü
# (services.desktopManager.plasma6) oturumun tamamını kendisi kurar; bu dosyanın
# işi yalnızca o modülün BU MAKİNEYE özgü kenarlarını yamamak.
#
# NEDEN DENEME: Hyprland burada sadece pencere yöneticisi değil, güç zincirinin
# bir halkası (dGPU'yu D3cold'da tutan AQ_DRM_DEVICES + AC/BAT tazeleme geçişi).
# Plasma'ya "geçmek" o halkayı değiştirmek demek, ve zincirin geri kalanı ÖLÇÜMLE
# kuruldu. Bu yüzden önce karantinalı deneme, sonra karar. Karar kriteri ölçüm:
#   Documentation/aerox16/power.md yöntemi (120s sakinleşme + 6×10s örnek)
#   → Plasma oturumunda idle 4.28W ± gürültü çıkıyorsa geçiş teknik olarak açık.
{ config, lib, ... }:

let
  cfg = config.desktop.plasma;
in
{
  options.desktop.plasma.enable = lib.mkEnableOption
    "KDE Plasma 6 — karantinali deneme oturumu (ly'de ayri girdi, Caelestia'ya dokunmaz)";

  config = lib.mkIf cfg.enable {
    # Oturumun kendisi. `services.displayManager.sessionPackages`'a plasma-workspace'in
    # oturum dosyalarını ekler (plasma = Wayland, plasmax11 = X11) — ly ikisini de
    # listeler. SDDM AÇILMAZ: modül sddm'in package/theme/wayland alanlarını doldurur
    # ama `sddm.enable`'a dokunmaz, dolayısıyla ly greeter olarak kalır.
    #
    # `defaultSession` ÇAKIŞMASI YOK, ama incedir: modül
    # `services.displayManager.defaultSession = mkDefault "plasma"` diyor;
    # configuration.nix ise DÜZ (mkDefault'suz) "hyprland-uwsm" veriyor. Düz tanım
    # mkDefault'u yener, yani varsayılan oturum Caelestia'da kalır. configuration.nix'teki
    # o satır bir gün mkDefault'a çevrilirse ly SESSİZCE Plasma'yı öntanımlı yapar.
    services.desktopManager.plasma6.enable = true;

    #### Karantina sınırı 1 — dGPU uykuda kalsın (4.28W bütçesi) ####
    # AQ_DRM_DEVICES'in kwin karşılığı. Aynı gerekçe (system/desktop/session.nix'teki
    # uzun nota bak): compositor NVIDIA dGPU'nun DRM node'unu açarsa o açık fd
    # kartın RTD3/D3cold'a girmesini bloke eder ve idle tabanı ~4.3W'tan ~7W'a çıkar.
    # kwin bu değişkeni libkwin'in DRM backend'inde okuyor (binary'de doğrulandı).
    #
    # DEĞER İKİ NOKTA (:) İÇEREMEZ — kwin de aquamarine gibi ':' ile ayrılmış bir
    # cihaz listesi bekler, yani `by-path` adları ("pci-0000:65:00.0-card") burada da
    # üç geçersiz parçaya bölünür. Bu yüzden yine iki-nokta-içermeyen bir udev symlink'i.
    #
    # KENDİ SYMLINK'İ, hypr-igpu'yu ÖDÜNÇ ALMAZ: karantina kuralı — iki oturum
    # birbirinin dosyasına dayanmamalı (serpantinum.nix'teki duvar kağıdı notuyla aynı
    # gerekçe). desktop.hyprland.enable kapatılırsa bu oturum yine de açılabilmeli.
    environment.sessionVariables.KWIN_DRM_DEVICES = "/dev/dri/kwin-igpu";

    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="amdgpu", SYMLINK+="dri/kwin-igpu"
    '';

    #### Karantina sınırı 2 — oturum DIŞINA taşan servisler ####
    # Kural: Plasma oturumunun İÇİNDE koşan her şey (powerdevil, baloo, kded6, orca)
    # varsayılan bırakıldı — "default kurulum" istendi ve o bileşenler yalnız Plasma'ya
    # girildiğinde ayakta olur, Caelestia'da sıfır maliyetlidir. Sistem geneline SIZAN,
    # yani Caelestia'dayken de koşan şeyler ise karantina ihlalidir ve burada kapanır.
    #
    # fwupd: plasma6 modülü `mkDefault true` yapıyor. Kendisi D-Bus aktivasyonlu ama
    # modül `fwupd-refresh.timer`'ı da kuruyor — o KALICI bir timer, Plasma'ya hiç
    # girilmese bile koşar. CLAUDE.md'nin sert kuralı: system/ altına idle'da koşan/
    # yoklayan bir şey EKLENMEZ. Düz `false` mkDefault'u yener, mkForce gerekmez.
    services.fwupd.enable = false;

    #### Bilinen sızıntılar — kapatılmadı, kayda geçti ####
    # 1) environment.sessionVariables.XDG_CONFIG_DIRS += "$HOME/.config/kdedefaults"
    #    (plasma6 modülü, koşulsuz). PAM üzerinden HER oturuma girer, Caelestia dahil.
    #    Zararsız: dizin Plasma bir kez çalışana dek yok, var olduğunda da içindeki
    #    kdeglobals'ı yalnız Qt/KDE uygulamaları okur. Kapatmak modülü mkForce'la
    #    dövmek demekti; sızıntı ölçülebilir bir maliyet taşımıyor.
    # 2) xdg.portal.extraPortals += xdg-desktop-portal-kde. Portal seçimi .portal
    #    dosyasındaki `UseIn=` ile masaüstü başına yapılır (xdph'ninki
    #    "wlroots;Hyprland;sway;..." — doğrulandı), yani Caelestia'da xdpk devreye
    #    girmez. Yine de ekran paylaşımı Hyprland tarafında bozulursa İLK bakılacak yer
    #    burasıdır: `xdg.portal.config.Hyprland` ile açıkça pinlemek çözüm olur.
    # 3) Stylix'in `kde` hedefi HM'de zaten AÇIK (`qt` hedefi kapalı) — Plasma
    #    kanagawa-dragon renkleriyle açılır, ayrıca bir şey yapmaya gerek yok.
    #    QT_QPA_PLATFORMTHEME sistem geneline SET EDİLMEZ (qt.platformTheme = null),
    #    yani Breeze ile qt6ct arasında bir çekişme yok.
    #
    # ÖLÇÜLMEMİŞ, DENEMENİN ASIL SORUSU: powerdevil ile power-display.nix'in
    # sahiplik çakışması. Plasma oturumundayken powerdevil hem sysfs parlaklığı hem
    # PPD profilini kendi mantığıyla sürer; power-display.nix'in ppd_apply()
    # doğrula-ve-zorla döngüsü (PPD 0.30'un no-op hatasına karşı yazılmıştı) onunla
    # yarışır. Caelestia'da hiçbir etkisi yok. Plasma'da ne olduğunu ÖLÇ, tahmin etme.
  };
}
