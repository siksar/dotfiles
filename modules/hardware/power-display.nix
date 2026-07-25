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
  # değişmiyor (o mantık TLP'deydi, kaldırıldı) ve Hyprland'da GNOME güç kaydırıcısı
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

    if [ "$AC" = "0" ]; then
      echo $((MAX * 40 / 100)) > "$BL/brightness"
      # Webcam pilde hard-off (autosuspend yetmez, enumerate bile olmasın)
      echo 0 > /sys/bus/usb/devices/1-1/authorized 2>/dev/null || true
      "$PPCTL" set power-saver 2>/dev/null || true
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
        "$PPCTL" set performance 2>/dev/null || true
      else
        "$PPCTL" set balanced 2>/dev/null || true
      fi

      # Kritik düzeltme (2026-07-18): PPD power-saver profili platform_profile=low-power
      # üzerinden scaling_max_freq'i ~2.0 GHz'e hard-limiter olarak yazar; performance/
      # balanced'a geri dönerken bu limiti GERİ AÇMAZ (ölçüldü). Bu Zen 5 aslında ~5.09 GHz
      # boost yapabilir; AC'de 2 GHz'te kalmak compositor tepkiselliğini belirgin yavaşlatır.
      # AC'de her koşuşta limiti tüm CPU'lerde cpuinfo_max_freq'e geri aç + boost'u aç.
      # BAT'ta power-saver 2 GHz sınırı idle'ı etkilemediğinden (load altında fark eder)
      # aynen kalır → 4.28W idle bütçesi dokunulmaz.
      for C in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        MAXF=$(cat "$C/cpuinfo_max_freq" 2>/dev/null) || continue
        CURF=$(cat "$C/scaling_max_freq" 2>/dev/null) || continue
        [ "$CURF" != "$MAXF" ] && echo "$MAXF" > "$C/scaling_max_freq" 2>/dev/null || true
      done
      # boost geri-aç: amd-pstate=active'te anahtar cpufreq/boost (intel_pstate/no_turbo
      # düğümü AMD'de YOK — eski kod yanlış node'u hedefliyordu). 1=boost-on.
      B=/sys/devices/system/cpu/cpufreq/boost
      [ -w "$B" ] && [ "$(cat "$B" 2>/dev/null)" != "1" ] && echo 1 > "$B" 2>/dev/null || true
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

    # Kullanıcı oturumu varsa GNOME adaptasyon servisini tetikle
    systemctl --user -M zixar@.host start power-display-user.service 2>/dev/null || true
  '';

  # --- Kullanıcı servisi: GNOME refresh rate + pil render profili ---
  # gnome-randr mutter'ın org.gnome.Mutter.DisplayConfig D-Bus API'sini kullanır;
  # oturum yoksa sorgu düşer, sessizce çıkılır. Gerçek mod adları (59.994 vb.)
  # panele göre değiştiğinden regex ile sorgu çıktısından seçilir.
  powerDisplayUserScript = pkgs.writeShellScript "power-display-user" ''
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)

    GR=${pkgs.gnome-randr}/bin/gnome-randr
    MODES=$("$GR" 2>/dev/null) || exit 0

    if [ "$AC" = "0" ]; then
      # Pil: 60Hz + animasyonlar kapalı → residency artar
      MODE=$(printf '%s\n' "$MODES" | grep -oE '2560x1600@(59|60)(\.[0-9]+)?' | head -1)
      ANIM=false
    else
      # AC: 165Hz + animasyonlar açık (VRR mutter experimental; yalnız tam ekran)
      MODE=$(printf '%s\n' "$MODES" | grep -oE '2560x1600@16[45](\.[0-9]+)?' | head -1)
      ANIM=true
    fi

    [ -n "$MODE" ] && "$GR" modify eDP-1 --mode "$MODE" || true
    ${pkgs.glib}/bin/gsettings set org.gnome.desktop.interface \
      enable-animations "$ANIM" 2>/dev/null || true
  '';
in
{
  # UPower — batarya telemetrisini D-Bus'a sunar (GNOME kabuğu buradan okur).
  # Salt okuyucu; güç profilini PPD yönetir (power.nix), çakışma yok.
  services.upower.enable = true;

  # udev: AC adaptör bağlantısı değişince sistem servisini tetikle
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", \
      RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-display.service"
  '';

  # Sistem servisi — boot'ta VE udev'de koşar (pille boot edilirse de uygulanır).
  # after/wants power-profiles-daemon: boot'taki koşu PPD hazır olmadan "set" çağırıp
  # sessizce düşmesin (udev tetiklemesinde PPD zaten ayakta olur).
  systemd.services.power-display = {
    description = "AC/BAT display brightness + webcam + power-profile adaptation";
    wantedBy = [ "multi-user.target" ];
    after    = [ "power-profiles-daemon.service" ];
    wants    = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayScript;
    };
  };

  # Kullanıcı servisi — GNOME oturumu açılınca otomatik koşar (graphical-session.target)
  systemd.user.services.power-display-user = {
    description = "AC/BAT GNOME refresh rate + render profile adaptation";
    wantedBy = [ "graphical-session.target" ];
    after    = [ "graphical-session.target" ];
    partOf   = [ "graphical-session.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayUserScript;
    };
  };
}
