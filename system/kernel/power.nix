# Güç yönetimi — 4.28W idle bütçesinin çekirdeği. GERİLEMEZ.
# PPD (TLP değil) + kernel parametreleri + ASPM + zram + powertop --auto-tune.
# Ölçüm defteri: Documentation/aerox16/power.md
{ config, pkgs, inputs, ... }:

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

  # ---------- Çekirdek: CachyOS bore-lto-zen4 (1 Eyl 2026, linuxPackages_latest'ten) ----------
  #
  # NEDEN bu varyant (hepsi ölçüldü, tahmin yok):
  #  - BORE: görev başına "burst" süresi (uyku↔uyku arası CPU tüketimi) üstel ortalamayla
  #    izlenir; kısa-burst iş (UI thread'i, vsync'te uyanan oyun döngüsü, terminal) ağırlık
  #    bonusu, uzun-burst iş (derleyici, encode) ceza alır. Kazancı YÜK ALTINDA görünür;
  #    boştayken hiçbir şey yapmaz → 4.28W bütçesine dokunmaz. Katı adaletten ödün verir.
  #  - ThinLTO (clang): modüller arası inline/DCE. Kazanç mütevazı, maliyeti sıfır (cache'te).
  #  - zen4: -march=znver4. CPU'nun (Ryzen AI 7 350, Zen5) avx512_bf16 + avx512_vnni dahil
  #    znver4'ün istediği TÜM ISA'ya sahip olduğu /proc/cpuinfo'dan doğrulandı. Bu çekirdek
  #    CPU'ya bağımlıdır: başka bir makinede boot etmez.
  #
  # pkgs.linuxPackagesFor KASITLI — flake'in legacyPackages.linuxPackages-cachyos-* seti
  # xddxdd'nin nixpkgs pin'ini taşır ve NVIDIA'yı 595.99.02'ye düşürür. Böyle sararak
  # yalnız çekirdek oradan gelir; nvidia (610.57.04, gpu.nix), acpi_call ve aorus-laptop
  # bizim pin'imizde kalır. Bu üçü çekirdek sürümüne bağlı olduğu için her çekirdek/sürücü
  # bump'ında YEREL derlenir (~15-25 dk) — cache onları kurtarmaz, normaldir.
  boot.kernelPackages =
    pkgs.linuxPackagesFor inputs.cachyos-kernel.packages.${pkgs.stdenv.hostPlatform.system}.linux-cachyos-bore-lto-zen4;

  # xddxdd'nin attic cache'i — çekirdek buradan İNER, derlenmez (out/dev/modules üçü de
  # doğrulandı). Anahtar flake'in kendi nixConfig'inden alındı. Bu blok olmadan her
  # rebuild bir CachyOS çekirdeği derler (~40+ dk).
  nix.settings = {
    substituters       = [ "https://attic.xuyh0120.win/lantian" ];
    trusted-public-keys = [ "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc=" ];
  };

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

    # --- zswap KAPALI (1 Eyl 2026, CachyOS çekirdeğiyle birlikte geldi) ---
    # CachyOS config'i CONFIG_ZSWAP_DEFAULT_ON=y ile geliyor (nixpkgs çekirdeğinde
    # kapalıydı). Bizde sched.nix'in zram'i var: zswap açık kalırsa sayfa önce zswap
    # havuzunda zstd ile sıkışır, oradan taşınca zram'e yazılırken TEKRAR sıkışır —
    # boşa CPU + çift bellek muhasebesi. Tek katman istiyoruz, o da zram.
    "zswap.enabled=0"

    # --- lazy RCU GERİ AÇILDI (1 Eyl 2026, CachyOS geçişinin gerilemesi) ---
    # ÖLÇÜM: taban 4.28 W (nixpkgs 7.2.0) → 5.16 W (cachyos 7.2.2), +0.88 W.
    # İkisi de temiz koşu (yayılım 0.65 W, fork/s 0, gpu_busy %0, %40 parlaklık,
    # low-power/power, dGPU suspended) — gürültü değil.
    # İki config yan yana konunca güçle ilgili üç fark çıktı:
    #   CONFIG_RCU_LAZY_DEFAULT_OFF   eski: kapalı (lazy AÇIK)  yeni: y (lazy KAPALI)
    #   CONFIG_PREEMPT vs _LAZY       eski: PREEMPT_LAZY        yeni: PREEMPT (full)
    #   CONFIG_CPU_IDLE_GOV_TEO       eski: yok                 yeni: y
    # Üçüncüsü ELENDİ: canlıda governor ikisinde de `menu` (teo derli ama seçili değil).
    # Kalan ilk şüpheli lazy RCU: boştaki CPU'yu RCU callback'i için uyandırmamak
    # üzere onları toplu işler — tam olarak idle bütçesinin konusu. CachyOS varsayılanı
    # kapalı getiriyor, nixpkgs açık getiriyordu. Parametre boot-time (sysfs 0444),
    # runtime'da açılamıyor → burada.
    # TEK DEĞİŞKEN olarak eklendi. Yetmezse sıradaki kaldıraç `preempt=voluntary`
    # (PREEMPT_DYNAMIC ikisinde de açık; cachyos'ta `lazy` modu derli DEĞİL, o yüzden
    # birebir eski davranış değil, en yakını voluntary). Onu ayrı ölçümle dene.
    "rcutree.enable_rcu_lazy=1"

    # --- Enerji Verimliliği ---
    "nowatchdog"                   # NMI watchdog kapalı → wakeup azalır
    "nmi_watchdog=0"               # aynı şeyin kernel param karşılığı
    "pcie_aspm=force"              # PCIe Active State PM → dGPU/WiFi/NVMe uykuya girebilir
    "pcie_aspm.policy=powersupersave" # en agresif ASPM politikası
    "pcie_port_pm=force"           # PM'i reddeden PCIe köprülerde de runtime PM zorla
    "workqueue.power_efficient=1"  # kworker'ları boşta çekirdeklere topla → daha derin C-state
    "mem_sleep_default=s2idle"     # Modern Standby (s2idle) tercih et
    "nohibernate"                  # hibernate YETENEĞİ kapalı — gerekçe aşağıda,
                                   # "HİBERNATE NEDEN KAPALI" bloğunda (24 Ağu 2026)
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
  #
  # UYANDIRMA POLİTİKASI — 24 Ağu 2026: iki klavye de sistemi uyandıramaz.
  # Yetenek denetimi: uykudan uyandırma izni olan yalnız iki USB cihazı vardı —
  # harici BY Tech klavye (258a:0049, removable) ve dahili GIGABYTE HID
  # denetleyicisi (0414:8104, fixed). Fare (22d4:1503) ve Bluetooth (0bda:0852)
  # zaten çekirdek varsayılanıyla "disabled"; onlara kural YAZILMADI — kapsam
  # dışı ve ölçülmemiş bir davranışı sabitlemek regresyon üretir.
  #
  # Geriye kalan uyandırıcılar: kapak (PNP0C0D), güç tuşu (PNP0C0C) ve dahili
  # AT klavye (serio0/i8042 — yazdığın asıl klavye, USB'den ayrı yol). Yani
  # "tuşa basınca uyanma" jesti korunuyor.
  #
  # ⚠️ /proc/acpi/wakeup KULLANMA. O arayüz TOGGLE: cihaz adını yazmak durumu
  # ters çevirir, aynı satırı iki kez çalıştırmak ilk yazımı geri alır — yani
  # idempotent değil, bir serviste ölümcül. Buradaki sysfs yolu idempotent.
  #
  # Doğrulama: `cat /sys/bus/usb/devices/{3-2,3-4}/power/wakeup` → disabled;
  # bir uykudan sonra kimin uyandırdığı `/sys/.../power/wakeup_count` sayaçlarında.
  services.udev.extraRules = ''
    # power/control="on"      : autosuspend kapalı (yukarıdaki girdi-gecikmesi gerekçesi)
    # power/wakeup="disabled" : uykudayken sistemi uyandıramasın (yukarıdaki politika)
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0414", ATTR{idProduct}=="8104", ATTR{power/control}="on", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="258a", ATTR{idProduct}=="0049", ATTR{power/control}="on", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="22d4", ATTR{idProduct}=="1503", ATTR{power/control}="on"
  '';

  # powertop --auto-tune'un ezdiği ayarları geri yazar. powertop'un kendisi
  # kalıyor (ASPM, SATA, ses, i2c vb. onlarca ayarı hâlâ değerli) — yalnız
  # bilinçli olarak istediğimiz birkaçını ondan sonra geri alıyoruz: writeback
  # gecikmesi ve USB power/control ÖLÇÜLMÜŞ ezme; USB power/wakeup ise ihtiyaten
  # (gerekçesi ExecStart'ın içinde, 24 Ağu 2026).
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

        # 2) girdi cihazları: autosuspend kapalı (udev kuralıyla aynı üç cihaz),
        #    iki klavyede ayrıca uyandırma kapalı (udev kuralıyla aynı iki cihaz).
        #
        #    wakeup NEDEN BURADA DA YAZILIYOR (24 Ağu 2026): powertop ikilisinde
        #    /sys/bus/usb/devices/%s/power/wakeup yolu ve bir usb_wakeup tunable
        #    sınıfı VAR (strings ile görüldü). Ölçüm: klavyeler 17:10:51'de
        #    enumere oldu, powertop 17:10:57-59'da koştu, sonrasında ikisi de
        #    hâlâ "enabled" — yani auto-tune wakeup'ı KAPATMIYOR. Ama çekirdek
        #    varsayılanı da "enabled" olduğu için "hiç dokunmuyor" ile "enabled
        #    yazıyor" ayırt EDİLEMİYOR. İkinci ihtimalde udev kuralı (17:10:51)
        #    powertop tarafından ezilirdi — power/control'de bizzat yaşanan
        #    senaryo. Tek satır maliyetine ihtimali kapatıyoruz.
        for D in /sys/bus/usb/devices/*/; do
          V=$(cat "$D/idVendor" 2>/dev/null) || continue
          P=$(cat "$D/idProduct" 2>/dev/null) || continue
          case "$V:$P" in
            0414:8104|258a:0049|22d4:1503)
              echo on > "$D/power/control" 2>/dev/null || true
              ;;
          esac
          case "$V:$P" in
            0414:8104|258a:0049)
              echo disabled > "$D/power/wakeup" 2>/dev/null || true
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
  #
  # Hibernate 24 Ağu 2026'da KAPATILDI (aşağıdaki nohibernate). Bu satır yine de
  # duruyor: kapatan şey politika (nohibernate), yeteneğin nasıl kurulduğu bilgisi
  # bu satır. Yukarı akış düzelince nohibernate'i çıkarmak yeniden açmaya yeter.
  boot.resumeDevice = (builtins.head config.swapDevices).device;

  # ═══ HİBERNATE NEDEN KAPALI — 24 Ağu 2026, journal ölçümüyle ═══════════════
  # Hibernate'in dondurma (freeze) aşaması amdgpu'nun TTM defterini BOZUYOR ve
  # sistem saatler sonra, GPU yükü altında, kurtarılamaz biçimde kilitleniyor:
  #
  #   amdgpu_pmops_freeze → amdgpu_device_evict_resources
  #     → ttm_device_prepare_hibernation → ttm_bo_swapout → ttm_resource_alloc
  #     → WARNING drivers/gpu/drm/ttm/ttm_resource.c:235
  #        (ttm_resource_add_bulk_move)          ← her denemede 10-11 kez
  #   ...saatler sonra, ilk ağır GPU tahsisinde...
  #     → list_del corruption → kernel BUG at lib/list_debug.c:65
  #     → görev TTM LRU spinlock'unu TUTARKEN ölüyor (preempt_count 1)
  #     → amdgpu'ya dokunan her şey sonsuza kilitleniyor → rcu_preempt stall
  #     → ne TTY, ne kapanış, ne SysRq-siz çıkış: güç tuşunu basılı tutmak
  #
  # 25 boot tarandı (29 Tem – 24 Ağu). Bağıntı temiz:
  #   - Çöken 3 boot'un (16/19/24 Ağu) 3'ünde de hibernate denemesi var.
  #   - Hibernate denenmemiş 9 boot'un hiçbirinde çökme yok.
  #   - TTM WARN gören 2 boot'un 2'sinde de çökme geldi → WARN, saatler
  #     öncesinden haber veren bir sinyal.
  #
  # Karşılığında kaybedilen bir şey YOK: hibernate bu makinede bir kez bile
  # tamamlanmadı. Hiçbir boot'ta imaj yazma logu yok, her açılışta
  # "systemd-hibernate-resume: Unable to resume from device ... continuing",
  # boot ID'ler uykular boyunca kesintisiz. MAINTAINERS'ın 30 Tem'den beri
  # "ELLE TEST BEKLİYOR" dediği doğrulama işte bu — ve sonucu: çalışmıyor.
  #
  # Yeniden açmadan önce: kernel'i güncelle, elle bir `systemctl hibernate`
  # dene, sonra `journalctl -kb | grep ttm_resource_add_bulk_move` BOŞ dönmeli
  # ve `journalctl -b | grep 'Resuming from'` bir satır vermeli. İkisi birden
  # olmadan açma. Tam kanıt: Documentation/aerox16/power.md.

  # Yeteneği kapatan parametre "nohibernate", yukarıdaki boot.kernelParams
  # listesinde (tek bir tanım olmak zorunda). Yalnız aşağıdaki logind
  # handler'larını değiştirmek YETMEZDİ: HandleHibernateKey systemd
  # varsayılanıyla hibernate'te kalır ve bir masaüstünün oturum menüsü
  # `hibernate` komutunu suspendThenHibernate'e eşleyebilir.
  # nohibernate ile logind'in CanHibernate'i "na" döner → o yollar
  # kendiliğinden düz suspend'e düşer, çağıran avlamaya gerek kalmaz.

  # HibernateDelaySec/HibernateOnACPower yalnızca suspend-then-hibernate
  # yolunda iş görür; o yol kapalı olduğu için şu an ATIL. Silinmedi — geri
  # açarken 25 dk'nın neden seçildiği burada duruyor: s2idle kapak kapalıyken
  # bile yavaşça pil tüketir ("Modern Standby" gerçek sıfır güç değil) ve bu
  # makinede /sys/power/mem_sleep YALNIZCA [s2idle] listeler (deep/S3 hiç yok),
  # yani daha ucuz bir düz uyku alternatifi mevcut değil.
  # HibernateOnACPower=true (systemd 257+) → fişteyken de sayaç işlerdi; false
  # olsaydı geri sayım yalnız fiş çekildiğinde başlardı.
  systemd.sleep.settings.Sleep = {
    HibernateDelaySec  = "25min";
    HibernateOnACPower = true;
  };

  # Kapak kapama / suspend tuşu düz s2idle suspend'e gidiyor. 24 Ağu 2026'ya
  # kadar burası suspend-then-hibernate'ti; yukarıdaki gerekçeyle geri alındı.
  # Yan kazanç: s2h, uykuya girdikten 25 dk sonra hibernate ayağını çalıştırmak
  # için RTC alarmı kurar ve makineyi HER uykuda bir kez uyandırırdı
  # (journalde her "suspend entry"den tam 25 dk sonraki "suspend exit" buydu).
  # Düz suspend'de o uyanma da yok.
  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandleSuspendKey             = "suspend";
  };
}
