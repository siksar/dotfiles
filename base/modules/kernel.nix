{ config, pkgs, lib, ... }:

{
	# ========================================================================
	# KERNEL PACKAGES - Linux 6.18
	# ========================================================================
	# NVIDIA production driver (580.x) henüz 6.19'u desteklemiyor.
	# zone_device_page_init API değişikliği build kırıyor.
	boot.kernelPackages = pkgs.linuxPackages_6_18;

	# ========================================================================
	# KERNEL MODULES
	# ========================================================================
	boot.kernelModules = [ 
		"kvm-amd"
		"acpi_call"
		"amdxdna"          # NPU support
		"amd-pmf"          # Platform Management Framework
		"gigabyte-wmi"     # Gigabyte sensor/WMI support
		"zram"
	];

	# Essential modules for early boot
	boot.initrd.kernelModules = [ 
		"amdgpu"
		"nvme"
		"zram"
	];

	# Extra module packages
	boot.extraModulePackages = with config.boot.kernelPackages; [ 
		acpi_call
	];

	# ========================================================================
	# KERNEL PARAMETERS - Performance & Compatibility
	# ========================================================================
	boot.kernelParams = [
		# CPU Power & Scheduling (amd-pstate-epp is default in recent kernels)
		"amd_pstate=active"
		"amd_prefcore=enable"

		# Hardware Support
		"amd_iommu=on"
		"iommu=pt"
		"amdxdna.enable=1"                  # Enable NPU

		# Graphics & Display (Hybrid Graphics: AMD + NVIDIA)
		"amdgpu.sg_display=0"               # Fixes some flickering on iGPU
		"amdgpu.ppfeaturemask=0xffffffff"   # Unlock full GPU features
		"amdgpu.gttsize=12288"              # Allow up to 12GB system RAM for VRAM (Fix 512MB limit)
		"nvidia-drm.modeset=1"              # REQUIRED for Wayland on NVIDIA
		"nvidia-drm.fbdev=1"                # Framebuffer device for high-res console

		# Power Saving Latency Optimization
		"nvme_core.default_ps_max_latency_us=0"
		"pcie_aspm=powersave"
		"usbcore.autosuspend=-1"            # Prevent USB device disconnects

		# System Stability & Debugging
		"quiet"
		"splash"
		"loglevel=3"
		"nowatchdog"
		"nmi_watchdog=0"
	];

	# ========================================================================
	# BLACKLIST - Remove Unwanted Modules
	# ========================================================================
	boot.blacklistedKernelModules = [ 
		"iTCO_wdt"
		"softdog"
		"intel_idle"       # AMD CPU -> No Intel Idle needed
		"intel_pstate"     # AMD CPU -> No Intel P-State needed
		"pcspkr"           # Silence PC speaker beep
		"nouveau"          # Blacklist open-source NVIDIA to prevent conflicts
		"asus-wmi"         # Prevent conflict with AMD PMF on Gigabyte laptops
		"asus_wmi"
	];

	# ========================================================================
	# MODPROBE CONFIGURATION
	# ========================================================================
	boot.extraModprobeConfig = ''
		options amd_pstate mode=active
		options amdgpu dc=1 dpm=1
		options nvme default_ps_max_latency_us=0
		options zram num_devices=1
		install asus-wmi /bin/false
		install asus_wmi /bin/false
	'';

	# ========================================================================
	# SYSTEM PACKAGES - Kernel Specific
	# ========================================================================
	environment.systemPackages = with pkgs; [
		# Essential tools for monitoring kernel performance
		config.boot.kernelPackages.cpupower
		lm_sensors
		powertop
		nvtopPackages.full    # GPU monitoring
	];

	# ========================================================================
	# POWER MANAGEMENT & ZRAM
	# ========================================================================
	powerManagement = {
		enable = true;
		cpuFreqGovernor = "performance";  # Default to performance, allow userspace tools to manage
		powertop.enable = false;          # Disable auto-tune to avoid conflicts with custom scripts
	};

	zramSwap = {
		enable = true;
		algorithm = "zstd";
		memoryPercent = 50;
	};

	# ========================================================================
	# SYSCTL TUNING - Throughput & Latency
	# ========================================================================
	boot.kernel.sysctl = {
		# Virtual Memory
		"vm.swappiness" = 10;             # Reduce swap usage (32GB RAM is plenty)
		"vm.dirty_ratio" = 10;
		"vm.dirty_background_ratio" = 5;
		"vm.vfs_cache_pressure" = 50;

		# Networking (BBR Congestion Control)
		"net.core.default_qdisc" = "cake";
		"net.ipv4.tcp_congestion_control" = "bbr";

		# Watchdog
		"kernel.nmi_watchdog" = 0;

		# Filesystem Monitoring
		"fs.inotify.max_user_watches" = 524288;
	};

	# ========================================================================
	# FIRMWARE
	# ========================================================================
	hardware.enableRedistributableFirmware = true;
	hardware.enableAllFirmware = true;
	hardware.cpu.amd.updateMicrocode = true;
}
