{ config, pkgs, lib, ... }:
{
  boot = {
    # ════════════════════════════════════════════════════════════════
    # KERNEL SEÇİMİ - XanMod (Gaming/Performance optimized)
    # ════════════════════════════════════════════════════════════════
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    # ════════════════════════════════════════════════════════════════
    # KERNEL PARAMETERS - Zen 4 Optimizasyonları
    # ════════════════════════════════════════════════════════════════
    kernelParams = [
      # AMD P-State EPP (Energy Performance Preference)
      "amd_pstate=active"
      "amd_pstate_epp=performance"
      
      # IOMMU (NPU ve GPU için gerekli)
      "iommu=pt"
      "amd_iommu=on"
      
      # Bellek optimizasyonları
      "transparent_hugepage=madvise"
      "mitigations=off"  # Performans için (güvenlik riskleri var!)
      
      # Preemption (düşük latency)
      "preempt=full"
      
      # Timer frekansı
      "clocksource=tsc"
      "tsc=reliable"
      
      # Watchdog devre dışı (enerji tasarrufu)
      "nowatchdog"
      "nmi_watchdog=0"
      
      # Split lock (Zen 4 için önemli)
      "split_lock_detect=off"
      
      # NVIDIA (senin gpu.nix'teki)
      "nvidia-drm.modeset=1"
    ];
    # ════════════════════════════════════════════════════════════════
    # KERNEL SYSCTL - Performans Tuning
    # ════════════════════════════════════════════════════════════════
    kernel.sysctl = {
      # VM Tuning
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
      "vm.dirty_ratio" = 10;
      "vm.dirty_background_ratio" = 5;
      "vm.page-cluster" = 0;
      
      # Network Tuning
      "net.core.netdev_max_backlog" = 16384;
      "net.core.somaxconn" = 8192;
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_congestion_control" = "bbr";
      
      # Scheduler Tuning
      "kernel.sched_autogroup_enabled" = 1;
      "kernel.sched_cfs_bandwidth_slice_us" = 3000;
    };
    # ════════════════════════════════════════════════════════════════
    # KERNEL MODÜLLER
    # ════════════════════════════════════════════════════════════════
    kernelModules = [
      "amd_pstate"       # AMD P-State driver
      "kvm-amd"          # AMD virtualization
      "amdgpu"           # AMD GPU
      "zenpower"         # AMD Zen power monitoring (opsiyonel)
    ];
    # Erken yüklenecek modüller
    initrd.kernelModules = [
      "amdgpu"
    ];
  };
  # ════════════════════════════════════════════════════════════════
  # AMD P-STATE CPU GOVERNOR
  # ════════════════════════════════════════════════════════════════
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "performance";  # veya "schedutil"
  };
  # ════════════════════════════════════════════════════════════════
  # ZRAM (Swap sıkıştırma - RAM verimliliği)
  # ════════════════════════════════════════════════════════════════
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  # ════════════════════════════════════════════════════════════════
  # HARDWARE SENSÖRLERI
  # ════════════════════════════════════════════════════════════════
  hardware.cpu.amd.updateMicrocode = true;
}
