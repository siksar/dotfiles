# Sanallaştırma — şu an tek tüketicisi Claude Desktop'ın "Cowork" VM sandbox'ı.
# Resmî gereksinim listesi: qemu + OVMF (qemu_kvm ile gelir) + virtiofsd
# (host↔misafir paylaşımlı dizin). Kullanıcı `kvm` grubunda olmazsa /dev/kvm'e
# erişemez ve sandbox yazılım emülasyonuna düşer (kullanılamayacak kadar yavaş).
#
# Boşta maliyet YOK: libvirtd/virtlogd gibi kalıcı daemon açılmıyor, yalnız
# paketler + grup üyeliği. VM sadece Cowork onu başlattığında koşar.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    qemu_kvm
    virtiofsd
  ];

  users.users.zixar.extraGroups = [ "kvm" ];
}
