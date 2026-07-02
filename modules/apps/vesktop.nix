# Vesktop — Vencord gömülü Discord istemcisi
# Caelestia CLI tema geçişinde caelestia.theme.css'i canlı günceller
# (enableDiscord=true); burada tema Vencord'da kalıcı olarak etkinleştirilir.
# settings.json'lar runtime'da uygulama tarafından da yazılır → mutable-copy
# hilesi modules/desktop/caelestia/default.nix'te merkezi yapılır.
{ ... }:

{
  programs.vesktop = {
    enable = true;
    settings = {
      tray = true;
      minimizeToTray = true;
    };
    vencord.settings = {
      enabledThemes = [ "caelestia.theme.css" ];
      useQuickCss = false;
    };
  };
}
