{ config, pkgs, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta; 
    open = true; # AI ve yeni kartlar için open module iyidir
    nvidiaSettings = true;
    
    powerManagement = {
      enable = true;
      finegrained = true; # Pil tasarrufu
    };

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      # Senin önceki configdeki ID'ler (lspci ile kontrol etmen gerekebilir)
      amdgpuBusId = "PCI:101:0:0"; 
      nvidiaBusId = "PCI:100:0:0"; 
    };
  };
  
  # Nvidia için gerekli kernel parametreleri
  boot.kernelParams = [ "nvidia-drm.modeset=1" "NVreg_DynamicBoostSupport=1" ];
}
