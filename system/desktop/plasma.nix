# KDE Plasma 6 — KARANTİNALI ikinci oturum (24 Ağu 2026).
#
# Sözleşme: varsayılan oturuma (COSMIC) HİÇ dokunmadan greeter'a ayrı bir girdi
# ekler, `desktop.plasma.enable = false;` ile tek satırda geri alınır. Oturumun
# tamamını upstream nixpkgs modülü (services.desktopManager.plasma6) kurar; bu
# dosyanın işi yalnızca o modülün BU MAKİNEYE özgü kenarlarını yamamak.
#
# NEDEN KARANTİNA: masaüstü burada sadece pencere yöneticisi değil, güç zincirinin
# bir halkası (dGPU'yu D3cold'da tutan DRM guard + AC/BAT tazeleme geçişi) ve o
# zincirin geri kalanı ÖLÇÜMLE kuruldu. Karar kriteri yine ölçüm:
#   Documentation/aerox16/power.md yöntemi (120s sakinleşme + 6×10s örnek)
#   → Plasma oturumunda idle 4.28W ± gürültü çıkıyorsa geçiş teknik olarak açık.
#
# ── 11 EYL 2026: SARMALAYICI KALDIRILDI ───────────────────────────────────────
# Burada `plasma-session-quarantined` adlı bir sarmalayıcı + elle yazılmış bir
# `plasma-karantina.desktop` girdisi vardı. Tek işi HM'in Caelestia için koyduğu
# QT_QPA_PLATFORMTHEME=qt6ct değerini bu oturumda `kde`'ye geri çevirmekti (25 Ağu'da
# plasmashell'i kabuksuz bırakan zincir buydu).
# Caelestia Eylül 2026'da ağaçtan çıkınca o değişkenin KAYNAĞI kalmadı ve sarmalayıcı
# no-op'a döndü. Canlı doğrulama: HM profilinde QT_QPA_PLATFORMTHEME yok,
# oturumdaki değer zaten `kde` (Stylix'in qt hedefi yazıyor), `QT_STYLE_OVERRIDE=breeze`.
# Yani artık upstream'in stok `plasma.desktop` girdisi kullanılıyor; greeter'daki
# kafa karıştırıcı ikinci "Plasma (karantina)" satırı da kalktı.
# GERİ GELİRSE: Plasma tekrar kabuksuz açılırsa ilk bakılacak yer budur — oturumdaki
# QT_QPA_PLATFORMTHEME'i oku; `kde` değilse bir yerden qt6ct sızıyordur.
{ config, lib, ... }:

let
  cfg = config.desktop.plasma;
in
{
  options.desktop.plasma.enable = lib.mkEnableOption
    "KDE Plasma 6 — karantinali ikinci oturum (greeter'da ayri girdi)";

  config = lib.mkIf cfg.enable {
    # Oturumun kendisi. `services.displayManager.sessionPackages`'a plasma-workspace'in
    # oturum dosyalarını ekler (plasma = Wayland, plasmax11 = X11) — greeter ikisini de
    # listeler.
    #
    # GREETER'I BU DOSYA AÇMAZ: greeter seçimi system/desktop/login.nix'tedir.
    # Burada bir zamanlar "dolayısıyla ly greeter olarak kalır" yazıyordu; ARTIK
    # Plasma modülü oturum paketini kurar; greeter seçimine karışmaz.
    #
    # `defaultSession` ÇAKIŞMASI YOK, ama incedir: modül
    # `services.displayManager.defaultSession = mkDefault "plasma"` diyor;
    # configuration.nix ise DÜZ (mkDefault'suz) "cosmic" veriyor. Düz tanım mkDefault'u
    # yener, yani varsayılan oturum COSMIC'te kalır. configuration.nix'teki o satır bir
    # gün mkDefault'a çevrilirse greeter SESSİZCE Plasma'yı öntanımlı yapar.
    services.desktopManager.plasma6.enable = true;

    # Greeter'daki girdiler artık doğrudan upstream'den: `Plasma` (Wayland) ve
    # `Plasma (X11)`. Elle yazılmış üçüncü bir girdi YOK — gerekçesi dosya başındaki
    # "SARMALAYICI KALDIRILDI" notunda.

    #### Karantina sınırı 1 — dGPU uykuda kalsın (4.28W bütçesi) ####
    # COSMIC_DRM_ALLOW_DEVICES'in kwin karşılığı — ama SÖZDİZİMİ TERS (bkz. cosmic.nix).
    # Aynı gerekçe: compositor NVIDIA dGPU'nun DRM node'unu açarsa o açık fd
    # kartın RTD3/D3cold'a girmesini bloke eder ve idle tabanı ~4.3W'tan ~7W'a çıkar.
    # kwin bu değişkeni libkwin'in DRM backend'inde okuyor (binary'de doğrulandı).
    #
    # DEĞER İKİ NOKTA (:) İÇEREMEZ — kwin de aquamarine gibi ':' ile ayrılmış bir
    # cihaz listesi bekler, yani `by-path` adları ("pci-0000:65:00.0-card") burada da
    # üç geçersiz parçaya bölünür. Bu yüzden yine iki-nokta-içermeyen bir udev symlink'i.
    #
    # KENDİ SYMLINK'İ VAR, COSMIC'inkine dayanmaz: karantina kuralı — iki oturum
    # birbirinin dosyasına dayanmamalı. COSMIC kapatılırsa bu oturum yine de açılabilmeli
    # (COSMIC zaten symlink kullanmıyor, PCI kimliğiyle eşleşiyor).
    environment.sessionVariables.KWIN_DRM_DEVICES = "/dev/dri/kwin-igpu";

    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="amdgpu", SYMLINK+="dri/kwin-igpu"
    '';

    #### Karantina sınırı 2 — oturum DIŞINA taşan servisler ####
    # Kural: Plasma oturumunun İÇİNDE koşan her şey (powerdevil, baloo, kded6, orca)
    # varsayılan bırakıldı — "default kurulum" istendi ve o bileşenler yalnız Plasma'ya
    # girildiğinde ayakta olur, COSMIC'te sıfır maliyetlidir. Sistem geneline SIZAN,
    # yani COSMIC'teyken de koşan şeyler ise karantina ihlalidir ve burada kapanır.
    #
    # fwupd: plasma6 modülü `mkDefault true` yapıyor. Kendisi D-Bus aktivasyonlu ama
    # modül `fwupd-refresh.timer`'ı da kuruyor — o KALICI bir timer, Plasma'ya hiç
    # girilmese bile koşar. CLAUDE.md'nin sert kuralı: system/ altına idle'da koşan/
    # yoklayan bir şey EKLENMEZ. Düz `false` mkDefault'u yener, mkForce gerekmez.
    services.fwupd.enable = false;

    #### Bilinen sızıntılar — kapatılmadı, kayda geçti ####
    # 1) environment.sessionVariables.XDG_CONFIG_DIRS += "$HOME/.config/kdedefaults"
    #    (plasma6 modülü, koşulsuz). PAM üzerinden HER oturuma girer, COSMIC dahil.
    #    Zararsız: dizin Plasma bir kez çalışana dek yok, var olduğunda da içindeki
    #    kdeglobals'ı yalnız Qt/KDE uygulamaları okur. Kapatmak modülü mkForce'la
    #    dövmek demekti; sızıntı ölçülebilir bir maliyet taşımıyor.
    # 2) xdg.portal.extraPortals += xdg-desktop-portal-kde. Portal seçimi .portal
    #    dosyasındaki `UseIn=` ile masaüstü başına yapılır, yani COSMIC'te xdpk devreye
    #    girmez. Yine de ekran paylaşımı COSMIC tarafında bozulursa İLK bakılacak yer
    #    burasıdır: `xdg.portal.config.COSMIC` ile açıkça pinlemek çözüm olur.
    # 3) DERS (25 Ağu 2026, hâlâ geçerli): burada bir zamanlar "QT_QPA_PLATFORMTHEME
    #    sistem geneline SET EDİLMEZ (qt.platformTheme = null)" yazıyordu ve YANLIŞTI —
    #    ilk Plasma denemesini çökerten şey tam olarak buydu. nixos/modules/config/qt.nix'in
    #    VARSAYILANI (`default = null`) okunmuş, gerçek değer hiç eval edilmemişti.
    #    Gerçek değerler `platformTheme = "kde"` ve `style = "breeze"`, ikisini de
    #    STYLIX yazıyor (stylix/modules/qt/nixos.nix).
    #    DERS: bir seçeneğin değerini upstream kaynağındaki `default =` satırından
    #    çıkarma — `options.<yol>.definitionsWithLocations` ile KİMİN yazdığına bak.
    #
    #    QT_STYLE_OVERRIDE=breeze sistem geneli, yani COSMIC oturumundaki Qt
    #    uygulamalarına da giriyor. REGRESYON DEĞİL — Stylix'in qt hedefi tam olarak
    #    bunu istiyor ve renkleri kanagawa-dragon'dan alıyor, kök CLAUDE.md'nin
    #    "Stylix tek kaynak" kuralıyla uyumlu. Kapatmak istenirse tek satır:
    #    `qt.style = lib.mkForce null;` (breeze paketi plasma6'nın KENDİ
    #    systemPackages'ından geldiği için kaybolmaz — plasma6.nix:129, doğrulandı).
    #    NOT: eval bu yüzden bir uyarı basıyor — stylix qt platform'u `kde`
    #    desteklemiyor. Hata değil, beklenen.
    #
    # ÖLÇÜLMEMİŞ, DENEMENİN ASIL SORUSU: powerdevil ile power-display.nix'in
    # sahiplik çakışması. Plasma oturumundayken powerdevil hem sysfs parlaklığı hem
    # PPD profilini kendi mantığıyla sürer; power-display.nix'in ppd_apply()
    # doğrula-ve-zorla döngüsü (PPD 0.30'un no-op hatasına karşı yazılmıştı) onunla
    # yarışır. COSMIC'te hiçbir etkisi yok. Plasma'da ne olduğunu ÖLÇ, tahmin etme.
  };
}
