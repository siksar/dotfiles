{ config, pkgs, ... }:

{
  # Güç profili yönetimi: power-profiles-daemon (2026-07-18, TLP'den geçildi).
  # amd-pstate=active + EPP/platform_profile'i PPD yönetir → GNOME güç kaydırıcısı
  # (Performans/Dengeli/Güç tasarrufu) + uygulamaların D-Bus'tan performans istemesi.
  # TLP kaldırıldı: CPU governor/EPP/platform_profile'i aynı anda set etmesi amd-pstate
  # ile çatışıyordu (AMD/Limonciello uyarısı). Cihaz autosuspend'i artık powertop
  # --auto-tune (aşağıda, boot) + kernel ASPM param'ı + EC üstleniyor; brightness/
  # webcam/refresh AC-BAT adaptasyonu power-display.nix'te kaldı.
  services.power-profiles-daemon.enable = true;

  services.printing.enable = false;
  systemd.oomd.enable = false;

  # Kernel versiyonu
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.kernelModules = [ "amdgpu" ];

  # NPU kullanılmıyor — amdxdna modülü yüklenmesin (lokal AI istenirse kaldır)
  boot.blacklistedKernelModules = [ "amdxdna" ];

  # Plymouth quiet boot için log bastırma
  boot.consoleLogLevel = 0;
  boot.initrd.verbose  = false;

  boot.kernelParams = [
    # --- CPU güvenlik azaltmaları KAPALI (2026-07-18, kullanıcı onayı) ---
    # Spectre/Meltdown/MDS vb. azaltmalarını devre dışı bırakır → oyun/CPU yükünde
    # ~%3-7 kazanç (özellikle syscall-yoğun iş). BEDEL: spekülatif-yürütme
    # açıklarına karşı savunma düşer — tek kullanıcılı, güvenilen kişisel laptop
    # olduğundan kabul edildi. Geri almak istenirse bu satırı sil.
    "mitigations=off"

    # --- AMD GPU / CPU ---
    "amd_pstate=active"            # Strix Point/Zen 5 EPP scaling
    "amdgpu.gfx_off=1"            # RDNA 3.5 iGPU sleep
    "amdgpu.abmlevel=4"           # eDP panel Auto Brightness Management (max seviye)

    # --- Enerji Verimliliği ---
    "nowatchdog"                   # NMI watchdog kapalı → wakeup azalır
    "nmi_watchdog=0"               # aynı şeyin kernel param karşılığı
    "pcie_aspm=force"              # PCIe Active State PM → dGPU/WiFi/NVMe uykuya girebilir
    "pcie_aspm.policy=powersupersave" # en agresif ASPM politikası
    "pcie_port_pm=force"           # PM'i reddeden PCIe köprülerde de runtime PM zorla
    "workqueue.power_efficient=1"  # kworker'ları boşta çekirdeklere topla → daha derin C-state
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
    options rtw89_core disable_ps_mode=n
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

  # --- Suspend / Hibernate ---
  # Disk swap 33,5G > 30,5G RAM → hibernate image'ı rahat sığar (zram ayrı,
  # kernel resume= imajı doğrudan bu partisyona yazar, swap önceliğinden
  # bağımsız). resumeDevice set edilmezse systemd-stage-1 initrd'de resume=
  # kernel parametresi hiç eklenmiyor — /sys/power/resume "0:0" kalıp hibernate
  # tamamen çalışmaz (ölçüldü). hardware-configuration.nix'teki tek
  # swapDevices girdisini tekrar UUID yazmadan referans alıyoruz.
  boot.resumeDevice = (builtins.head config.swapDevices).device;

  # s2idle kapak kapalıyken bile saatlerce yavaşça pil tüketir — "Modern Standby"
  # gerçek sıfır güç değil. Bu makinede /sys/power/mem_sleep YALNIZCA [s2idle]
  # listeler (deep/S3 hiç yok), yani "daha ucuz bir düz uyku" alternatifi mevcut
  # değil → suspend-then-hibernate kozmetik değil, tek gerçek kaldıraç.
  # Önce s2idle'a gir (hızlı açılış), 25 dk sonra hâlâ uyanmadıysa gerçek
  # hibernate'e düş (RAM diske yazılır, güç tamamen kesilebilir).
  #
  # HibernateOnACPower=true (systemd 257+) → fişteyken de sayaç işler. false
  # olsaydı geri sayım yalnız fiş çekildiğinde başlardı; bu, elektrik kesintisinde
  # oturum kaybı ve fişte hiç 0W'a inmeme demekti.
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec  = "25min";
    HibernateOnACPower = true;
  };

  # Kapak kapama / suspend tuşu suspend-then-hibernate'e yönleniyor; fişte-pilde
  # davranış farkı yok (HibernateOnACPower=true). Hibernate tuşu (varsa) systemd
  # varsayılanıyla doğrudan hibernate'e düşmeye devam eder.
  #
  # DİKKAT — yukarıdaki 25 dk'lık sayaç YALNIZCA uykuya `suspend-then-hibernate`
  # olarak girildiyse başlar. Düz `systemctl suspend` çağıran her yol zinciri
  # baypas eder ve s2idle'da sonsuza kalır; systemd'de düz suspend'i s2h'e
  # yükseltmenin desteklenen bir yolu YOK (SuspendState= sadece /sys/power/state'e
  # yazılan stringi değiştirir), yani çağıran tarafı düzeltmek tek çözüm.
  # Yeni bir uyku tetikleyicisi eklerken `suspend-then-hibernate` yaz — ör.
  # hypridle.conf'ta zamanlayıcı hiç suspend'e bağlanmaz (hyprland-rice/hm.nix,
  # docs/hyprland-rice.md'de gerekçesi), omarchy-menu'nün güç menüsü de
  # `systemctl suspend-then-hibernate` çağırır (waybar-omarchy-compat.nix).
  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleSuspendKey             = "suspend-then-hibernate";
  };
}
