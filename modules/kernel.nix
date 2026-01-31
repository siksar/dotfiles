{ config, pkgs, lib, ... }:
{
  boot = {
    # ========================================================================
    # KERNEL - Linux Zen (Optimized for Desktop/Gaming)
    # ========================================================================
    kernelPackages = pkgs.linuxPackages_zen;
    
    # ========================================================================
    # KERNEL PARAMETERS
    # ========================================================================
    kernelParams = [
      # Zen 5 / Strix Point Optimizations
      "amd_pstate=active"
      "amd_prefcore=enable" # Enable preferred core (Zen 5/5c scheduling)
      
      # Güç Optimizasyonu
      "workqueue.power_efficient=1"
      "pcie_aspm.policy=powersupersave"
      
      # NVMe Workarounds (Kingston OM8PGP4 Fixes)
      "nvme_core.default_ps_max_latency_us=0" # Disable APST (Fixes 0xc004 errors)
      "nvme_core.idle_timeout=255"             # Prevent aggressive idle suspend
      "nvme_core.shutdown_timeout=10"          # Prevent unsafe shutdowns
      "nvme_core.admin_timeout=10"
      "nvme_core.io_timeout=10"
      
      # VRAM / Memory Optimization (iGPU)
      "amdgpu.sg_display=0" # Reduce display flickering on some APUs
      
      # NVIDIA
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
      
      # Boot Speed & Quiet
      "quiet"
      "splash"
      "loglevel=3"
      "nowatchdog"          # Disable watchdog for faster boot/shutdown
      "modprobe.blacklist=iTCO_wdt" # Blacklist Intel watchdog on AMD
      
      # EC
      "ec_sys.write_support=1"
    ];
    
    # ========================================================================
    # KERNEL MODULES
    # ========================================================================
    kernelModules = [ "kvm-amd" "acpi_call" ];
    initrd.kernelModules = [ "amdgpu" "nvme" ]; # Ensure nvme loads early
    
    # Extra kernel modules for power management
    extraModulePackages = with config.boot.kernelPackages; [
      acpi_call  # ACPI call for power profile control (Gigabyte EC)
    ];
  };

  # ========================================================================
  # FALLBACK KERNEL (LTS)
  # ========================================================================
  specialisation = {
    lts-kernel.configuration = {
      system.nixos.tags = [ "lts" ];
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_6;
    };
  };

  # ========================================================================
  # CPU POWER MANAGEMENT
  # ========================================================================
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave";  # amd_pstate ile EPP kontrolü için optimal
    powertop.enable = true;         # PowerTop auto-tune
  };

  # ========================================================================
  # ZRAM SWAP
  # ========================================================================
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ========================================================================
  # HARDWARE & FIRMWARE
  # ========================================================================
  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
}
