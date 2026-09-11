# Stylix taban tema verisi — TEK kaynak.
# Hem NixOS modülü (system/desktop/theme.nix) hem standalone HM
# (lib/theme-standalone.nix) bunu tüketir.
# Modül DEĞİL, saf fonksiyon — target ayarları tüketicilerde.
{ pkgs }:

let
  # Aktif palet — "zixar-main" | "ergenekon" | "kanagawa-dragon" (değiştir + rebuild)
  # kanagawa-dragon: resmî base16 şeması (tinted-theming/base16-schemes'ten
  # birebir kopya). zixar-main'in pastel mavi/leylak/krem üçlüsü terminalde
  # (fastfetch dahil) bayrak-pasteli görüntü veriyordu; dragon desatüre,
  # toprak tonlu — miasma duvar kağıdı tarzıyla da uyumlu.
  palette = "kanagawa-dragon";

  # Palete eşlik eden duvar kağıdı (build-time türetmeler)
  wallpaper = {
    zixar-main = ./wallpapers/kanagawa.png;
    ergenekon = ./wallpapers/bonfire.png;
    kanagawa-dragon = ./wallpapers/kanagawa.png;
  };
in
{
  enable = true;
  polarity = "dark";

  # Saydamlık — TEK KAYNAK. Stylix bunu destekleyen hedeflere CSS opacity'si
  # olarak enjekte eder (terminal: ghostty; applications: zen-browser vb.).
  # Not: Stylix hedefi olmayan uygulamalar (steam vb.) CSS opacity'si ALMAZ;
  # onların saydamlığı varsa bileşkenden gelir, bu değerden değil. Eskiden burada
  # Hyprland'ın main.lua active_opacity'siyle ELLE senkron tutulur notu vardı —
  # o oturum Eylül 2026'da kalktı, senkron tutulacak ikinci yer artık YOK.
  opacity = {
    applications = 0.92;
    terminal     = 0.85; # ghostty biraz daha şeffaf
    popups       = 0.95;
    desktop      = 1.0;  # waybar/rofi/swaync matugen'de kendi alpha'sını yönetir
  };

  # Kişisel paletler — eski Caelestia şemalarından base16'ya çevrildi (schemes/).
  # DİKKAT: bu çevrim GERİ ALINAMAZ (110 anahtarın yalnız 16'sı taşınıyor; M3
  # container'ları, 12 kademeli surface rampası, parlak ANSI renkleri kayıp).
  # Not: 110-anahtarlı Caelestia .txt biçimi Eylül 2026'da ağaçtan çıktı; tek
  # kaynak artık buradaki base16 yaml'ları.
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

  # macOS oku, BEYAZ varyant (apple-cursor; kullanıcı isteği 2026-07-16 —
  # paket iki tema taşır: macOS ve macOS-White)
  cursor = {
    package = pkgs.apple-cursor;
    name = "macOS-White";
    size = 24;
  };
}
