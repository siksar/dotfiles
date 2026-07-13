# Stylix taban tema verisi — TEK kaynak.
# Hem NixOS modülü (stylix.nix) hem standalone HM (stylix-standalone.nix)
# bunu tüketir. Modül DEĞİL, saf fonksiyon — target ayarları tüketicilerde.
{ pkgs }:

let
  # Aktif palet — "zixar-main" | "ergenekon" (değiştir + rebuild)
  palette = "zixar-main";

  # Palete eşlik eden duvar kağıdı (GNOME arka planı + build-time türetmeler)
  wallpaper = {
    zixar-main = ./wallpapers/kanagawa.png;
    ergenekon = ./wallpapers/bonfire.png;
  };
in
{
  enable = true;
  polarity = "dark";

  # Kişisel paletler — eski Caelestia şemalarından base16'ya çevrildi (schemes/)
  base16Scheme = ./schemes + "/${palette}.yaml";

  image = wallpaper.${palette};

  fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sansSerif = {
      package = pkgs.inter;
      name = "Inter";
    };
    serif = {
      package = pkgs.inter;
      name = "Inter";
    };
    emoji = {
      package = pkgs.noto-fonts-color-emoji;
      name = "Noto Color Emoji";
    };
  };

  # Klasik macOS oku (apple-cursor)
  cursor = {
    package = pkgs.apple-cursor;
    name = "macOS";
    size = 24;
  };
}
