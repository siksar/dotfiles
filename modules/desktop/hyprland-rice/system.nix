# Hyprland + Matugen dinamik tema rice'ı — SİSTEM katmanı (varsayılan KAPALI)
#
# GNOME'un yerine geçmez: programs.hyprland yalnız oturum dosyasını, paketi ve
# xdg-desktop-portal-hyprland'i ekler; GDM giriş ekranında "Hyprland" ikinci
# seçenek olarak belirir, GNOME varsayılan kalır.
#
# Açmak için configuration.nix'te: rice.hyprland.enable = true;
# HM tarafı (hm.nix) gömülü HM'de osConfig üzerinden bunu OTOMATİK izler —
# ikinci bir anahtar çevirmek gerekmez. Standalone `hms` yolunda osConfig
# olmadığından gerekirse home.nix'te elle açılır.
{ config, lib, pkgs, ... }:

{
  options.rice.hyprland.enable =
    lib.mkEnableOption "Hyprland 0.55+ (Lua config) + Matugen dinamik tema rice'ı";

  # atif-1402/minimal-waybar-themes portlarından biri (V1..V7) veya "current"
  # (Anto98765 portu, matugen renkli — varsayılan). Geçerli isimler
  # hm.nix'teki waybar-themes.nix'in ürettiği attrset'in anahtarları +
  # "current". Deneme aşamasında `waybar-theme <ad>` ile rebuild'siz de
  # değiştirilebilir; bu seçenek yalnız temiz kurulumdaki varsayılanı belirler.
  options.rice.hyprland.waybarTheme = lib.mkOption {
    type = lib.types.str;
    default = "current";
    description = "Varsayılan Waybar teması (bkz. modules/desktop/hyprland-rice/waybar-themes.nix)";
  };

  config = lib.mkIf config.rice.hyprland.enable {
    # gpu-screen-recorder'ın setcap wrapper'ı — omarchy-cmd-screenrecord shim'i
    # (waybar-omarchy-compat.nix) ve elle ekran kaydı kısayolları için.
    programs.gpu-screen-recorder.enable = true;

    # Aşağıdaki dördü daha önce GNOME modülünün mkDefault'larından geliyordu
    # (services.desktopManager.gnome.enable); tek oturum kalınca burada açık
    # tanımlanmaları gerekiyor — yoksa bluetooth/USB otomatik bağlama/GTK dosya
    # seçici/nautilus çöp kutusu sessizce kaybolur.
    hardware.bluetooth.enable = true; # bluetuith, waybar format-bluetooth
    services.udisks2.enable = true; # USB otomatik bağlama
    services.gvfs.enable = true; # nautilus çöp kutusu / ağ konumları

    # xdg.portal.enable zaten programs.hyprland'den geliyor; xdph dosya-seçici
    # ve Settings portallarını doyurucu uygulamıyor, GTK portalı ekleniyor.
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

    # hyprlock'un PAM servisi — HM modülünün kendi belgesi bunu şart koşuyor:
    # olmadan hyprlock parolayı asla doğrulayamaz, kilit ekranından çıkılamaz.
    security.pam.services.hyprlock = { };

    # nixpkgs'teki 0.55.4 — "hyprland.lua" çağı (hyprlang deprecate edildi).
    # Paket sistemden gelir; HM tarafında package = null (çifte kurulum ve
    # portal çakışması olmasın).
    programs.hyprland.enable = true;

    # uwsm: Hyprland'i systemd oturumu olarak başlatır (upstream'in önerdiği yol).
    # KAPALIYKEN bile hyprland paketi "Hyprland (uwsm-managed)" oturum dosyasını
    # GDM'e koyar (module satır 107: sessionPackages = [ cfg.package ]); ama
    # uwsm systemd unit'leri (wayland-session-bindpid@.service) kurulmadığından
    # o giriş ÇALIŞMAZ — GDM "Unit not found" verip oturumu düşürür. true yapmak
    # programs.uwsm.enable'ı da açar (module satır 116) ve o girişi çalışır kılar.
    programs.hyprland.withUWSM = true;

    # AQ_DRM_DEVICES: aquamarine SADECE AMD iGPU'sunu açsın; NVIDIA dGPU node'una
    # (card0, pci 64:00.0) HİÇ dokunmasın. İki neden:
    #   1) Açık DRM fd, dGPU'nun RTD3 D3cold'una girmesini bloke eder → 4.28W
    #      idle bütçesi gerilerdi (gnome.nix'teki mutter-device-ignore'un karşılığı).
    #   2) Kısıtlama olmadan aquamarine iki GPU'yu da açmayı deneyip başlangıçta
    #      çöküyordu (CBackend::create failed) — Hyprland'e girilememesinin nedeni.
    #
    # DEĞER İKİ NOKTA (:) İÇEREMEZ: aquamarine AQ_DRM_DEVICES'i ':' ile ayırır
    # (PATH gibi çoklu-cihaz listesi). by-path adı 'pci-0000:65:00.0-card' iki
    # nokta içerdiğinden ÜÇ geçersiz parçaya bölünür → aquamarine "found no gpus"
    # der, backend yaratamaz, çöker. (Bunu crash raporu kanıtladı — ilk denememde
    # by-path kullanmıştım, aynı çöküş sürdü.) Bu yüzden cardN yerine, sürücüye
    # göre sabit ve iki-nokta-İÇERMEYEN bir udev symlink'ine işaret ediyoruz.
    #
    # BURADA (oturum ortamında) set edilmek ZORUNDA: aquamarine bu değişkeni
    # backend'i kurarken, yani Hyprland daha config'i okumadan okur. Config
    # içindeki hl.env/`env=` çok geç kalır (bkz. lua/main.lua'daki uzun not).
    # sessionVariables, PAM üzerinden GDM'in başlattığı oturuma compositor exec
    # edilmeden önce girer — hem düz hem uwsm giriş yolunda geçerli. AQ_* yalnız
    # aquamarine'i etkiler, dolayısıyla GNOME oturumunda tamamen zararsızdır.
    environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/hypr-igpu";

    # Yukarıdaki değerin işaret ettiği kararlı, iki-nokta-İÇERMEYEN iGPU node'u.
    # gnome.nix'teki 'SUBSYSTEM=="drm", DRIVERS=="nvidia"' kuralının kardeşi;
    # KERNEL=="card[0-9]*" ile yalnız KMS kart düğümüne (renderD* değil) bağlanır,
    # DRIVERS=="amdgpu" ile boot sırasından bağımsız hep AMD iGPU'yu yakalar.
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="amdgpu", SYMLINK+="dri/hypr-igpu"
    '';
  };
}
