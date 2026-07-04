# Stylix — taban tema katmanı (system)
# Renklerin asıl runtime motoru Caelestia CLI'dır (anlık şema geçişi);
# Stylix burada font, imleç ve build-time varsayılan renkleri sağlar.
{ pkgs, ... }:

{
  stylix = {
    enable = true;
    polarity = "dark";

    # Everforest — Caelestia'nın varsayılan şemasıyla (everforest/medium/dark) uyumlu
    base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest-dark-medium.yaml";

    # Varsayılan duvar kağıdı (Caelestia shell çizer; stylix build-time türetmeler için kullanır)
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

    # Özel Miasma limine teması korunur (modules/boot/limine.nix ile çakışmasın)
    targets.limine.enable = false;
    # Plymouth kullanılmıyor (boot optimizasyonunda kaldırıldı)
    targets.plymouth.enable = false;
  };
}
