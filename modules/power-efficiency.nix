{ config, pkgs, lib, ... }:
{
  # ========================================================================
  # POWER EFFICIENCY - TLP & Thermal Management
  # AMD Ryzen AI 7 350 (Strix Point) için optimize edilmiş
  # ========================================================================

  environment.systemPackages = [ pkgs.tlp ];

  # TLP - Advanced Power Management
  services.tlp = {
    enable = true;
    settings = {
      # ─────────────────────────────────────────────────────────────────────
      # CPU GÜÇ AYARLARI
      # ─────────────────────────────────────────────────────────────────────
      CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 30;
      
      # ─────────────────────────────────────────────────────────────────────
      # PLATFORM PROFILE
      # ─────────────────────────────────────────────────────────────────────
      PLATFORM_PROFILE_ON_AC = "balanced";
      PLATFORM_PROFILE_ON_BAT = "low-power";
      
      # ─────────────────────────────────────────────────────────────────────
      # AMD iGPU (Radeon 860M)
      # ─────────────────────────────────────────────────────────────────────
      AMDGPU_ABM_LEVEL_ON_AC = 0;
      AMDGPU_ABM_LEVEL_ON_BAT = 3;  # Adaptive backlight management
      
      # ─────────────────────────────────────────────────────────────────────
      # USB & RUNTIME PM
      # ─────────────────────────────────────────────────────────────────────
      USB_AUTOSUSPEND = 1;
      USB_EXCLUDE_BTUSB = 1;        # Bluetooth adapter hariç tut
      
      RUNTIME_PM_ON_AC = "auto";
      RUNTIME_PM_ON_BAT = "auto";
      
      # ─────────────────────────────────────────────────────────────────────
      # STORAGE
      # ─────────────────────────────────────────────────────────────────────
      AHCI_RUNTIME_PM_ON_AC = "auto";
      AHCI_RUNTIME_PM_ON_BAT = "auto";
      
      # NVMe APST (Autonomous Power State Transitions)
      # Not: kernel.nix'de nvme_core.default_ps_max_latency_us=0 var
      # Bu TLP ile çelişebilir, dikkat!
      
      # ─────────────────────────────────────────────────────────────────────
      # WIFI
      # ─────────────────────────────────────────────────────────────────────
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "on";
      
      # ─────────────────────────────────────────────────────────────────────
      # PCI RUNTIME PM
      # ─────────────────────────────────────────────────────────────────────
      PCIE_ASPM_ON_AC = "default";
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };
  
  # Auto-cpufreq devre dışı (TLP ile çakışmasın)
  services.auto-cpufreq.enable = lib.mkForce false;
  
  # Power-profiles-daemon devre dışı (TLP ile çakışmasın)
  services.power-profiles-daemon.enable = lib.mkForce false;
  
  # Thermald - termal yönetim
  services.thermald.enable = true;
}
