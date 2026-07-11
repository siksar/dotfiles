# Stylix çakışma güvenlik duvarı (home-manager)
# Runtime tema motorları (Caelestia CLI, DMS matugen, Noctalia şablonları)
# bu hedeflerin config dosyalarını RUNTIME'da kendileri yazar. Stylix/HM aynı
# dosyaları yönetirse symlink çakışması ve çifte tema kaynağı oluşur — bu
# yüzden ÜÇ kabukta da kapalılar (rice.shell'den bağımsız, koşulsuz).
{ ... }:

{
  stylix.targets = {
    gtk.enable = false;       # caelestia: gtk-{3,4}.0/gtk.css + dconf
    hyprland.enable = false;  # renkler hypr/scheme/current.conf'tan canlı gelir
    hyprlock.enable = false;  # kilit ekranı Caelestia shell'in içinde
    hyprpaper.enable = false; # duvar kağıdını shell kendisi çizer
    ghostty.enable = false;   # terminal renkleri OSC dizileriyle canlı
    btop.enable = false;      # caelestia: btop/themes/caelestia.theme
    vesktop.enable = false;   # caelestia: vesktop tema CSS'i
    vencord.enable = false;
    fuzzel.enable = false;    # caelestia fuzzel.ini'yi komple yazar
    waybar.enable = false;    # Faz 2'de waybar tamamen kalkıyor
    starship.enable = false;  # prompt ANSI renk kullanır (shell.nix) — OSC ile canlı uyar
  };
}
