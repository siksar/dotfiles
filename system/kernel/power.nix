# Güç yönetimi — 4.28W idle bütçesinin çekirdeği. GERİLEMEZ.
# PPD (TLP değil) + kernel parametreleri + ASPM + zram + powertop --auto-tune.
# Ölçüm defteri: Documentation/aerox16/power.md
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
    # KALDIRILDI 16 Ağu 2026: "amdgpu.gfx_off=1". Böyle bir parametre YOK —
    # kernel logu açıkça reddediyor: "amdgpu: unknown parameter 'gfx_off' ignored".
    # `modinfo amdgpu` 95 parametre listeliyor, gfx içeren tek isim async_gfx_ring.
    # Yani satır boot'tan beri hiçbir şey yapmıyordu. GFXOFF zaten amdgpu'da
    # varsayılan açık; niyet karşılanıyor, parametreye gerek yok.
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
  #
  # KALDIRILDI 16 Ağu 2026: "vm.laptop_mode" = 5. Kernel bunu artık UYGULAMIYOR —
  # mm/page-writeback.c:2233 laptop_mode_handler() yazımı alıp atıyor ve boot'ta
  # şunu basıyor: "systemd-sysctl: vm.laptop_mode is deprecated. Ignoring setting."
  # (`sysctl -n vm.laptop_mode` yine 5 okur; değişkene yazılıyor, davranışa bağlı değil.)
  #
  # UYARI — vm.dirty_writeback_centisecs'i powertop EZİYOR: powertop --auto-tune
  # bu düğüme 1500 yazar ve systemd-sysctl'den SONRA koşar (ölçüldü: sysctl 20:58:22,
  # powertop 20:58:25). O yüzden istenen 6000 aşağıdaki power-tunables-restore
  # servisiyle geri yazılıyor. Buradaki değeri değiştirirsen ORAYI da değiştir.
  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000; # 60s writeback → disk uykuda kalır
    "vm.dirty_expire_centisecs"   = 6000;
    "kernel.nmi_watchdog"         = 0;    # runtime'da da watchdog kapalı
  };

  # Powertop auto-tune (boot sonrası tüm cihazları power save moduna al)
  powerManagement.powertop.enable = true;

  # Girdi cihazları autosuspend'den muaf: powertop yukarıdaki auto-tune'da HER
  # USB cihazını "auto"ya çeker — dahili klavyenin asıl HID arayüzü
  # (GIGABYTE 0414:8104) bunun kurbanı olup gerçek `runtime_status=suspended`a
  # düşüyor (uyanma gecikmesi = tuş girişinde gecikme).
  #
  # DÜZELTME 16 Ağu 2026 — eski yorum iki şeyi yanlış anlatıyordu:
  #
  # 1) "Fare ve klavyenin ikinci arayüzü kernelin USB_QUIRK_NO_AUTOSUSPEND
  #    listesinde" İDDİASI YANLIŞ. Böyle bir liste yok: v7.1'in
  #    drivers/usb/core/quirks.c'sinde ne o sabit ne de 258a/22d4/0414 geçiyor.
  #    O iki cihaz "on" görünüyor çünkü powertop BİTTİKTEN SONRA yeniden
  #    enumere oldular (fare 20:58:38, klavye-2 20:58:39 — powertop 20:58:25'te
  #    bitmişti) ve udev kuralı tazeden işledi. Yani kazara kurtuluyorlar.
  #
  # 2) "replug/reboot gerekir" ÇÖZÜM DEĞİL. Dahili klavye tek sefer (20:58:17)
  #    enumere oluyor ve bir daha olmuyor; powertop her boot'ta ondan SONRA
  #    koştuğu için reboot asla yardım etmez. Ölçüm: klavye uptime'ın %96,2'sini
  #    askıda geçirmiş (runtime_suspended_time 14.029.429 / uptime 14.586.850 ms).
  #
  # Bu yüzden udev kuralı TEK BAŞINA yetmiyor; aşağıdaki
  # power-tunables-restore.service powertop'tan sonra aynı değerleri geri yazıyor.
  # Kural yine de kalıyor — hotplug (yeniden enumerasyon) yolunu o kapatıyor.
  # Birkaç mW için girdi gecikmesine değmez.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0414", ATTR{idProduct}=="8104", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="258a", ATTR{idProduct}=="0049", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="22d4", ATTR{idProduct}=="1503", ATTR{power/control}="on"
  '';

  # powertop --auto-tune'un ezdiği İKİ ayarı geri yazar. powertop'un kendisi
  # kalıyor (ASPM, SATA, ses, i2c vb. onlarca ayarı hâlâ değerli) — yalnız
  # bilinçli olarak istediğimiz bu ikisini ondan sonra geri alıyoruz.
  # Sıralama tek kritik nokta: After=powertop.service.
  #
  # Ölçülen ezme davranışı (16 Ağu 2026):
  #   vm.dirty_writeback_centisecs : 6000 -> 1500
  #   USB power/control            : on   -> auto  (yalnız yeniden enumere
  #                                 olmayan dahili klavyeye kalıcı zarar)
  #
  # wantedBy=graphical.target, multi-user.target DEĞİL (16 Ağu 2026 — SIRALAMA
  # DÖNGÜSÜ, power-display.nix'teki 27 Tem tuzağının BİREBİR aynısı):
  # powertop.service'in unit'i "After=multi-user.target" taşıyor. systemd.target(5):
  # bir target Wants= listesindeki her unit'e örtük After= alır → multi-user.target
  # otomatik After=power-tunables-restore oluyordu. Döngü:
  #   multi-user.target → after → power-tunables-restore → after → powertop
  #                     → after → multi-user.target
  # systemd kıramayıp BİZİM servisin başlatma job'ını düşürdü ("Job
  # power-tunables-restore.service/start deleted to break ordering cycle") —
  # servis sessizce hiç koşmadı, ayarlar powertop'ta kaldı (ölçüldü: 1500/auto).
  # graphical.target zaten After=multi-user.target olduğu için döngü kırılıyor.
  systemd.services.power-tunables-restore = {
    description = "powertop --auto-tune'un ezdiği ayarları geri yaz";
    wantedBy = [ "graphical.target" ];
    after    = [ "powertop.service" ];
    wants    = [ "powertop.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "power-tunables-restore" ''
        # 1) writeback gecikmesi — boot.kernel.sysctl'deki değerle EŞ tutulmalı
        echo 6000 > /proc/sys/vm/dirty_writeback_centisecs

        # 2) girdi cihazları: autosuspend kapalı (udev kuralıyla aynı üç cihaz)
        for D in /sys/bus/usb/devices/*/; do
          V=$(cat "$D/idVendor" 2>/dev/null) || continue
          P=$(cat "$D/idProduct" 2>/dev/null) || continue
          case "$V:$P" in
            0414:8104|258a:0049|22d4:1503)
              echo on > "$D/power/control" 2>/dev/null || true
              ;;
          esac
        done
      '';
    };
  };

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
  # Yeni bir uyku tetikleyicisi eklerken `suspend-then-hibernate` yaz. Caelestia'nın
  # oturum menüsü örnek: systemctl/loginctl çağrılarını logind D-Bus'a alias'lar
  # ve `hibernate` komutu SessionManager.suspendThenHibernate'e eşlenir (CanHibernate
  # ön kontrolüyle, kullanılamazsa düz suspend'e düşer) — bkz.
  # home/desktop/caelestia/default.nix, Documentation/desktop.md'de gerekçesi.
  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandleSuspendKey             = "suspend-then-hibernate";
  };
}
