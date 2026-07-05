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
    open           = true; # Blackwell dGPU open source driver modules
    nvidiaSettings = true;
    package        = config.boot.kernelPackages.nvidiaPackages.latest;
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
