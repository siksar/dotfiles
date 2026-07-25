# Masaüstü uygulamaları (system)
{ pkgs, inputs, ... }:

{
  # Steam (32-bit GL/Vulkan dahil) — perf altyapısı: modules/hardware/gaming.nix,
  # kullanım: docs/gaming.md (launch options: gamerun %command%)
  programs.steam = {
    enable = true;
    # Proton seçenekleri (Steam'de oyun-başına seçilir → Özellikler → Uyumluluk):
    #  • proton-ge-bin  — VARSAYILAN: ntsync açık + güncel dxvk-nvapi (DLSS 4.5 override)
    #  • proton-cachyos — Blackwell-sertleştirilmiş: VK_EXT_descriptor_heap (Xid 109 sert
    #    çökme fix, vkd3d-proton #2914) + DX12 donma (#2793) en iyi burada test edilmiş.
    #    İnatçı DX12/Blackwell oyunlarında bu Proton'u seç + GR_HEAP=1 (PROTON_VKD3D_HEAP=1).
    extraCompatPackages = [
      pkgs.proton-ge-bin
      inputs.chaotic.packages.${pkgs.stdenv.hostPlatform.system}.proton-cachyos
    ];
    protontricks.enable = true;
  };

  # Proton-CachyOS binary cache (chaotic-nyx, kendi nixConfig'inden doğrulanan değerler) —
  # kaynaktan derlemeyi önler. local-ai.nix'teki nix-amd-ai cachix deseniyle aynı
  # (nix.settings.substituters/trusted-public-keys listeleri NixOS'ta birleşir).
  nix.settings = {
    substituters = [ "https://nyx-cache.chaotic.cx/" ];
    trusted-public-keys = [ "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=" ];
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
  security.pam.services.gdm-password.enableGnomeKeyring = true; # girişte keyring kilidi açılır

  # Cowork için KVM erişimi
  users.users.zixar.extraGroups = [ "kvm" ];
}
