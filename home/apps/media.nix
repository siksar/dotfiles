# Medya uygulamaları (HM)
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Deezer istemcisi (resmi olmayan Linux portu, Electron 41).
    # deezer-enhanced 16 Ağu 2026'da kaldırıldı: kullanılmıyordu ve Electron değil
    # NW.js 0.102 tabanlıydı — yani ikinci bir Chromium yığını taşıyordu.
    deezer-desktop
  ];
}
