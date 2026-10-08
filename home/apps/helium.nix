# Helium (Chromium, .deb'den). Wayland: sarmalayıcı NIXOS_OZONE_WL'i okur, ek bayrak gerekmez.
{ inputs, ... }:

{
  imports = [ inputs.helium-browser.homeModules.default ];

  programs.helium = {
    enable = true;

    # Kullanıcı seviyesi policy'leri Chromium güvenilir okumaz; zorunlu olan upstream nixosModules'a.
    policies = {
      MetricsReportingEnabled     = false;
      DefaultBrowserSettingEnabled = false;
      BackgroundModeEnabled       = false;
    };
  };
}
