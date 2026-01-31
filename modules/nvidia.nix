{ config, pkgs, ... }:
{
  # ========================================================================
  # GPU CONFIGURATION - AMD + NVIDIA PRIME
  # ========================================================================
  
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Unlock Nvidia Power Limits via Registry Dwords
  boot.kernelParams = [
    "nvidia.NVreg_RegistryDwords=PowerMizerEnable=0x1;PerfLevelSrc=0x2222;PowerMizerLevel=0x3;PowerMizerDefault=0x3;PowerMizerDefaultAC=0x3;OverrideMaxPerf=0x1"
    "iomem=relaxed"
    # pcie_aspm kaldırıldı - güç tasarrufu için default kullanılacak
    "nvidia.NVreg_RestrictProfilingToAdminUsers=0"
  ];
  
  services.xserver.deviceSection = ''
    Option "Coolbits" "28"
  '';

  services.xserver.videoDrivers = [ "nvidia" ];
  
  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;  # Beta for RTX 5060 support
    open = true;  # REQUIRED for RTX 50 series (Blackwell) - closed source NOT supported!
    nvidiaSettings = true;
    
    powerManagement.enable = true;
    powerManagement.finegrained = true;   # GPU kullanılmıyorken tamamen kapat (OFFLOAD mode)
    
    # Persistence Mode - Keeps driver loaded
    nvidiaPersistenced = true;

    # Dynamic Boost disabled
    dynamicBoost.enable = false;
    
    prime = {
      # Offload mode - dGPU sadece gerektiğinde aktif (büyük güç tasarrufu!)
      offload = {
        enable = true;
        enableOffloadCmd = true;  # nvidia-offload komutu ekler
      };
      
      # Bus IDs from lspci (hex 64 = decimal 100, hex 65 = decimal 101)
      amdgpuBusId = "PCI:101:0:0";
      nvidiaBusId = "PCI:100:0:0";
    };
  };
  
  # nvidia-powerd is started automatically when dynamicBoost is enabled
}
