# Kabuktan bağımsız ortak parçalar — hangi rice.shell seçili olursa olsun aktif.
# (caelestia/default.nix'ten taşındı; DMS/Noctalia da bunlara muhtaç)
{ inputs, lib, pkgs, ... }:

let
  # Hyprland için build-time fallback şema: hyprland/settings.nix her kabukta
  # ~/.config/hypr/scheme/current.conf'u source eder — dosya yoksa renk
  # değişkenleri ($primary vb.) patlar. everforest'ten üretilir; caelestia
  # runtime'da üstüne yazar, diğer kabuklarda son/fallback hali kalır.
  fallbackScheme = pkgs.runCommand "hypr-fallback-scheme.conf" { } ''
    sed 's/^\([A-Za-z_0-9]*\) \(.*\)$/$\1 = \2/' \
      ${inputs.caelestia-cli}/src/caelestia/data/schemes/everforest/medium/dark.txt > $out
  '';
in
{
  # Pano geçmişi — caelestia launcher'ı da DMS clipboard'u da cliphist okur
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Tema duvar kağıtları (recursive: kullanıcı dizine kendi dosyasını da atabilir)
  home.file."Pictures/Wallpapers" = {
    source = ../wallpapers;
    recursive = true;
  };

  # GTK/ikon tema paketleri — runtime tema motorlarının (caelestia dconf,
  # DMS matugen) referans verdiği temalar her kabukta kurulu olmalı
  home.packages = with pkgs; [
    adw-gtk3
    papirus-icon-theme
  ];

  # Hyprland şema fallback'i (yalnızca dosya yoksa)
  home.activation.hyprSchemeFallback = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.config/hypr/scheme/current.conf" ]; then
      run mkdir -p "$HOME/.config/hypr/scheme"
      run cp ${fallbackScheme} "$HOME/.config/hypr/scheme/current.conf"
      run chmod u+w "$HOME/.config/hypr/scheme/current.conf"
    fi
  '';
}
