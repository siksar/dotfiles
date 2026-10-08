# Mullvad KAPALI: zapret'in nfqueue kuralıyla çakışır. Açarsan zapret'i kapat.
# `package`e dokunma (pkgs.mullvad-vpn yalnız GUI; assertion düşer) — GUI için gui.enable.
{ ... }:

{
  services.mullvad-vpn = {
    enable = false;
    gui.enable = false;
  };
}
