# Yalnız standalone homeConfigurations'ta; home.nix'e eklenirse çift tanım.
{ pkgs, ... }:

{
  stylix = import ./theme.nix { inherit pkgs; };
}
