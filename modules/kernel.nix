{ config, pkgs, lib, ... }:

{
  # ============================================================================
  # DEFAULT KERNEL - Ryzen-SMU (Zen Kernel)
  # ============================================================================
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # ============================================================================
  # KERNEL MODULES
  # ============================================================================
  boot.kernelModules = [
    "kvm-amd"
    "acpi_call"
    "amdxdna"
    "zram"
    "ryzen_smu"
    "msr"           # MSR erişimi - RyzenAdj için gerekli
  ];

  # ryzen_smu hardware option
  hardware.cpu.amd.ryzen-smu.enable = true;

  boot.initrd.kernelModules = [
    "amdgpu"
    "nvme"
    "zram"
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [
    acpi_call
    ryzen-smu
  ];

  # ============================================================================
  # KERNEL PARAMETERS
  # ============================================================================
  boot.kernelParams = [
    "amd_pstate=active"
    "amd_prefcore=enable"
    "amd_iommu=on"
    "iommu=pt"
    "processor.max_cstate=9"
    "pcie_aspm=powersave"
    "usbcore.autosuspend=-1"
    "nvme_core.default_ps_max_latency_us=0"
    "amdgpu.sg_display=0"
    "amdgpu.ppfeaturemask=0xffffffff" # AMD Overdrive/OC support
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "quiet"
    "splash"
    "loglevel=3"
    "nowatchdog"
    "nmi_watchdog=0"
    "amdxdna.enable=1"
  ];

  # ============================================================================
  # BLACKLIST
  # ============================================================================
  boot.blacklistedKernelModules = [
    "iTCO_wdt"
    "softdog"
    "intel_idle"
    "intel_pstate"
    "pcspkr"
  ];

  # ============================================================================
  # MODPROBE
  # ============================================================================
  boot.extraModprobeConfig = ''
    options amd_pstate mode=active
    options amdgpu dc=1 dpm=1
    options nvme default_ps_max_latency_us=0
    options zram num_devices=1
  '';

  # ============================================================================
  # RYZEN-MONITOR-NG (sadece bu kernel'de)
  # ============================================================================
  environment.systemPackages = [
    pkgs.ryzen-monitor-ng
  ];

  # ============================================================================
  # SPECIALISATION - Linux Latest (Fallback)
  # ============================================================================
  specialisation = {
    latest-kernel.configuration = {
      system.nixos.tags = [ "latest" ];
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;
      boot.kernelParams = lib.mkForce [
        "quiet"
        "amd_pstate=active"
        "nowatchdog"
      ];
      environment.systemPackages = lib.mkForce [];
    };
  };

  # ============================================================================
  # POWER & ZRAM
  # ============================================================================
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
    powertop.enable = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ============================================================================
  # SYSCTL
  # ============================================================================
  boot.kernel.sysctl = {
    "vm.swappiness" = 60;
    "vm.dirty_ratio" = 10;
    "vm.vfs_cache_pressure" = 50;
    "kernel.nmi_watchdog" = 0;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "fs.inotify.max_user_watches" = 524288;
  };

  # ============================================================================
  # HARDWARE
  # ============================================================================
 # hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
}
