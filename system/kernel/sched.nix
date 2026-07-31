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
  # Ayrıca fan_mode 5 (turbo/max): "oyunlarda her zaman soğuk" tercihi (2026-07-17).
  # Turbo, EC'nin fanlarını tam güce (~6900 RPM) alır → dGPU en soğuk + fan tepkisi
  # maksimum. NOT: CPU yine ~95°C SMU tavanında (fan bunu değiştirmez, defter E-matrisi)
  # ve SESLİDİR — bilinçli seçim. 5→0 çıkışı temiz (defter E3). Yalnız AC'de:
  # pilde oyun güç-limitli, max fan anlamsız gürültü+drain olur.
  # EC uçucu → stop'ta 0xED profil 0 (boot varsayılanı) + gigabyte-power-profile
  # ACBT 80/fan modunu (AC→0 dengeli) geri kurar.
  # Ayrıntı: Documentation/aerox16/wmi-ec.md "Deneysel 0xED" tablosu + preset karakterizasyonu.
  gamePerfStart = pkgs.writeShellScript "game-perf-start" ''
    if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "1" ]; then
      if [ -w /proc/acpi/call ]; then
        echo '\_SB.PCI0.AMW0.WMBD 0 0xED 2' > /proc/acpi/call
        cat /proc/acpi/call > /dev/null
      fi
      # Turbo fan (max üfleme) — aorus-laptop preset selector
      F=/sys/devices/platform/aorus_laptop/fan_mode
      [ -w "$F" ] && echo 5 > "$F"
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
  gamePerfStop = pkgs.writeShellScript "game-perf-stop" ''
    if [ -w /proc/acpi/call ]; then
      echo '\_SB.PCI0.AMW0.WMBD 0 0xED 0' > /proc/acpi/call
      cat /proc/acpi/call > /dev/null
    fi
    /run/current-system/sw/bin/systemctl start gigabyte-power-profile.service || true
    # GR_CPUMAX işaret dosyasını temizle → sonraki oyun varsayılan balanced başlasın.
    UID_ZIXAR=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
    rm -f "/run/user/$UID_ZIXAR/gamerun-cpumax" 2>/dev/null || true
    # CPU profilini geri al: power-display.service AC/BAT'a göre balanced/power-saver set
    # eder (oyun bittiği için balanced/performance'tan düşer). Sabit yazmıyoruz → tek otorite orası.
    /run/current-system/sw/bin/systemctl start power-display.service || true
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
        # hypridle org.freedesktop.ScreenSaver arayüzünü sağlar → oyun
        # sırasında ekran kararması/kilidi bastırılır (yalnız oyun
        # oturumunda, idle maliyeti yok; bkz. home/desktop/session.nix hypridle)
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
  };

  # game-perf: gamemode start/end kancalarının hedefi. Wants ile scx'i başlatır,
  # stop'ta PartOf scx'i durdurur. Faz E kanıtlanan kol: 0xED profil 2 (start,
  # AC'de) / profil 0 (stop). CPU kolu: start'ta PPD VARSAYILAN balanced (AC'de,
  # GPU-öncelik — dGPU'ya paylaşımlı Dynamic Boost bütçesi bırakır; GR_CPUMAX=1 ise
  # performance), stop'ta power-display.service geri hesaplar (balanced/power-saver).
  # PPD'yi kendi D-Bus API'siyle sürüyoruz — ham governor/EPP yazımı DEĞİL, o yüzden
  # amd-pstate=active ile çatışmaz (TLP tam bu yüzden kaldırılmıştı, 2026-07-18).
  systemd.services.game-perf = {
    description = "Oyun performans profili (scx_lavd + 0xED) — gamemode kancaları tetikler";
    wants = [ "scx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${gamePerfStart}";
      ExecStopPost = [ "${gamePerfStop}" ];
    };
  };

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
