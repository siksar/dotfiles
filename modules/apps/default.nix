# Masaüstü uygulamaları (system)
{ pkgs, ... }:

{
  # Steam (32-bit GL/Vulkan dahil) — perf altyapısı: modules/hardware/gaming.nix,
  # kullanım: docs/gaming.md (launch options: gamerun %command%)
  programs.steam = {
    enable = true;
    # GE-Proton: ntsync varsayılan açık + güncel dxvk-nvapi (DLSS 4.5 override)
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    protontricks.enable = true;
  };

  # Mullvad VPN (GUI dahil)
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };

  # LocalSend — yerel ağda dosya paylaşımı (firewall 53317'yi kendisi açar)
  programs.localsend = {
    enable = true;
    openFirewall = true;
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
  security.pam.services.sddm.enableGnomeKeyring = true; # girişte keyring kilidi açılır

  # Cowork için KVM erişimi
  users.users.zixar.extraGroups = [ "kvm" ];
}
