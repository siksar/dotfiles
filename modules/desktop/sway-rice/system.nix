# Sway rice — SİSTEM katmanı (varsayılan KAPALI), vyrx-dev/dotfiles kurulumunun
# NixOS'a deklaratif portu. GNOME'un ve Hyprland rice'ının yerine geçmez: üçüncü,
# tamamen bağımsız bir oturum. ly'de "Sway" ikinci/üçüncü seçenek olarak belirir,
# GNOME varsayılan kalır.
#
# Açmak için configuration.nix'te: rice.sway.enable = true;
# HM tarafı (hm.nix) gömülü HM'de osConfig üzerinden bunu OTOMATİK izler —
# ikinci bir anahtar çevirmek gerekmez (hyprland-rice/system.nix ile aynı desen).
# Ayrıntı: docs/sway-rice.md
{ config, lib, pkgs, ... }:

{
  options.rice.sway.enable =
    lib.mkEnableOption "Sway + noctalia-shell rice'ı (vyrx-dev/dotfiles portu)";

  config = lib.mkIf config.rice.sway.enable {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;

      # WLR_DRM_DEVICES: wlroots SADECE AMD iGPU'sunu açsın; NVIDIA dGPU node'una
      # hiç dokunmasın. Açık DRM fd, dGPU'nun RTD3 D3cold'una girmesini bloke eder
      # → 4.28W idle bütçesi gerilerdi. GNOME'daki mutter-device-ignore udev
      # kuralının ve Hyprland rice'ındaki AQ_DRM_DEVICES'in (system.nix) aynı
      # gerekçesi. Kendi udev symlink'i kullanılıyor (hyprland-rice ile
      # çakışmasın — iki rice birbirinden bağımsız kalsın).
      #
      # extraSessionCommands'ta (sessionVariables'ta DEĞİL): bu değişken sadece
      # sway'i etkilemeli, GNOME/Hyprland oturumlarına hiç sızmamalı. wlroots
      # AQ_DRM_DEVICES'ten farklı olarak ':' ayracını kabul eder, ama tek cihaz
      # kullanıyoruz.
      #
      # Koşullu: symlink yoksa değişken hiç set edilmez ve wlroots kendi
      # otomatik seçimine döner. Bu, `nh os build-vm` gibi amdgpu'nun (ve
      # dolayısıyla dGPU'nun da) bulunmadığı ortamlarda sway'in var olmayan
      # bir node'u açmaya çalışıp ölmesini engeller. Gerçek donanımda symlink
      # her zaman var; yoksa udev kuralı bozulmuş demektir — o dar senaryoda
      # oturumun açılması, siyah ekrana yeğdir (güç regresyonu ölçülebilir,
      # açılmayan oturum debug edilemez).
      # `[ … ] && export …` biçimi DEĞİL: bu, dosya yokken son komutun çıkış
      # kodunu 1 yapar ve sarmalayıcı `set -e` altındaysa oturumu düşürür.
      extraSessionCommands = ''
        if [ -e /dev/dri/sway-igpu ]; then
          export WLR_DRM_DEVICES=/dev/dri/sway-igpu
        fi
      '';
    };

    # Yukarıdaki değerin işaret ettiği kararlı iGPU node'u. hyprland-rice'ın
    # dri/hypr-igpu sembolik linkinin kardeşi — aynı KERNEL/DRIVERS eşleşmesi,
    # farklı isim (bağımsızlık için).
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="amdgpu", SYMLINK+="dri/sway-igpu"
    '';

    # Ekran paylaşımı wlr portal'ından, dosya seçici GTK'dan. programs.sway
    # modülü zaten xdg.portal.config.sway.default = "gtk" set ediyor —
    # ÜZERİNE YAZMIYORUZ (nixpkgs'in kendi varsayılanıyla çakışır); sadece
    # wlr implementasyonunu ekliyoruz, seçim sırası nixpkgs'e kalıyor.
    # xdg.portal.config.gnome/hyprland dallarına dokunulmuyor.
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    # Ekran kaydı: gpu-screen-recorder'ın setcap wrapper'ını NixOS opsiyonu halleder.
    programs.gpu-screen-recorder.enable = true;

    # Harici monitör parlaklığı (Mod+XF86AudioRaise/Lower → ddcutil setvcp).
    hardware.i2c.enable = true;
    users.users.zixar.extraGroups = [ "i2c" ];

    # scrcpy webcam modu (run-scrcpy): modül mevcut ama kernelModules'a
    # EKLENMEZ — boot'ta otomatik yüklenip idle'da durmasın; script çalıştığında
    # elle modprobe eder.
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];

    # noctalia pil widget'ı + [hooks] battery_under_threshold.
    services.upower.enable = true;

    # fish — vyrx'in kurulumuna sadık tam geçiş: login shell. Sistem paketi +
    # completion altyapısı burada, HM tarafındaki abbr/alias/function seti
    # modules/desktop/fish.nix'te (aynı rice.sway.enable'ı okur).
    #
    # RİSK: GNOME/ly girişini ve home-manager-zixar.service'in bash -el profil
    # zincirini etkiler (bkz. 0f0be6c). home.nix'teki .bash_profile mkForce'u
    # BUNA DOKUNMUYOR — login shell fish olsa da HM'in ürettiği .bash_profile
    # hâlâ var, sadece PAM/getty artık onu değil fish'i login shell olarak
    # başlatıyor. GNOME kendi oturumunu shell'den bağımsız başlattığından
    # (systemd --user + dbus, login shell'i pas geçer) burası GNOME'u
    # BOZMAMALI — ama switch sonrası doğrulanmalı: `ls -l /run/current-system/sw/bin/fish`
    # + GNOME'a giriş yap + `systemctl --user status home-manager-zixar.service`.
    # Geri alma: bu satırı silmek yeterli (fish.nix kendiliğinden devre dışı kalmaz,
    # rice.sway.enable = false ile birlikte kapanır).
    programs.fish.enable = true;
    users.users.zixar.shell = pkgs.fish;
  };
}
