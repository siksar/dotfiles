{ pkgs, ... }:

{
  # Güç profili yönetimi — TLP tarafından devre dışı bırakılır (modules/hardware/tlp.nix)
  # services.power-profiles-daemon.enable burada set edilmiyor; tlp.nix false yapar.
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
    # NOT: amdgpu.dcdebugmask kaldırıldı → PSR(0x10) + Stutter(0x2) TAM AÇIK.
    # Ekran-açık idle gücünü büyük ölçüde düşürür. Panel donarsa cerrahi fallback:
    # "amdgpu.dcdebugmask=0x200" (yalnız PSR-SU kapalı, PSR1+stutter korunur).

    # --- Enerji Verimliliği ---
    "nowatchdog"                   # NMI watchdog kapalı → wakeup azalır
    "nmi_watchdog=0"               # aynı şeyin kernel param karşılığı
    "pcie_aspm=force"              # PCIe Active State PM → dGPU/WiFi/NVMe uykuya girebilir
    "pcie_aspm.policy=powersupersave" # en agresif ASPM politikası
    "mem_sleep_default=s2idle"     # Modern Standby (s2idle) tercih et
    # NOT: nvidia_drm.fbdev=1 kaldırıldı → dGPU fbcon tutmaz, D3cold'da kalıcı kalır.
    # Konsol fbdev'i zaten amdgpu'da (/proc/fb = amdgpudrmfb). dGPU idle'da uyur.
    "snd_hda_intel.power_save=1"   # HDA ses kartı boşta power save
    "snd_hda_intel.power_save_controller=Y"

    # --- Sessiz Boot (Plymouth olmadan) ---
    "quiet"
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
