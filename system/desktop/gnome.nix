{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.gnome;
in
{
  options.desktop.gnome.enable = lib.mkEnableOption
    "GNOME — karantinali ikinci oturum (greeter'da ayri girdi)";

  config = lib.mkIf cfg.enable {
    services.desktopManager.gnome.enable = true;

    # DRM guard: mutter env değil udev ETİKETİ (mutter-device-ignore) okur. DRIVERS ile eşleş, kart
    # numarası boot'a göre kayar. externalDisplay açıkken yazılmaz. mkForce DEĞİL: extraRules birleşen metin.
    services.udev.extraRules =
      lib.optionalString (!config.desktop.externalDisplay.enable) ''
        SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="nvidia", TAG+="mutter-device-ignore"
      '';

    # Oturum dışına sızan upstream mkDefault servisleri; düz false yeter.

    services.gnome.localsearch.enable = false;
    services.gnome.tinysparql.enable = false;

    services.gnome.rygel.enable = false;
    services.dleyna.enable = false;
    services.gnome.gnome-user-share.enable = false;
    services.gnome.gnome-remote-desktop.enable = false;

    # geoclue2 burada kapatılmaz: geoclue.nix düz true diyor, çakışır.

    services.avahi.enable = false;

    services.orca.enable = false;

    # ibus/fcitx sistem geneli env yazar; xkb yeterli.
    i18n.inputMethod.enable = false;

    services.gnome.gnome-browser-connector.enable = false;
    services.gnome.gnome-initial-setup.enable = false;

    environment.gnome.excludePackages = [ pkgs.gnome-tour ];

    # evolution-data-server modülde düz true (mkForce ister); D-Bus aktivasyonlu, bırakıldı.
    # Fn tuşları: GNOME MICMUTE/TOUCHPAD_TOGGLE'ı kendisi işler → aero-fn-bridge gnome-shell varken eylemi atlar.
  };
}
