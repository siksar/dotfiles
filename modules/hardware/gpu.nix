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
    # #392/#966 + docs/aerox16-1vh-wmi.md). latest (610.43.03) DB regresyonunu düzeltiyor
    # mu diye bakılıyor. NOT: 595 (beta/production) daha eski, bilinen oyun-donma sorunları
    # (Tsushima, s2idle) — son çare. Geri pinlemek: mkDriver { version + hash }.
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
