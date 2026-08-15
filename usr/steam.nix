# Steam + Proton — sistem geneli oyun çalıştırma katmanı.
# Perf altyapısı system/kernel/sched.nix'te (scx_lavd/gamemode/ntsync/zram),
# kullanıcı tarafı home/apps/games.nix'te (home.packages üzerinden PATH'e ekler).
# gamerun'ın tanımı lib/gamerun.nix'te — iki tarafça ortak import edilir.
# Kullanım / launch options tablosu: Documentation/gaming.md
{ pkgs, inputs, ... }:

{
  # Steam (32-bit GL/Vulkan dahil)
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
    # gamerun'u Steam'in KENDİ FHS/pressure-vessel kum havuzuna koyar (10 Ağu
    # 2026 — bkz. lib/gamerun.nix dosya başlığı). extraPackages, nixpkgs'in
    # steam modülünde extraPkgs'e geçer → kum havuzunda /usr/bin/gamerun oluşur.
    # BUNSUZ launch options'taki "gamerun %command%" "command not found" verir
    # (kum havuzunun PATH'i yalnız /usr/bin:/bin, HM profili dışarıda kalır).
    extraPackages = [ (import ../lib/gamerun.nix { inherit pkgs; }) ];
  };

  # Proton-CachyOS binary cache (chaotic-nyx, kendi nixConfig'inden doğrulanan değerler) —
  # kaynaktan derlemeyi önler. usr/local-ai.nix'teki nix-amd-ai cachix deseniyle aynı
  # (nix.settings.substituters/trusted-public-keys listeleri NixOS'ta birleşir).
  nix.settings = {
    substituters = [ "https://nyx-cache.chaotic.cx/" ];
    trusted-public-keys = [ "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=" ];
  };
}
