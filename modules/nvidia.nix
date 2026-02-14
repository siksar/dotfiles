{ config, pkgs, ... }:

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

	# ========================================================================
	# KERNEL PARAMETERS - NVIDIA OPTIMIZATION
	# ========================================================================
	boot.kernelParams = [
		# Unlock Power Limits (Max-Q Optimization)
		# PowerMizer: Prefer Maximum Performance when plugged in
		"nvidia.NVreg_RegistryDwords=PowerMizerEnable=0x1;PerfLevelSrc=0x2222;PowerMizerLevel=0x3;PowerMizerDefault=0x3;PowerMizerDefaultAC=0x3;OverrideMaxPerf=0x1"
		"nvidia.NVreg_RestrictProfilingToAdminUsers=0"
		"iomem=relaxed"
	];
  
	# Load NVIDIA driver for Xorg and Wayland
	services.xserver.videoDrivers = [ "nvidia" ];
  
	hardware.nvidia = {
		# ====================================================================
		# DRIVER SETTINGS
		# ====================================================================
		# Modesetting is required for Wayland compositors (Hyprland, Niri)
		modesetting.enable = true;

		# Use the latest proprietary driver (Beta often needed for new HW like RTX 5060)
		package = config.boot.kernelPackages.nvidiaPackages.beta;

		# Blackwell (RTX 50) and newer require the open kernel modules
		open = true;

		# Enable nvidia-settings menu
		nvidiaSettings = true;
    
		# ====================================================================
		# POWER MANAGEMENT (Max-Q)
		# ====================================================================
		# Experimental power management for modern cards
		powerManagement.enable = true;
		
		# Fine-grained power management turns off the dGPU when not in use.
		# Critical for laptop battery life.
		powerManagement.finegrained = true;
    
		# Persistence Mode - Keeps driver loaded to avoid latency on app start
		nvidiaPersistenced = true;

		# Dynamic Boost - let the driver manage power balance between CPU/GPU
		dynamicBoost.enable = true;
    
		# ====================================================================
		# PRIME CONFIGURATION (Hybrid Graphics)
		# ====================================================================
		prime = {
			# Offload mode - dGPU remains sleep until explicitly requested
			# Usage: `nvidia-offload application` or `prime-run application`
			offload = {
				enable = true;
				enableOffloadCmd = true;
			};
      
			# Bus IDs (Verified for this specific laptop model)
			# AMD Radeon 860M (iGPU)
			amdgpuBusId = "PCI:101:0:0"; # Hex 65 -> Decimal 101
			
			# NVIDIA RTX 5060 (dGPU)
			nvidiaBusId = "PCI:100:0:0"; # Hex 64 -> Decimal 100
		};
	};
}
