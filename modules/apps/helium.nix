# Helium — Chromium tabanlı hafif tarayıcı (nixpkgs'te yok, flake'ten)
{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.helium
  ];
}
