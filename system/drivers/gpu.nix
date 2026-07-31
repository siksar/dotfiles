# Hibrit grafik: AMD 860M iGPU (amdgpu) + NVIDIA RTX 5060 Max-Q (PRIME offload).
# dGPU boştayken D3cold'da uyur; oyunlar gamerun ile offload eder (home/apps/games.nix).
{ config, pkgs, ... }:

{
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];

  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open           = true; # Blackwell dGPU open source driver modules (zorunlu)
    nvidiaSettings = true;
    # Sürücü: nvidiaPackages.latest (şu an 610.43.03). 2026-07-18'de 610.43.02
    # pininden latest'e alındı — TEST: pinli 610.43.02'de nvidia-powerd Dynamic Boost'u
    # bu AMD+NVIDIA makinede kuramıyor, GPU 30W tabanda kilitli (enforced 30W < 50W
    # varsayılan; profil/PPD/TLP ölçümle elendi; bkz. NVIDIA open-gpu-kernel-modules
    # #392/#966 + Documentation/aerox16/wmi-ec.md). SONUÇ (31 Tem 2026): sürüm avcılığı gereksizmiş —
    # nvidia-powerd canlıda sağlıklı (D-Bus bağlı, çökmüyor); tek yinelenen log satırı
    # "SBIOS disable Dynamic Boost DC controller" (DC=pil; bu repo boost'u zaten yalnız
    # AC'ye kilitlemiş, muhtemelen zararsız). Gerçek kanıt versiyon değil ÖLÇÜM: ACBT WMI
    # yazımı (0x4C)→nvidia-powerd okuma→GPU tavanı zinciri KCD'de 38W→70-83W ölçüldü
    # (gaming-performance-project belleği). #392 (AMD CPU'da DB, NVIDIA'da 2022'den beri
    # açık/kabul edilmiş genel sınırlama) bu yüzden ilgisiz — kazanç o jenerik mekanizmadan
    # değil WMI yan-kanalından geliyor. NOT: 595 (beta/production) daha eski, bilinen
    # oyun-donma sorunları (Tsushima, s2idle) — son çare. Geri pinlemek: mkDriver { version + hash }.
    package = config.boot.kernelPackages.nvidiaPackages.latest;
    # nvidia-powerd: NPCF.ACBT bütçesini okuyup GPU tavanını 50W→75W+'a
    # çıkarır (Dynamic Boost). ACBT'yi gigabyte-power-profile yazar (0x4C).
    dynamicBoost.enable = true;
    powerManagement = {
      enable      = true;
      finegrained = true;
    };
    prime = {
      offload = {
        enable          = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:100:0:0";
      amdgpuBusId = "PCI:101:0:0";
    };
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER      = "radeonsi";
  };

  environment.systemPackages = with pkgs; [
    libva-utils
    vdpauinfo
  ];
}
