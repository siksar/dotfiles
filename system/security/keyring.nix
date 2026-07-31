# gnome-keyring — Secret Service sağlayıcısı (Vesktop, Bitwarden, 1Password CLI
# gibi uygulamalar token'ı buraya yazar).
#
# GNOME kaldırıldıktan (30 Tem) sonra kalan GNOME parçalarından biri: masaüstünden
# bağımsız, D-Bus org.freedesktop.secrets adını sağlayan tek şey bu.
# Kilit açma girişte otomatik: nixpkgs'in ly modülü enableGnomeKeyring'i
# services.gnome.gnome-keyring.enable'dan mkDefault ile alıp PAM'e bağlıyor
# (bkz. system/desktop/login.nix).
{ ... }:

{
  services.gnome.gnome-keyring.enable = true;
}
