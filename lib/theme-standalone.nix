# YALNIZCA flake.nix'teki standalone homeConfigurations'ta import edilir.
# Gömülü HM'de (nh os switch) stylix NixOS modülünden otomatik propagate olur;
# bu dosya home.nix'e eklenirse çift tanım çakışması doğar.
{ pkgs, ... }:

{
  stylix = import ./theme.nix { inherit pkgs; };
}
