{ pkgs, ... }:

{
  # Güç profili yönetimi
  services.power-profiles-daemon.enable = true;
  services.printing.enable = false;
  systemd.oomd.enable = false;

  # Kernel versiyonu
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Plymouth quiet boot için log bastırma
  boot.consoleLogLevel = 0;
  boot.initrd.verbose  = false;

  boot.kernelParams = [
    # --- AMD GPU / CPU ---
    "amd_pstate=active"            # Strix Point/Zen 5 EPP scaling
    "amdgpu.gfx_off=1"            # RDNA 3.5 iGPU sleep
    "amdgpu.abmlevel=3"           # eDP panel Auto Brightness Management
    "amdgpu.dcdebugmask=0x12"     # Zen 5 Panel Self Refresh freeze fix

    # --- Enerji Verimliliği ---
    "nowatchdog"                   # NMI watchdog kapalı → wakeup azalır
    "nmi_watchdog=0"               # aynı şeyin kernel param karşılığı
    "pcie_aspm=force"              # PCIe Active State PM → dGPU/WiFi/NVMe uykuya girebilir
    "pcie_aspm.policy=powersupersave" # en agresif ASPM politikası
    "mem_sleep_default=s2idle"     # Modern Standby (s2idle) tercih et
    "nvidia_drm.fbdev=1"           # NVIDIA framebuffer → Plymouth + Wayland uyumu
    "snd_hda_intel.power_save=1"   # HDA ses kartı boşta power save
    "snd_hda_intel.power_save_controller=Y"

    # --- Plymouth Quiet Boot ---
    "quiet"
    "splash"
    "rd.systemd.show_status=false"
    "rd.udev.log_level=3"
    "udev.log_priority=3"
    "boot.shell_on_fail"           # hata olursa shell düşsün, debug kolaylığı
  ];

  # Realtek rtw89 WiFi + HDA ses kartı modprobe parametreleri
  boot.extraModprobeConfig = ''
    options rtw89_pci disable_clkreq=0 disable_aspm_l1=0 disable_aspm_l1ss=0
    options rtw89_core power_save=Y
    options snd_hda_intel power_save=1 power_save_controller=Y
  '';

  # Kernel sysctl power tuning
  boot.kernel.sysctl = {
    "vm.laptop_mode"              = 5;    # Disk yazma gecikmesi → daha az wakeup
    "vm.dirty_writeback_centisecs" = 6000; # 60s writeback → disk uykuda kalır
    "vm.dirty_expire_centisecs"   = 6000;
    "kernel.nmi_watchdog"         = 0;    # runtime'da da watchdog kapalı
  };

  # Powertop auto-tune (boot sonrası tüm cihazları power save moduna al)
  powerManagement.powertop.enable = true;
}
