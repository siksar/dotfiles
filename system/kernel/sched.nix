# Oyun performans altyapısı (sistem katmanı)
# Kullanım: Steam launch options → gamerun %command%   (ayrıntı: Documentation/gaming.md)
#
# Tasarım kısıtı: pil/idle tabanı 4.28W GERİLEMEZ. Buradaki hiçbir şey boşta
# koşmaz — scx_lavd yalnız gamemode aktifken çalışır, zram pasif, ntsync pasif.
{ lib, pkgs, ... }:

let
  # GameMode kancaları: gamemoded KULLANICI servisi olarak koşar ve NixOS
  # modülü servis PATH'ini pkexec-only linkfarm'a mkForce'lar → mutlak store
  # yolları zorunlu. systemctl izni aşağıdaki polkit kuralından gelir.
  gameStart = pkgs.writeShellScript "gamemode-start" ''
    /run/current-system/sw/bin/systemctl start game-perf.service
  '';
  gameEnd = pkgs.writeShellScript "gamemode-end" ''
    /run/current-system/sw/bin/systemctl stop game-perf.service
  '';

  # GCC performans profili 2 (WMBD 0xED): ACBT 80→160 + agresif fan eğrisi.
  # Ölçüm (2026-07-06, KCD A/B): GPU 38W→62-83W sustained, fan %32-35→%46-49.
  # Ayrıca fan_mode turbo: "oyunlarda her zaman soğuk" tercihi (2026-07-17).
  # Turbo, EC'nin fanlarını tam güce (~6900 RPM) alır → dGPU en soğuk + fan tepkisi
  # maksimum. NOT: CPU yine ~95°C SMU tavanında (fan bunu değiştirmez, defter E-matrisi)
  # ve SESLİDİR — bilinçli seçim. Yalnız AC'de: pilde oyun güç-limitli, max fan
  # anlamsız gürültü+drain olur.
  # ÇIKIŞ: aşağıdaki gamePerfStop başlığına bak — 12 Eyl 2026'da yeniden yazıldı,
  # ham 0xED yazımı kaldırıldı (artık sürücünün platform_profile handler'ı aynı
  # register'ı yönetiyor, iki otorite birbirini eziyordu).
  # Ayrıntı: Documentation/aerox16/wmi-ec.md "Deneysel 0xED" tablosu + preset karakterizasyonu,
  # ve Documentation/gaming.md "0xED'in İKİ yazıcısı var".
  gamePerfStart = pkgs.writeShellScript "game-perf-start" ''
    if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "1" ]; then
      # Turbo fan (max üfleme) — aero_eg61h, PECM+0x2C = 0x0C (düz %63 eğrisi).
      # 7 Eyl 2026: eskiden `aorus_laptop`'a `5` yazılıyordu ve bu, ADJF biti
      # 0 iken TANINMAYAN bir desen (0x04) üretip varsayılana düşüyordu — yani
      # oyun turbosu sessizce çalışmıyordu. Yeni sürücü deseni tam yazıp geri
      # okuyor; yazma tutmazsa -EIO döner (burada sessizce yutuluyor, gamerun
      # tasarım kuralı A: hiçbir yan etki oyunu engellemez).
      F=$(echo /sys/bus/wmi/devices/ABBC0F75-*/fan_mode)
      [ -w "$F" ] && echo turbo > "$F"
      # CPU güç profili — VARSAYILAN balanced (GPU-öncelik, 2026-07-18).
      # Neden performance DEĞİL: CPU ile dGPU, NVIDIA Dynamic Boost (ACBT 80W) altında
      # PAYLAŞIMLI güç/termal bütçe kullanıyor. performance preset'i amd-pmf'e en yüksek
      # CPU STAPM'ini bastırır → CPU 100°C Tjmax'inde bütçeyi yer → nvidia-powerd dGPU'ya
      # ~30W bırakır (aç kalır, tavan 85W). balanced STAPM daha düşük; klok yine talep
      # üzerine yükselir (EPP=balance_performance) → bütçe dGPU'ya kayar. CPU-ağır oyunda
      # kullanıcı `GR_CPUMAX=1 gamerun …` ile performance'a döner: gamerun bir işaret
      # dosyası bırakır, burada okunur (root tek PPD otoritesi; polkit gerekmez).
      # PPD'yi kendi API'siyle set → amd-pstate=active ile çatışmaz (ham governor yazımı
      # değil; TLP'nin kaldırılma sebebi tam da o çatışmaydı).
      UID_ZIXAR=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
      if [ -f "/run/user/$UID_ZIXAR/gamerun-cpumax" ]; then PROF=performance; else PROF=balanced; fi
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$PROF" 2>/dev/null || true

      # ---- 0xED oyun profili — PPD'DEN SONRA YAZILMALI (12 Eyl 2026 düzeltmesi) ----
      # Bu blok eskiden fonksiyonun BAŞINDAYDI ve 7 Eyl'den beri sessizce
      # eziliyordu: aero_eg61h sürücüsü platform_profile handler'ı olarak
      # KAYITLI ve o handler aynı WMBD 0xED register'ını yazıyor
      # (aero-profile.c: low-power→0, balanced→1, performance→2). PPD ise
      # legacy /sys/firmware/acpi/platform_profile üzerinden TÜM handler'lara
      # dağıtıyor — 12 Eyl'de ölçüldü:
      #   powerprofilesctl set performance
      #     → platform-profile-0 (aero_eg61h) = performance   ← 0xED 2 yazıldı
      #     → platform-profile-1 (amd-pmf)    = performance
      # Yani eski sırada: 0xED 2 yaz → PPD balanced → handler 0xED 1 yazar →
      # oyun profili YOK OLUR (ACBT 0xA0→0x50, AC PL1 30→25 W). Sıra tersine
      # çevrilince son söz oyun profilinde kalıyor.
      # BEDELİ, BİLEREK: sürücünün önbelleği (aero_pprof_cur) artık EC ile
      # uyuşmuyor — sysfs "balanced" der, EC 2'dedir. 0xED'in geri okuması YOK
      # (WMBC'de karşılığı yok, aero-profile.c), o yüzden bu kaçınılmaz. Oyun
      # bitince gamePerfStop ikisini yeniden senkronluyor.
      if [ -w /proc/acpi/call ]; then
        echo '\_SB.PCI0.AMW0.WMBD 0 0xED 2' > /proc/acpi/call
        cat /proc/acpi/call > /dev/null
      fi

      # Kritik düzeltme (2026-07-18): PPD power-saver profili platform_profile=low-power
      # üzerinden scaling_max_freq'i ~2.0 GHz'e hard-limiter olarak yazar; performance/
      # balanced'a geri dönerken bu limiti GERİ AÇMAZ (ölçüldü — profil/EPP doğru olsa
      # bile CPU 2 GHz'te kilitli kaldı). Bu Zen 5 aslında ~5.09 GHz boost yapabilir.
      # power-saver'dan kalma eski limitleri tek yanlı temizle:
      #   1) scaling_max_freq → cpuinfo_max_freq (her CPU'da)
      #   2) cpufreq/boost → 1 (boost aç). DİKKAT: amd-pstate=active'te boost anahtarı
      #      BURASI; intel_pstate/no_turbo düğümü AMD'de YOK — eski kod yanlış node'u
      #      hedefliyordu (no-op). 0=boost-off, 1=boost-on (no_turbo'nun TERSİ).
      # Yalnız AC'de, yalnız oyun başlarken — idle/pil tabanına dokunmaz.
      for C in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        MAX=$(cat "$C/cpuinfo_max_freq" 2>/dev/null) || continue
        CUR=$(cat "$C/scaling_max_freq" 2>/dev/null) || continue
        [ "$CUR" != "$MAX" ] && echo "$MAX" > "$C/scaling_max_freq" 2>/dev/null || true
      done
      B=/sys/devices/system/cpu/cpufreq/boost
      [ -w "$B" ] && [ "$(cat "$B" 2>/dev/null)" != "1" ] && echo 1 > "$B" 2>/dev/null || true
    fi
  '';
  # OYUN ÇIKIŞI — 12 EYL 2026'DA YENİDEN YAZILDI. Eski hâli üç yerden kırıktı ve
  # üçü birlikte kullanıcının gördüğü tabloyu üretiyordu: "oyunu kapattım, fan
  # turbo'da kaldı, ama AERO Kontrol'de hiçbir ön ayar seçili görünmüyor."
  #
  #  (1) ÖLÜ BİRİM ADI. `systemctl start gigabyte-power-profile.service` çağrılıyordu;
  #      o birim 7 Eyl'de `aero-power-profile.service` oldu (sürücü değişimi) ve satır
  #      `|| true` ile hatayı yutuyordu. Journal, 12 Eyl'de üç oyun kapanışı:
  #        "Failed to start gigabyte-power-profile.service: Unit ... not found."
  #      → fan modunu ve ACBT'yi geri kuran TEK kol hiç koşmadı. EC uçucu DEĞİL,
  #      kendiliğinden dönmez → fan reboot'a kadar turbo.
  #
  #  (2) HAM `0xED 0` YAZIMI ARTIK YANLIŞ. "Boot varsayılanına dön" diye yazılmıştı,
  #      ama 7 Eyl'den beri boot varsayılanı 0 DEĞİL: PPD açılışta balanced set ediyor
  #      ve aero_eg61h handler'ı onu 0xED 1 olarak yazıyor. 0 en düşük profil
  #      (ACBT kapalı, AC PL1 20 W) — yani oyun sonrası makine boot'takinden DAHA
  #      KISITLI bir güç profilinde bırakılıyordu.
  #
  #  (3) VE O KISITTAN ÇIKIŞ YOK. power-display.service'in `ppd_apply balanced`i,
  #      PPD zaten balanced olduğu için no-op'a düşüyor (bu davranış power-display.nix'te
  #      2026-07-27'de ölçülüp belgelenmiş) → handler'a hiç yazılmıyor → EC 0xED 0'da
  #      KİLİTLİ kalıyor, sysfs ise "balanced" diyor. Sürücünün önbelleği geri okumayla
  #      doğrulanamıyor (WMBC'de 0xED yok), o yüzden yalanı kimse yakalayamıyor.
  #
  # YENİ SIRA — en görünür geri dönüş (fan) önce, profil senkronu sonra:
  gamePerfStop = pkgs.writeShellScript "game-perf-stop" ''
    # GR_CPUMAX işaret dosyasını ÖNCE temizle: aşağıdaki power-display onu okuyor,
    # kalırsa oyun bitmişken performance'ta bırakır.
    UID_ZIXAR=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
    rm -f "/run/user/$UID_ZIXAR/gamerun-cpumax" 2>/dev/null || true

    # Fan modu + dGPU ACBT bütçesi: AC/BAT'a göre aero-eg61h modülü hesaplar.
    # Bu birim `is-active game-perf.service` ile kendini oyun ortasında susturuyor;
    # ExecStopPost sırasında birim "deactivating" durumda olduğu için `is-active`
    # BAŞARISIZ döner ve fan yazımı gerçekten koşar (systemctl yalnız active/reloading
    # için 0 döndürür).
    /run/current-system/sw/bin/systemctl start aero-power-profile.service || true

    # 0xED'i gerçekten geri getir. Ham acpi_call YAZMIYORUZ (yukarıdaki 2+3):
    # standart platform_profile düğümüne yazmak hem EC'yi doğru profile alır hem
    # sürücünün önbelleğini senkronlar, yani sysfs bir daha yalan söylemez.
    # Değer power-display'in PPD kararıyla aynı olmalı: AC → balanced, pil → low-power.
    PP=/sys/firmware/acpi/platform_profile
    if [ -w "$PP" ]; then
      if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "0" ]; then
        echo low-power > "$PP" 2>/dev/null || true
      else
        echo balanced > "$PP" 2>/dev/null || true
      fi
    fi

    # CPU tarafı: power-display.service AC/BAT'a göre PPD profilini, 4.5 GHz tavanını
    # ve affinity maskesini geri hesaplar. Sabit yazmıyoruz → tek otorite orası.
    /run/current-system/sw/bin/systemctl start power-display.service || true
  '';

  # SIZINTI AĞI (12 Eyl 2026). game-perf `Type=oneshot` + `RemainAfterExit=true`,
  # yani gamerun SIGKILL edilirse (trap yakalanamaz, lib/gamerun.nix ilke D'de kabul
  # edilmiş) birim süresiz "active" kalır. Bunun bedeli yalnız "servis açık kalır"
  # değil: aero-power-profile de power-display de `is-active game-perf` görünce
  # fan/affinity yazmayı ATLIYOR — yani fişi çekmek, kapağı kapatmak, uyanmak,
  # hiçbiri turbo'dan çıkaramaz. Reboot'a kadar.
  #
  # Bu betik o durumu tespit edip birimi kapatır: gamerun'ın referans sayacı
  # dizininde CANLI bir PID kalmamışsa oyun oturumu bitmiştir. Yoklama YOK —
  # yalnız olay anında koşar (udev ACAD, uyanış) ve gamerun'ın kendisi de
  # başlamadan önce çağırır.
  gamePerfReap = pkgs.writeShellScript "game-perf-reap" ''
    /run/current-system/sw/bin/systemctl is-active --quiet game-perf.service || exit 0

    UID_ZIXAR=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
    STATE="/run/user/$UID_ZIXAR/gamerun.d"

    if [ -d "$STATE" ]; then
      for F in "$STATE"/*; do
        [ -e "$F" ] || continue
        PID="''${F##*/}"
        # Canlı bir gamerun varsa oyun sürüyor — dokunma.
        if kill -0 "$PID" 2>/dev/null; then exit 0; fi
        rm -f "$F" 2>/dev/null || true    # ölü kayıt
      done
    fi

    echo "game-perf sizintisi toplandi (canli gamerun yok)" >&2
    /run/current-system/sw/bin/systemctl stop game-perf.service || true
  '';
in
{
  # ---------- GameMode: oyun süresince perf boost (tek aktivasyon noktası) ----------
  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      general = {
        renice = 20; # oyun süreci nice -20 (maksimum normal öncelik, 2026-07-18).
                     # scx_lavd bunu ağırlık olarak onurlandırır → oyun, normal-sınıf
                     # görevler içinde en yüksek öncelikli. Gerçek RT (SCHED_FIFO) DEĞİL:
                     # o, scx_lavd'ı bypass eder + busy-loop donma riski taşır (bilinçli).
        ioprio = 0;  # IO best-effort en yüksek öncelik
        # TARİHÇE — iki kez ölçüldü, cevap iki kez değişti:
        #   16 Ağu 2026: SAĞLAYICI YOK. Eski yorum "hypridle sağlar" diyordu ama
        #     hypridle 9 Ağu'da düşmüştü; D-Bus'ta hiçbir org.freedesktop.ScreenSaver
        #     sahibi yoktu, yani gamemode'un inhibit çağrısı boşa gidiyordu.
        #   11 Eyl 2026: SAĞLAYICI VAR — COSMIC'e geçişle `cosmic-idle` bu adı
        #     alıyor (ölçüm: `busctl --user list | grep -i screensaver` →
        #     org.freedesktop.ScreenSaver / cosmic-idle). Yani ayar artık gerçekten
        #     çalışıyor; oyun sırasında otomatik kilit ERTELENİR.
        # DERS: "bu ayar ölü" demek oturum değişince yanlışa döner — bırakılması
        # doğru karardı. Yine de tek güvence değil: tam ekran oyunu asıl koruyan
        # şey Wayland idle-inhibit protokolüdür.
        # TEST EDİLMEDİ: kontrolcüyle 5+ dk klavye/fare girdisi olmadan oyna.
        inhibit_screensaver = 1;
      };
      custom = {
        start = "${gameStart}";
        end   = "${gameEnd}";
      };
    };
  };
  # renice için gamemode grubu üyeliği şart (etkinleşmesi re-login ister)
  users.users.zixar.extraGroups = [ "gamemode" ];

  # ---------- scx_lavd: oyun zamanlayıcısı — YALNIZ oyun sırasında ----------
  # Steam Deck'in kullandığı latency-aware sched_ext zamanlayıcısı.
  services.scx = {
    enable = true;
    package = pkgs.scx.rustscheds;   # scx_lavd içerir (full'den küçük closure)
    scheduler = "scx_lavd";
    extraArgs = [ "--performance" ]; # autopilot yerine sabit performans modu
  };
  systemd.services.scx = {
    wantedBy = lib.mkForce [ ];       # boot'ta BAŞLAMASIN (idle taban korunur)
    partOf = [ "game-perf.service" ]; # game-perf durunca scx da durur → EEVDF döner
    # Başlatma hız sınırını KALDIR — ÖLÇÜLDÜ 2 Eyl 2026. Upstream scx modülü
    # StartLimitBurst=2 / StartLimitIntervalSec=30s koyuyor: 30 sn içinde İKİ kez
    # oyun açmak scx.service'i kalıcı `failed`a düşürüyor ("Start request repeated
    # too quickly") ve `systemctl reset-failed` yapılmadan bir daha ASLA başlamıyor.
    # Yani çöken bir oyunu hemen tekrar açmak scx_lavd'ı SESSİZCE öldürüyordu —
    # ve gamerun'ın "zincir çalışmıyor" şikâyetinin ikinci ayağı buydu.
    # Sınır çöküş-döngüsü koruması içindir; burada tetikleyen bir insandır
    # (gamerun → game-perf → Wants=scx), o yüzden anlamsız.
    startLimitIntervalSec = lib.mkForce 0;   # upstream scx.nix 30s koyuyor → mkForce şart
  };

  # game-perf: OTORİTE DEĞİŞTİ 2 Eyl 2026 — birincil tetikleyici artık gamerun'ın
  # KENDİSİ (lib/gamerun.nix, doğrudan `systemctl start/stop`, referans sayaçlı).
  # Aşağıdaki gamemode custom.start/end kancaları YEDEK yolda kaldı: gamerun'sız
  # başlatılan, gamemode API'sini kendi çağıran oyunlar için. Steam yolunda zaten
  # hiç ateşlemiyorlar (gamemode'un LD_PRELOAD'ı pressure-vessel konteynerinde
  # libgamemode.so'yu bulamıyor — kanıt lib/gamerun.nix başlığında). DİKKAT: iki
  # otorite var demek, gamemode'lu bir oyunun bitişi gamerun'lı bir oyunun
  # game-perf'ini de durdurabilir demek. Aynı anda ikisini birden koşturma.
  #
  # Wants ile scx'i başlatır,
  # stop'ta PartOf scx'i durdurur. Faz E kanıtlanan kol: 0xED profil 2 (start,
  # AC'de) / profil 0 (stop). CPU kolu: start'ta PPD VARSAYILAN balanced (AC'de,
  # GPU-öncelik — dGPU'ya paylaşımlı Dynamic Boost bütçesi bırakır; GR_CPUMAX=1 ise
  # performance), stop'ta power-display.service geri hesaplar (balanced/power-saver).
  # PPD'yi kendi D-Bus API'siyle sürüyoruz — ham governor/EPP yazımı DEĞİL, o yüzden
  # amd-pstate=active ile çatışmaz (TLP tam bu yüzden kaldırılmıştı, 2026-07-18).
  systemd.services.game-perf = {
    description = "Oyun performans profili (scx_lavd + 0xED) — gamerun tetikler";
    wants = [ "scx.service" ];
    startLimitIntervalSec = 0;        # scx ile aynı gerekçe (varsayılan 5 / 10s)
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${gamePerfStart}";
      ExecStopPost = [ "${gamePerfStop}" ];
    };
  };

  # Sızıntı ağının birim tarafı. Tetikleyicileri aşağıda: udev (ACAD) ve uyanış —
  # ikisi de aero-eg61h modülünün kullandığı desenin aynısı (olay → oneshot, timer
  # ya da poll YOK, CLAUDE.md kural 6). Boot'ta çalışmasına gerek yok: game-perf
  # RemainAfterExit'i reboot'u aşmaz.
  systemd.services.game-perf-reap = {
    description = "Sızmış game-perf oturumunu topla (canlı gamerun kalmadıysa durdur)";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${gamePerfReap}";
    };
  };

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", \
      RUN+="${pkgs.systemd}/bin/systemctl start --no-block game-perf-reap.service"
  '';

  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl --no-block start game-perf-reap.service
  '';

  # zixar game-perf.service'i şifresiz yönetebilsin (yalnız bu unit)
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "game-perf.service" &&
          subject.user == "zixar") {
        var verb = action.lookup("verb");
        if (verb == "start" || verb == "stop" || verb == "restart") {
          return polkit.Result.YES;
        }
      }
    });
  '';

  # ---------- ntsync: Wine NT senkron primitifleri (Proton 11/Experimental/GE) ----------
  # Kernel 7.1.1 CONFIG_NTSYNC=m; sürücü /dev/ntsync'i 0666 oluşturur → udev gerekmez.
  boot.kernelModules = [ "ntsync" ];

  # ---------- Bellek: SteamOS değerleri ----------
  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642; # bazı oyunlar NixOS varsayılanını (1M) aşıyor
    "vm.swappiness"    = 180;        # önce zram; bellek baskısı yokken etkisiz
    "vm.page-cluster"  = 0;          # zram'de tekil sayfa okuması (readahead anlamsız)
  };

  # zram: 16GB zstd (RAM'in %50'si). Öncelik 5 > disk swap (-1) → önce zram
  # dolar, 33.5GB'lık bölüm taşma alanı olarak kalır. Boşta sıfır maliyet.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # ---------- Araçlar ----------
  environment.systemPackages = with pkgs; [
    vulkan-tools       # vulkaninfo doğrulaması
    nvtopPackages.full # AMD+NVIDIA GPU izleme (TUI) — MangoHud kaldırıldıktan sonra
                       # birincil oyun-içi ölçüm aracı (ikinci terminalde nvtop / nvidia-smi dmon)
  ];
  # gamescope KALDIRILDI (2026-07-22): bu hibrit topolojide (AMD iGPU süren + NVIDIA dGPU
  # offload) penceresiz çöküyordu (coredump geçmişi, Documentation/gaming.md). İzolasyon gerekirse
  # oyun-içi "unfocused'ta duraklat" ayarını kapatmak yeterli.
}
