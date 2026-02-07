{ config, pkgs, lib, ... }:

let
  # Zen 5 specific optimizations
  zen5Optimizations = with lib.kernel; {
    # CPU scheduler
    SCHED_ALT = lib.mkForce no;  # Use CFS for better heterogeneous support
    SCHED_CORE = yes;            # Core scheduling for SMT

    # AMD P-State
    X86_AMD_PSTATE = module;
    X86_AMD_PSTATE_UT = no;      # Disable test module

    # CPPC (Collaborative Processor Performance Control)
    ACPI_CPPC_LIB = yes;
    ACPI_CPPC_CPUFREQ = module;

    # AMD 3D V-Cache (if applicable)
    AMD_3D_VCACHE = yes;

    # AMD Uncore
    AMD_NB = yes;
    AMD_FD_DMA = yes;
  };

in
{
  boot = {
    # =============================================================================
    # KERNEL - Linux Latest with Zen 5 Optimizations
    # =============================================================================

    # Linux Latest kernel - Best Zen 5 support
    kernelPackages = pkgs.linuxPackages_latest;

    # =============================================================================
    # RUST KERNEL SUPPORT (February 2026)
    # =============================================================================

    kernelPatches = [
      {
        name = "rust-support";
        patch = null;
        structuredExtraConfig = with lib.kernel; {
          # Rust support
          RUST = yes;
          RUST_DEBUG_ASSERTIONS = lib.mkDefault no;
          RUST_OVERFLOW_CHECKS = lib.mkDefault yes;
          RUST_OPT_LEVEL_SIMILAR_CC = yes;

          # Rust drivers (enable as they become available)
          DRM_ACCEL = yes;
        };
      }
      {
        name = "zen5-optimizations";
        patch = null;
        structuredExtraConfig = with lib.kernel; zen5Optimizations;
      }
    ];

    # =============================================================================
    # KERNEL PARAMETERS - Strix Point Optimizations
    # =============================================================================

    kernelParams = [
      # Zen 5 / Strix Point CPU
      "amd_pstate=active"           # Active P-State mode (best for Zen 5)
      "amd_prefcore=enable"         # Preferred core scheduling
      "amd_pstate.shared_mem=1"     # Shared memory for P-State

      # CPU Scheduler
      "sched_itmt_enabled=1"        # Intel Turbo Boost Max equivalent
      "sched_schedstats=0"          # Disable scheduler stats (performance)

      # Memory Management
      "transparent_hugepage=madvise"
      "vm.dirty_ratio=10"
      "vm.dirty_background_ratio=5"
      "vm.swappiness=60"
      "vm.vfs_cache_pressure=50"
      "vm.page-cluster=3"

      # Power Management
      "processor.max_cstate=9"      # Maximum C-state
      "amd_iommu=on"                # IOMMU for NPU and virtualization
      "iommu=pt"                    # Passthrough mode
      "pcie_aspm=powersave"         # PCIe power saving
      "pcie_aspm.policy=powersupersave"

      # USB
      "usbcore.autosuspend=-1"      # Disable USB autosuspend (fix mouse issues)
      "usbcore.use_both_schemes=1"  # Better USB device detection

      # NVMe Optimizations (Kingston OM8PGP4)
      "nvme_core.default_ps_max_latency_us=0"  # Disable APST
      "nvme_core.io_timeout=30"
      "nvme_core.admin_timeout=30"
      "nvme_core.shutdown_timeout=10"
      "nvme_core.max_retries=5"

      # AMDGPU (iGPU)
      "amdgpu.sg_display=0"         # Fix display flickering
      "amdgpu.dc=1"                 # Display Core
      "amdgpu.dpm=1"                # Dynamic Power Management
      "amdgpu.runpm=1"              # Runtime PM
      "amdgpu.noretry=0"            # Enable retries

      # NVIDIA (dGPU)
      "nvidia-drm.modeset=1"
      "nvidia-drm.fbdev=1"
      "nvidia.NVreg_UsePageAttributeTable=1"
      "nvidia.NVreg_EnablePCIeGen3=1"
      "nvidia.NVreg_RegistryDwords=RMReqstVsyncRate=0x0;RMDisableGpuAS=0x0"

      # Boot Speed
      "quiet"
      "splash"
      "loglevel=3"
      "rd.systemd.show_status=auto"
      "rd.udev.log_level=3"

      # Disable watchdogs
      "nowatchdog"
      "nmi_watchdog=0"
      "soft_watchdog=0"
      "modprobe.blacklist=iTCO_wdt,softdog"

      # Security (performance trade-offs)
      "mitigations=auto"            # Keep mitigations for safety
      "spectre_v2=auto"
      "spec_store_bypass_disable=auto"

      # EC (Embedded Controller)
      "ec_sys.write_support=1"

      # ZRAM
      "zram.num_devices=1"

      # Timer
      "tsc=reliable"
      "clocksource=tsc"

      # Random
      "random.trust_cpu=on"

      # Hugepages for NPU/AI
      "default_hugepagesz=1G"
      "hugepagesz=1G"
      "hugepages=4"
      "hugepagesz=2M"
      "hugepages=1024"
    ];

    # =============================================================================
    # KERNEL MODULES
    # =============================================================================

    kernelModules = [
      "kvm-amd"           # AMD KVM
      "acpi_call"         # ACPI calls
      "amdxdna"           # AMD XDNA NPU
      "accel"             # Accelerator framework
      "zram"              # ZRAM
      "lz4"               # LZ4 compression
      "zstd"              # ZSTD compression
    ];

    initrd.kernelModules = [
      "amdgpu"            # Early GPU
      "nvme"              # Early NVMe
      "zram"              # Early ZRAM
      "amdxdna"           # Early NPU
      "accel"             # Early accelerator
    ];

    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "thunderbolt"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];

    # Extra kernel modules
    extraModulePackages = with config.boot.kernelPackages; [
      acpi_call           # ACPI power control
      # v4l2loopback      # Virtual camera (if needed)
    ];

    # =============================================================================
    # BLACKLIST - Problematic modules
    # =============================================================================

    blacklistedKernelModules = [
      # Watchdogs
      "iTCO_wdt"
      "iTCO_vendor_support"
      "softdog"

      # Intel modules (not needed on AMD)
      "intel_idle"
      "intel_pstate"
      "intel_rapl"

      # Problematic sensors
      "sp5100_tco"

      # Unused network protocols
      "nf_conntrack_helper"

      # Power saving that causes issues
      "pcspkr"
    ];

    # =============================================================================
    # EXTRA MODPROBE CONFIG
    # =============================================================================

    extraModprobeConfig = ''
      # AMD P-State options
      options amd_pstate mode=active
      options amd_pstate shared_mem=1

      # AMDGPU options
      options amdgpu si_support=1
      options amdgpu cik_support=1
      options amdgpu dc=1
      options amdgpu dpm=1
      options amdgpu runpm=1
      options amdgpu noretry=0
      options amdgpu lockup_timeout=0
      options amdgpu sched_jobs=32
      options amdgpu sched_hw_submission=4

      # NVMe options
      options nvme default_ps_max_latency_us=0
      options nvme io_timeout=30000

      # ZRAM options
      options zram num_devices=1

      # AMD XDNA NPU
      options amdxdna dyndbg=\+p

      # KVM optimizations
      options kvm-amd nested=1
      options kvm ignore_msrs=1
      options kvm report_ignored_msrs=0

      # Thunderbolt
      options thunderbolt ignore_native=0

      # USB autosuspend
      options usbcore autosuspend=-1

      # Disable PC speaker
      options snd-pcsp index=2
      options pcspkr index=2
    '';

    # =============================================================================
    # INITRD CONFIGURATION
    # =============================================================================

    initrd.systemd.enable = true;

    # Compress initrd with zstd for speed
    initrd.compressor = "zstd";
    initrd.compressorArgs = [ "-19" "-T0" ];
  };

  # =============================================================================
  # FALLBACK KERNELS
  # =============================================================================

  specialisation = {
    # Zen kernel - Gaming optimized
    zen-kernel.configuration = {
      system.nixos.tags = [ "zen" ];
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_zen;
      boot.kernelPatches = lib.mkForce [];
      boot.kernelParams = lib.mkForce [
        "quiet"
        "splash"
        "amd_pstate=active"
        "mitigations=off"
        "nowatchdog"
        "nmi_watchdog=0"
      ];
    };

    # Xanmod kernel - Low latency
    xanmod-kernel.configuration = {
      system.nixos.tags = [ "xanmod" ];
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_xanmod_latest;
      boot.kernelPatches = lib.mkForce [];
    };

    # LTS kernel - Maximum stability
    lts-kernel.configuration = {
      system.nixos.tags = [ "lts" ];
      boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;
      boot.kernelPatches = lib.mkForce [];
    };
  };

  # =============================================================================
  # POWER MANAGEMENT
  # =============================================================================

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";  # Best for amd_pstate
    powertop.enable = true;
  };

  # =============================================================================
  # ZRAM SWAP
  # =============================================================================

  zramSwap = {
    enable = true;
    algorithm = "zstd";        # Best compression/speed ratio
    memoryPercent = 50;        # 50% of RAM
    priority = 100;            # Higher than disk swap
    swapDevices = 1;
  };

  # =============================================================================
  # KERNEL SYSCTL - Runtime optimizations
  # =============================================================================

  boot.kernel.sysctl = {
    # VM
    "vm.swappiness" = 60;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
    "vm.page-cluster" = 3;
    "vm.stat_interval" = 10;
    "vm.overcommit_memory" = 0;
    "vm.overcommit_ratio" = 50;
    "vm.compaction_proactiveness" = 20;
    "vm.min_free_kbytes" = 65536;

    # Kernel
    "kernel.nmi_watchdog" = 0;
    "kernel.soft_watchdog" = 0;
    "kernel.watchdog" = 0;
    "kernel.sched_migration_cost_ns" = 500000;
    "kernel.sched_nr_migrate" = 32;
    "kernel.sched_latency_ns" = 10000000;
    "kernel.sched_min_granularity_ns" = 1250000;
    "kernel.sched_wakeup_granularity_ns" = 1500000;
    "kernel.sched_cfs_bandwidth_slice_us" = 5000;
    "kernel.sched_rt_period_us" = 1000000;
    "kernel.sched_rt_runtime_us" = 950000;
    "kernel.sched_energy_aware" = 1;           # Enable for heterogeneous cores
    "kernel.sched_pelt_multiplier" = 2;
    "kernel.unprivileged_userns_clone" = 1;
    "kernel.keys.maxkeys" = 2000;
    "kernel.keys.maxbytes" = 2000000;
    "kernel.msgmax" = 65536;
    "kernel.msgmnb" = 65536;
    "kernel.pid_max" = 4194304;

    # Network
    "net.core.netdev_max_backlog" = 65536;
    "net.core.somaxconn" = 65536;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_notsent_lowat" = 16384;
    "net.ipv4.tcp_fastopen" = 3;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    # FS
    "fs.file-max" = 2097152;
    "fs.inotify.max_user_watches" = 524288;
    "fs.inotify.max_user_instances" = 8192;
    "fs.aio-max-nr" = 1048576;

    # Dev
    "dev.raid.speed_limit_min" = 10000;
    "dev.raid.speed_limit_max" = 200000;
  };

  # =============================================================================
  # HARDWARE
  # =============================================================================

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # Firmware compression for faster boot
  hardware.firmware = lib.mkBefore [
    (pkgs.runCommand "firmware-compressed" {} ''
      mkdir -p $out/lib/firmware
      # Firmware will be loaded from linux-firmware
    '')
  ];
}
