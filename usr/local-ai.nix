# Yerel AI yığını — NPU öncelikli (kullanıcı isteği: dGPU değil NPU)
# - FastFlowLM: LLM'ler XDNA2 NPU'da (Ryzen AI 7 350, ~50 TOPS)
# - Lemonade: OpenAI-uyumlu API (http://localhost:13305/api/v1) + web UI
# - Vulkan backend: NPU'ya sığmayan modeller için iGPU (Radeon 860M) yolu
# - ROCm kapalı: gfx1152 (Krackan) desteği belirsiz; Vulkan hem destekli hem
#   üst modül sahibinin ölçümlerinde gfx115x'te daha hızlı
{ inputs, lib, ... }:

{
  imports = [ inputs.nix-amd-ai.nixosModules.default ];

  # Önceden derlenmiş paketler (XRT, FastFlowLM, Lemonade, llama.cpp-vulkan)
  nix.settings = {
    substituters = [ "https://nix-amd-ai.cachix.org" ];
    trusted-public-keys = [
      "nix-amd-ai.cachix.org-1:F4OU4vw/lV2oiG6SBHZ+nqjl4EFJuqI4X9A7pvaBmhQ="
    ];
  };

  hardware.amd-npu = {
    enable = true;
    enableNPU = true; # amdxdna + XRT + udev + memlock
    enableFastFlowLM = true; # NPU'da LLM (flm CLI)
    enableLemonade = true; # lemond servisi (OpenAI-uyumlu API)
    enableVulkan = true; # iGPU fallback (llama.cpp + whisper.cpp)
    enableROCm = false;
    lemonade.user = "zixar";

    # iGPU dinamik bellek tavanı: varsayılan ~15.6 GiB (RAM/2) → 24 GiB.
    # Bu bir ÜST SINIR (rezervasyon değil) — sadece model yüklüyken kullanılır.
    # BIOS'taki 512MB UMA carve-out'a dokunmaya gerek yok; APU'da GTT aynı hızda.
    gpuMemory.ttmSizeGiB = 24;
  };

  # NPU (/dev/accel) ve iGPU erişimi
  users.users.zixar.extraGroups = [ "video" "render" ];

  # lemond boot'ta OTOMATİK BAŞLAMASIN — elle başlatılan servis.
  # Upstream (amd-npu.nix) wantedBy=multi-user.target veriyor; mkForce ile
  # o bağı koparıyoruz (gaming.nix'teki game-perf.service ile aynı desen).
  # Unit tanımı ve `systemctl start lemond` yeteneği KALIR; sadece açılışta
  # tetiklenmez. Neden:
  #  - idle güç: sürekli açık lemond ~137 task tutuyor, 4.28W tabanı riske atar
  #  - shutdown: lemond kapanışta SIGINT'ten sonra ~4-6 sn takılıyor ve
  #    network-online.target'a bağlı olduğu için tüm kapanışı geciktiriyordu;
  #    çalışmıyorsa bu vergi hiç oluşmaz.
  # Kullanım: AI'a ihtiyaç olunca `systemctl start lemond`, iş bitince `stop`.
  systemd.services.lemond.wantedBy = lib.mkForce [ ];
}
