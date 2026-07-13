# Zen Browser — Firefox tabanlı
# (Helium'un yerine: Chromium tabanı istenen özelleştirmeleri desteklemiyordu)
{ inputs, ... }:

{
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true; # güncellemeler nix'ten gelir
      DisableTelemetry = true;
    };
  };
}
