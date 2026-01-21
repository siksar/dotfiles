{
  # ════════════════════════════════════════════════════════════════
  # AUDIO PRODUCTION TUNING (FL Studio için)
  # ════════════════════════════════════════════════════════════════
  
  # Kernel parametreleri (kernel.nix'e ekle)
  boot.kernelParams = [
    # ... mevcut parametrelerin
    "threadirqs"  # Audio latency için
  ];

  # Sysctl tuning
  boot.kernel.sysctl = {
    # ... mevcut ayarların
    "vm.swappiness" = 10;
    "kernel.sched_rt_runtime_us" = -1;  # Realtime unlimited
  };

  # CPU Governor audio için
  powerManagement.cpuFreqGovernor = lib.mkForce "performance";
}
