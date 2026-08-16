# AC/BAT ekran + güç profili adaptasyonu + UPower (eski tlp.nix; TLP 2026-07-18'de
# kaldırıldı, güç profili artık PPD — power.nix). Kalan: fişe göre parlaklık/webcam/
# tazeleme hızı + PPD profili ayarı (bir udev+oneshot deseni) ve batarya telemetrisi
# için upower.
{ pkgs, ... }:

let
  # --- Sistem servisi: sysfs brightness + webcam + PPD profili (root) ---
  # ACAD = AC adapter cihazı; BAT: %40 parlaklık + webcam kapalı, AC: %80 + webcam açık.
  #
  # PPD profili de fişe göre burada set edilir (2026-07-18): AC → balanced, BAT →
  # power-saver. Neden gerekli: PPD'nin aktif profili AC/BAT'a göre KENDİLİĞİNDEN
  # değişmiyor (o mantık TLP'deydi, kaldırıldı) ve masaüstünde güç kaydırıcısı
  # yok — yani en son ne kaldıysa fişte de öyle kalıyordu. power-saver, platform_profile'ı
  # low-power'a çekip scaling_max_freq'i 2.0 GHz'e sabitliyor; bu Zen 5 aslında ~5.09 GHz
  # boost yapabiliyor. Sonuç: fişteyken CPU kapasitesinin ~%40'ında → pencere açma /
  # uygulama başlatma / compositor tepkiselliği belirgin yavaş. balanced sınırı kaldırır
  # (EPP=balance_performance, tam boost) ama gereksiz pinlemez.
  # KRİTİK: pilde power-saver KALIR → 4.28W idle bütçesi hiç değişmez (idle'da profil ne
  # olursa olsun CPU en düşük frekansta; 2 GHz sınırı sadece yük altında fark eder).
  powerDisplayScript = pkgs.writeShellScript "power-display" ''
    BL=/sys/class/backlight/amdgpu_bl1
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)
    MAX=$(cat "$BL/max_brightness")
    PPCTL=${pkgs.power-profiles-daemon}/bin/powerprofilesctl

    # PPD profilini uygula + DOĞRULA (2026-07-27). PPD 0.30, istenen profil kendi
    # mevcut profiline EŞİTSE donanıma hiç yazmıyor — "set" sessizce no-op oluyor.
    # Boot'ta PPD kendini zaten "balanced" sanarak açılıyor, EPP ise çekirdeğin boot
    # varsayılanı "performance"ta kalıyor. Sonuç ölçüldü: boştaki 8 çekirdek tam
    # 3465 MHz'e çivileniyor, 623 MHz'e (cpuinfo_min_freq) hiç inemiyor — yani PPD
    # "balanced" derken donanım performance'ta. Bu yüzden set'ten sonra EPP'yi geri
    # okuyup uyuşmuyorsa, başka bir profile uğrayıp dönerek GERÇEK bir geçiş zorluyoruz.
    # Ham EPP yazmıyoruz, bilerek: PPD'yi kendi API'siyle sürmek şart — TLP'nin
    # amd-pstate ile kavgası tam olarak ham governor/EPP yazımıydı (power.nix).
    ppd_apply() {
      WANT=$1
      case "$WANT" in
        # ALT = geçişi zorlamak için uğranacak profil. power-saver'a ASLA uğranmaz:
        # scaling_max_freq'i 2 GHz'e kilitleyip geri açmıyor (aşağıdaki nota bak).
        performance) EXP=performance         ; ALT=balanced    ;;
        balanced)    EXP=balance_performance ; ALT=performance ;;
        power-saver) EXP=power               ; ALT=balanced    ;;
        *)           return 0                                  ;;
      esac
      "$PPCTL" set "$WANT" 2>/dev/null || return 0
      EPPF=/sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference
      [ "$(cat "$EPPF" 2>/dev/null)" = "$EXP" ] && return 0
      "$PPCTL" set "$ALT"  2>/dev/null || true
      "$PPCTL" set "$WANT" 2>/dev/null || true
    }

    if [ "$AC" = "0" ]; then
      echo $((MAX * 40 / 100)) > "$BL/brightness"
      # Webcam pilde hard-off (autosuspend yetmez, enumerate bile olmasın)
      echo 0 > /sys/bus/usb/devices/1-1/authorized 2>/dev/null || true
      ppd_apply power-saver
    else
      echo $((MAX * 80 / 100)) > "$BL/brightness"
      echo 1 > /sys/bus/usb/devices/1-1/authorized 2>/dev/null || true
      # PPD profili (AC): oyun DIŞINDA balanced. Oyunda da (game-perf aktif) VARSAYILAN
      # balanced (GPU-öncelik, 2026-07-18): CPU+dGPU paylaşımlı Dynamic Boost bütçesini
      # paylaşır; performance CPU STAPM'ini yükseltip dGPU'yu ~30W'ta aç bırakır. Yalnız
      # kullanıcı GR_CPUMAX=1 ile performance isterse (gamerun işaret dosyası) onu
      # onurlandır — böylece oyun-ortası bir ACAD olayı (fişle oynama) profili balanced'a
      # zıplatıp GR_CPUMAX'i ezmez. Aksi her koşulda balanced.
      UID_ZIXAR=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
      if ${pkgs.systemd}/bin/systemctl is-active --quiet game-perf.service \
         && [ -f "/run/user/$UID_ZIXAR/gamerun-cpumax" ]; then
        ppd_apply performance
      else
        ppd_apply balanced
      fi

      # Kritik düzeltme (2026-07-18): PPD power-saver profili platform_profile=low-power
      # üzerinden scaling_max_freq'i ~2.0 GHz'e hard-limiter olarak yazar; performance/
      # balanced'a geri dönerken bu limiti GERİ AÇMAZ (ölçüldü). Bu Zen 5 aslında ~5.09 GHz
      # boost yapabilir; AC'de 2 GHz'te kalmak compositor tepkiselliğini belirgin yavaşlatır.
      # BAT'ta power-saver 2 GHz sınırı idle'ı etkilemediğinden (load altında fark eder)
      # aynen kalır → 4.28W idle bütçesi dokunulmaz.
      #
      # AC TAVANI 4.5 GHz — tam açık DEĞİL (16 Ağu 2026, ÖLÇÜMLE). Sabit tek-thread iş,
      # cpu0 (Zen5), tavan taraması (tepe Tctl + marjinal güç):
      #   3.51GHz  7.81s  55.8C   4.3W      4.50GHz  6.06s  64.2C   7.5W
      #   4.00GHz  6.94s  58.9C   5.2W      5.09GHz  5.49s  80.1C  14.7W
      #   4.20GHz  6.60s  60.8C   6.5W
      # Son 590 MHz (4.50→5.09) %9 hız için gücü %96 artırıyor ve tepe sıcaklığı
      # +15.9°C yapıyor; MHz başına marjinal güç 3 mW'tan 15.6 mW'a fırlıyor. V/f
      # eğrisinin dizi tam orada. 4.50 tavanı kazancın %75'ini maliyetin %31'iyle alıyor.
      # Yan fayda: kullanıcının şikâyet ettiği "kısa patlamada 80-90°C" sıçraması
      # 64.2°C'ye iniyor — cores.nix maskesi kalkarken termal bedeli bu satır ödüyor.
      # İkisi birlikte okunmalı: maske AC'de açılıyor (aşağıdaki affinity bloğu),
      # ama Zen5 tepeye çıkmıyor.
      #
      # OYUNDA TAVAN YOK: game-perf aktifken tam boost. Oyun bitince game-perf'in
      # ExecStopPost'u power-display.service'i yeniden başlatıyor (sched.nix), yani
      # tavan kendiliğinden geri geliyor — ayrı bir geri-alma koluna gerek yok.
      if ${pkgs.systemd}/bin/systemctl is-active --quiet game-perf.service; then
        CAP=99999999   # oyun: kapama yok, her çekirdek kendi tavanına
      else
        CAP=4500000
      fi
      for C in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        MAXF=$(cat "$C/cpuinfo_max_freq" 2>/dev/null) || continue
        # Zen5c'nin kendi tavanı (3506494) zaten CAP'in altında → onlara dokunulmaz.
        WANT=$MAXF
        [ "$CAP" -lt "$MAXF" ] && WANT=$CAP
        CURF=$(cat "$C/scaling_max_freq" 2>/dev/null) || continue
        [ "$CURF" != "$WANT" ] && echo "$WANT" > "$C/scaling_max_freq" 2>/dev/null || true
      done
      # boost geri-aç: amd-pstate=active'te anahtar cpufreq/boost (intel_pstate/no_turbo
      # düğümü AMD'de YOK — eski kod yanlış node'u hedefliyordu). 1=boost-on.
      B=/sys/devices/system/cpu/cpufreq/boost
      [ -w "$B" ] && [ "$(cat "$B" 2>/dev/null)" != "1" ] && echo 1 > "$B" 2>/dev/null || true
    fi

    # --- CPU affinity maskesi AC/BAT'a bağlı (16 Ağu 2026, ÖLÇÜMLE) ---
    # cores.nix PID1'e Zen5c-only maske koyar, tüm masaüstü onu miras alır. O maskenin
    # gerekçesi ("5GHz'lik kısa patlamalar idle bütçesini bozar") bugüne kadar watt
    # cinsinden ölçülmemişti; ölçüldü (Documentation/aerox16/cpu-hybrid.md, aynı
    # tek-thread iş, 5 tur alternatifli, PPT marjinali):
    #     Zen5  → 5.51 s / 69.1 J        Zen5c → 8.19 s / 39.5 J
    # Yani race-to-idle bu silikonda KAZANMIYOR: 1.49x hızlı bitirmek 2.5x güç çekiyor,
    # net enerji 1.75x kötü.
    # KAPSAM: bu tablo AC saatlerinde alındı (4.92 vs 3.47 GHz). PİLDE aşağıdaki
    # power-saver kolu HER İKİ çekirdek tipini de 2.0 GHz'e kapıyor (doğrulandı); o
    # iso-frekans koşulu da ölçüldü (16 Ağu 2026): Zen5c'nin enerji avantajı YOK, ölçüm
    # ×1.10 ile ters yönde çıktı. Maske pilde yine de tutuluyor çünkü frekans eşitlendiği
    # için performansa mal olmuyor — ama "Zen5c daha verimli" diye değil, bedava diye.
    # FİŞTE ise yalnızca bedel: 1.49x gecikme, karşılığında anlamsız bir enerji tasarrufu.
    # (Ölçülen semptom: Electron/Deezer fişte 3.47 GHz'de, oyun varken 2.44 GHz'de kalıyordu.)
    # O yüzden maske artık sabit değil, fişe bağlı.
    #
    # SÜPÜRME NEDEN ŞART: PID1'in CPUAffinity'si çalışırken değiştirilemez ve mevcut
    # süreçler maskeyi zaten miras almıştır. Olay tetikli (udev ACAD), poll DEĞİL —
    # power katmanının kuralına uygun. taskset kullanılıyor çünkü cores.nix'in maskesi
    # sched_setaffinity (yumuşak), cgroup AllowedCPUs değil.
    TASKSET=${pkgs.util-linux}/bin/taskset
    if ${pkgs.systemd}/bin/systemctl is-active --quiet game-perf.service; then
      : # Oyun sırasında DOKUNMA: affinity'yi gamerun yönetiyor (taskset -c 0-15 /
        # GR_PIN). Oyun-ortası bir ACAD olayı oyunu Zen5c'ye çekerse kare süresi çöker.
    else
      if [ "$AC" = "0" ]; then MASK=1,3,5,7,9,11,13,15; else MASK=0-15; fi
      # Önce PID1: bundan SONRA doğacak her süreç doğru maskeyi miras alsın.
      "$TASKSET" -a -pc "$MASK" 1 >/dev/null 2>&1 || true
      for P in /proc/[0-9]*; do
        PID=''${P#/proc/}
        # Kernel thread ELE: cmdline'ı BOŞ olan süreç kernel thread'dir (bir kısmı
        # bilerek pinli, affinity'lerine dokunulmamalı).
        # TUZAK: `[ -s "$P/cmdline" ]` KULLANMA — procfs dosyaları boyutu her zaman 0
        # bildirir, userspace süreçler dahil; o test her şeyi kernel thread sanır ve
        # süpürme sessizce hiçbir işe yaramaz (16 Ağu 2026'da kuru testte yakalandı).
        # İÇERİĞE bakmak gerekir. `read` builtin: fork yok, ~400 süreç için önemli.
        IFS= read -r -d "" _CMD < "$P/cmdline" 2>/dev/null || continue
        # nix-daemon muafiyeti (cores.nix) korunsun: derlemeler 16 CPU'da kalmalı.
        read -r _COMM < "$P/comm" 2>/dev/null || true
        [ "$_COMM" = "nix-daemon" ] && continue
        "$TASKSET" -a -pc "$MASK" "$PID" >/dev/null 2>&1 || true
      done
    fi

    # --- WiFi güç tasarrufu AC/BAT uyarlaması ---
    # AC'de KAPALI: rtw89'un dinamik power-save'i (modprobe disable_ps_mode=n ile
    # açık) gecikme sıçraması / mikro-kopma / throughput düşüşü yapar; fişteyken güç
    # bütçesi umursanmadığından runtime nl80211 toggle ile kapatıp en kararlı/en
    # düşük gecikmeli linki alırız. Pilde AÇIK: 4.28W idle bütçesi (idle'da PS'in asıl
    # kazancı burada). Arayüz sabit "wlan0" varsayılmaz, sysfs glob ile bulunur.
    # (Kablo takılıyken WiFi radyosu kapalı → iw inik cihazda sessizce düşer.)
    IW=${pkgs.iw}/bin/iw
    for W in /sys/class/net/*/wireless; do
      [ -e "$W" ] || continue
      DEV=$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/dirname "$W")")
      if [ "$AC" = "0" ]; then
        "$IW" dev "$DEV" set power_save on  2>/dev/null || true
      else
        "$IW" dev "$DEV" set power_save off 2>/dev/null || true
      fi
    done

    # Kullanıcı oturumu varsa Hyprland adaptasyon servisini tetikle
    systemctl --user -M zixar@.host start power-display-user.service 2>/dev/null || true
  '';

  # --- Kullanıcı servisi: Hyprland refresh rate + animasyon ---
  # hyprctl keyword ile canlı ayar; oturum yoksa (Hyprland kapalı) sessizce
  # çıkılır. MOD DEĞERİ lua/main.lua'daki hl.monitor({mode="2560x1600@165"})
  # ile ELLE SENKRON tutulmalı — panel değişirse ikisi birden güncellenmeli.
  powerDisplayUserScript = pkgs.writeShellScript "power-display-user" ''
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)

    HYPRCTL=${pkgs.hyprland}/bin/hyprctl
    "$HYPRCTL" monitors >/dev/null 2>&1 || exit 0

    if [ "$AC" = "0" ]; then
      # Pil: 60Hz + animasyonlar kapalı → residency artar
      MODE="2560x1600@60"
      ANIM=0
    else
      # AC: 165Hz + animasyonlar açık (misc:vrr=2 zaten yalnız tam ekranda devreye girer)
      MODE="2560x1600@165"
      ANIM=1
    fi

    "$HYPRCTL" keyword monitor "eDP-1,$MODE,auto,1" >/dev/null 2>&1 || true
    "$HYPRCTL" keyword animations:enabled "$ANIM" >/dev/null 2>&1 || true
  '';
in
{
  # UPower — batarya telemetrisini D-Bus'a sunar (upower CLI, bazı uygulamalar
  # buradan okur). Salt okuyucu; güç profilini PPD yönetir (power.nix), çakışma yok.
  services.upower.enable = true;

  # udev: AC adaptör bağlantısı değişince sistem servisini tetikle
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", \
      RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-display.service"
  '';

  # Sistem servisi — boot'ta VE udev'de koşar (pille boot edilirse de uygulanır).
  # after/wants power-profiles-daemon: boot'taki koşu PPD hazır olmadan "set" çağırıp
  # sessizce düşmesin (udev tetiklemesinde PPD zaten ayakta olur).
  #
  # wantedBy=graphical.target, multi-user.target DEĞİL (2026-07-27 — sıralama döngüsü):
  # PPD 0.30'un upstream unit'i "After=multi-user.target" taşıyor. systemd.target(5):
  # bir target, Wants=/Requires= listesindeki her unit'e örtük After= alır — yani
  # multi-user.target otomatik olarak After=power-display oluyordu. Döngü:
  #   PPD → after → multi-user.target → after → power-display → after → PPD
  # systemd bunu kıramayıp PPD'nin BAŞLATMA JOB'INI düşürdü ("Unable to break cycle");
  # PPD ancak ~16 sn sonra D-Bus etkinleştirmesiyle geldi ve profil hiç uygulanmadı.
  # graphical.target zaten After=multi-user.target olduğundan buraya asılmak döngüyü
  # kırar (bu makine ly ile hep grafik boot ediyor). display-manager.target bu sistemde
  # hiç tanımlı değil, PPD'nin ona olan After='ı ölü bağ — yeni döngü riski yok.
  systemd.services.power-display = {
    description = "AC/BAT display brightness + webcam + power-profile adaptation";
    wantedBy = [ "graphical.target" ];
    after    = [ "power-profiles-daemon.service" ];
    wants    = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayScript;
    };
  };

  # Kullanıcı servisi — Hyprland oturumu açılınca otomatik koşar. Generic
  # graphical-session.target DEĞİL: rice'ın diğer servisiyle (caelestia.service)
  # aynı desen — yalnız Hyprland'de aktifleşsin.
  systemd.user.services.power-display-user = {
    description = "AC/BAT Hyprland refresh rate + render profile adaptation";
    wantedBy = [ "hyprland-session.target" ];
    after    = [ "hyprland-session.target" ];
    partOf   = [ "hyprland-session.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayUserScript;
    };
  };
}
