# GNOME + GDM — masaüstü altyapısı (system)
# Hyprland/Caelestia/SDDM rice'ının yerini aldı (eski hali: rice/caelestia dalı).
# Portallar, pipewire oturum entegrasyonu, keyring PAM'ı GNOME modülünden gelir.
{ pkgs, ... }:

let
  # GDM greeter kendi mutter'ını monitors.xml'siz açar → panelde otomatik
  # scale/mod seçimi "düşük çözünürlük" görünümü verebiliyor. Oturumla aynı
  # yapılandırmaya sabitle: 2560x1600@165, scale 1 (panel: BOE NE160QDM-NYJ,
  # kimlik `gnome-randr` çıktısından).
  gdmMonitors = pkgs.writeText "gdm-monitors.xml" ''
    <monitors version="2">
      <configuration>
        <logicalmonitor>
          <x>0</x>
          <y>0</y>
          <scale>1</scale>
          <primary>yes</primary>
          <monitor>
            <monitorspec>
              <connector>eDP-1</connector>
              <vendor>BOE</vendor>
              <product>NE160QDM-NYJ</product>
              <serial>0x00000000</serial>
            </monitorspec>
            <mode>
              <width>2560</width>
              <height>1600</height>
              <rate>165.001</rate>
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
    </monitors>
  '';
in
{
  services.desktopManager.gnome.enable = true;
  services.displayManager.gdm.enable = true; # wayland varsayılan açık

  # /run/gdm her boot'ta tmpfs'te yeniden doğar — monitors.xml'i tmpfiles bağlar
  systemd.tmpfiles.rules = [
    "d /run/gdm/.config 0711 gdm gdm -"
    "L+ /run/gdm/.config/monitors.xml - - - - ${gdmMonitors}"
  ];

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
