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
  # Hyprland pencere saydamlığı (main.lua active_opacity) bu `applications`
  # değeriyle ELLE senkron tutulur → buzlu cam görünümü tüm sistemde tutarlı.
  # Not: steam/deezer gibi Stylix hedefi olmayan uygulamalar CSS opacity'si
  # ALMAZ; onların saydamlığı compositor'dan (Hyprland active_opacity + blur)
  # gelir — o yüzden yine de camsı görünürler, sadece renkleri kendilerinden.
  opacity = {
    applications = 0.92; # main.lua active_opacity ile senkron
    terminal     = 0.85; # ghostty biraz daha şeffaf
    popups       = 0.95;
    desktop      = 1.0;  # waybar/rofi/swaync matugen'de kendi alpha'sını yönetir
  };

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

  # macOS oku, BEYAZ varyant (apple-cursor; kullanıcı isteği 2026-07-16 —
  # paket iki tema taşır: macOS ve macOS-White)
  cursor = {
    package = pkgs.apple-cursor;
    name = "macOS-White";
    size = 24;
  };
}
