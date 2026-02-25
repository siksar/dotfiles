{ config, pkgs, lib, ... }:

{
	# ========================================================================
	# GPU CONFIGURATION - AMD Ryzen AI 7 + NVIDIA RTX 5060 Max-Q
	# ========================================================================
	# Optimized for Hybrid Graphics (Prime Offloading)
	# iGPU (Radeon 860M) handles display, dGPU (RTX 5060) handles heavy loads.

	hardware.graphics = {
		enable = true;
		enable32Bit = true;
	};

	boot.kernelParams = [
		"nvidia.NVreg_RegistryDwords=PowerMizerEnable=0x1;PerfLevelSrc=0x2222;PowerMizerLevel=0x3;PowerMizerDefault=0x3;PowerMizerDefaultAC=0x3;OverrideMaxPerf=0x1"
		"nvidia.NVreg_RestrictProfilingToAdminUsers=0"
		"iomem=relaxed"
	];
  
	services.xserver.videoDrivers = [ "nvidia" ];
  
	hardware.nvidia = {
		modesetting.enable = true;

		# RTX 5060 (Blackwell) - stable driver
		package = config.boot.kernelPackages.nvidiaPackages.stable;

		# Blackwell (RTX 50) and newer work better with GSP, 
		# but open modules can sometimes fail to build on very new kernels.
		open = false;
		nvidiaSettings = true;
		powerManagement.enable = true;
		powerManagement.finegrained = true;
		nvidiaPersistenced = true;
		dynamicBoost.enable = false;

		prime = {
			offload = {
				enable = true;
				enableOffloadCmd = true;
			};
			amdgpuBusId = "PCI:101:0:0";
			nvidiaBusId = "PCI:100:0:0";
		};
	};
}
