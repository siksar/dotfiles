# Medya uygulamaları (HM)
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    deezer-enhanced # resmi olmayan Deezer istemcisi (electron)
  ];
}
