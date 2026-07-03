# Masaüstü uygulamaları (system)
{ pkgs, ... }:

{
  # Steam (32-bit GL/Vulkan dahil)
  programs.steam.enable = true;

  # Mullvad VPN (GUI dahil)
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  environment.systemPackages = with pkgs; [
    # Netflix: Widevine'lı Chrome app-mode sarmalayıcısı (google-chrome getirir)
    netflix

    # Claude Desktop Cowork VM sandbox'ı (resmî gereksinim: qemu + OVMF + virtiofsd)
    qemu_kvm
    virtiofsd
  ];

  # Vesktop/Bitwarden token saklama (Secret Service)
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Cowork için KVM erişimi
  users.users.zixar.extraGroups = [ "kvm" ];
}
