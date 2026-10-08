# Stylix tema verisi — tek kaynak; modül değil, `{ pkgs }:` fonksiyonu (NixOS + HM).
{ pkgs }:

let
  # Aktif palet: zixar-main | ergenekon | kanagawa-dragon | clouds-dusk
  palette = "clouds-dusk";

  wallpaper = {
    zixar-main = ./wallpapers/kanagawa.png;
    ergenekon = ./wallpapers/bonfire.png;
    kanagawa-dragon = ./wallpapers/kanagawa.png;
    clouds-dusk = ./wallpapers/clouds-dusk.jpg; # pexels, A. Taranenko
  };
in
{
  enable = true;
  polarity = "dark";

  # Saydamlık — tek kaynak; yalnız Stylix hedeflerine uygulanır.
  opacity = {
    applications = 0.92;
    terminal     = 0.85;
    popups       = 0.95;
    desktop      = 1.0;
  };

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

  cursor = {
    package = pkgs.apple-cursor;
    name = "macOS-White";
    size = 24;
  };
}
