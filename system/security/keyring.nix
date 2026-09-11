# gnome-keyring — Secret Service sağlayıcısı (Vesktop, Bitwarden, 1Password CLI
# gibi uygulamalar token'ı buraya yazar).
#
# GNOME kaldırıldıktan (30 Tem) sonra kalan GNOME parçalarından biri: masaüstünden
# bağımsız, D-Bus org.freedesktop.secrets adını sağlayan tek şey bu.
# Kilit açma girişte otomatik ve GREETER'DAN BAĞIMSIZ. Zincir greeter'ın değil,
# gnome-keyring modülünün kendisi:
# services/desktops/gnome/gnome-keyring.nix `security.pam.services.login
# .enableGnomeKeyring = true` diyor; her greeter'ın PAM servisi de `login`'i
# include/substack ediyor). Yani greeter değişikliği
# pam_gnome_keyring zincirini KIRMAZ; bu dosyada değişecek bir şey yok.
{ ... }:

{
  services.gnome.gnome-keyring.enable = true;
}
