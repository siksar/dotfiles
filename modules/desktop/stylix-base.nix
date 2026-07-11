# Stylix taban tema verisi — TEK kaynak.
# Hem NixOS modülü (stylix.nix) hem standalone HM (stylix-standalone.nix)
# bunu tüketir. Modül DEĞİL, saf fonksiyon — target ayarları tüketicilerde.
{ pkgs }:

{
  enable = true;
  polarity = "dark";

  # Everforest — Caelestia'nın varsayılan şemasıyla (everforest/medium/dark) uyumlu
  base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest-dark-medium.yaml";

  # Varsayılan duvar kağıdı (kabuk çizer; stylix build-time türetmeler için kullanır)
  image = ./wallpapers/everforest.png;

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
