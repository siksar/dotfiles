# GNOME masaüstü altyapısı (system) — display manager: ly (bkz. ly.nix)
# Hyprland/Caelestia/SDDM rice'ının yerini aldı (eski hali: rice/caelestia dalı).
# Portallar, pipewire oturum entegrasyonu, keyring PAM'ı GNOME modülünden gelir.
#
# GDM 2026-07-18'de ly'ye bırakıldı (modules/desktop/ly.nix). GDM'e özel greeter
# scale-sabitleme (monitors.xml + tmpfiles) artık gereksiz — ly TTY'de çalışır,
# greeter mutter'ı yok, dolayısıyla ölçek sorunu da yok. GDM'e geri dönmek istenirse
# ly.nix'i kaldır + burada `services.displayManager.gdm.enable = true` aç.
{ pkgs, ... }:

{
  services.desktopManager.gnome.enable = true;

  # Sade kurulum — kullanılmayan GNOME uygulamaları gelmesin
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
    geary
    gnome-music
    gnome-maps
    gnome-contacts
    totem
  ];

  # dGPU D3cold koruması: mutter NVIDIA DRM node'unu HİÇ açmasın — açık fd
  # RTD3'ü bloke edip idle bütçesini (4.28W) bozar. Hyprland'deki
  # AQ_DRM_DEVICES=card1'in mutter karşılığı; PRIME offload (gamerun)
  # etkilenmez, oyun node'u kendisi açar.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", DRIVERS=="nvidia", TAG+="mutter-device-ignore"
  '';
}
