# Medya uygulamaları (HM)
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    deezer-enhanced # resmi olmayan Deezer istemcisi (electron)
    deezer-desktop # düz Deezer istemcisi (resmi olmayan Linux portu), Enhanced'in yanında
  ];
}
