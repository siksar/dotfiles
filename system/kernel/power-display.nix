{ config, pkgs, ... }:

let
  # AC → balanced, pil → power-saver (PPD kendiliğinden değiştirmiyor). Parlaklık fişe göre değişmez.
  # power-saver'da scaling_max_freq SMT çiftlerinde bölünmüş görünür: regresyon değil.
  powerDisplayScript = pkgs.writeShellScript "power-display" ''
    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)
    PPCTL=${pkgs.power-profiles-daemon}/bin/powerprofilesctl

    # Oyun oturumu açık mı — tek sorgu (üç karar noktası aynı anlık görüntüyü kullanır).
    GAME=0
    ${pkgs.systemd}/bin/systemctl is-active --quiet game-perf.service && GAME=1

    # PPD set, istenen profil kendi sandığına eşitse no-op; boot'ta 'balanced' sanıp EPP performance'ta kalıyor
    # → EPP'yi geri oku, uyuşmuyorsa başka profile uğrayıp dön. Ham EPP yazma (TLP kavgası).
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

    # nvidia-powerd yalnız fişte (Dynamic Boost zaten yalnız AC'de). --no-block: Type=dbus beklemesin.
    SYSTEMCTL=${pkgs.systemd}/bin/systemctl

    if [ "$AC" = "0" ]; then
      # Webcam pilde hard-off (autosuspend yetmez, enumerate bile olmasın)
      echo 0 > /sys/bus/usb/devices/1-1/authorized 2>/dev/null || true
      ppd_apply power-saver
      "$SYSTEMCTL" stop --no-block nvidia-powerd.service 2>/dev/null || true
    else
      echo 1 > /sys/bus/usb/devices/1-1/authorized 2>/dev/null || true
      "$SYSTEMCTL" start --no-block nvidia-powerd.service 2>/dev/null || true
      # AC: balanced (oyunda da: CPU+dGPU Dynamic Boost bütçesini paylaşır). GR_CPUMAX işareti varsa performance.
      UID_ZIXAR=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
      if [ "$GAME" = "1" ] && [ -f "/run/user/$UID_ZIXAR/gamerun-cpumax" ]; then
        ppd_apply performance
      else
        ppd_apply balanced
      fi

      # power-saver scaling_max_freq'i ~2 GHz'e yazar ve geri açmaz → AC'de elle aç.
      # AC tavanı 4.5 GHz (ölçüldü: son 590 MHz %9 hız için %96 güç, +16 °C). Oyunda (game-perf) tavan yok;
      # game-perf durunca power-display yeniden koşar.
      if [ "$GAME" = "1" ]; then
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
      # boost anahtarı cpufreq/boost (AMD'de intel_pstate/no_turbo yok).
      B=/sys/devices/system/cpu/cpufreq/boost
      [ -w "$B" ] && [ "$(cat "$B" 2>/dev/null)" != "1" ] && echo 1 > "$B" 2>/dev/null || true
    fi

    # Affinity maskesi fişe bağlı: pilde Zen5c (cores.nix), fişte 0-15. PID1 + mevcut süreçler
    # taskset ile süpürülür (PID1 CPUAffinity'si çalışırken değişmez).
    TASKSET=${pkgs.util-linux}/bin/taskset
    if [ "$GAME" = "1" ]; then
      : # Oyun sırasında DOKUNMA: affinity'yi gamerun yönetiyor (taskset -c 0-15 /
        # GR_PIN). Oyun-ortası bir ACAD olayı oyunu Zen5c'ye çekerse kare süresi çöker.
    else
      if [ "$AC" = "0" ]; then MASK=1,3,5,7,9,11,13,15; else MASK=0-15; fi
      # Önce PID1: bundan SONRA doğacak her süreç doğru maskeyi miras alsın.
      "$TASKSET" -a -pc "$MASK" 1 >/dev/null 2>&1 || true
      for P in /proc/[0-9]*; do
        PID=''${P#/proc/}
        # Kernel thread'i boş cmdline'dan tanı. `[ -s cmdline ]` KULLANMA: procfs boyutu hep 0.
        IFS= read -r -d "" _CMD < "$P/cmdline" 2>/dev/null || continue
        # nix-daemon muafiyeti (cores.nix) korunsun: derlemeler 16 CPU'da kalmalı.
        read -r _COMM < "$P/comm" 2>/dev/null || true
        [ "$_COMM" = "nix-daemon" ] && continue
        "$TASKSET" -a -pc "$MASK" "$PID" >/dev/null 2>&1 || true
      done
    fi

    # WiFi PS: AC'de kapalı (rtw89 PS gecikme/kopma yapıyor), pilde açık.
    IW=${pkgs.iw}/bin/iw
    for W in /sys/class/net/*/wireless; do
      [ -e "$W" ] || continue
      D=''${W%/wireless}; DEV=''${D##*/}   # basename(dirname) — fork'suz
      if [ "$AC" = "0" ]; then
        "$IW" dev "$DEV" set power_save on  2>/dev/null || true
      else
        "$IW" dev "$DEV" set power_save off 2>/dev/null || true
      fi
    done

    # --no-block: compositor hazır değilken asılıp graphical.target'ı ve switch'i kilitliyordu.
    systemctl --user -M zixar@.host start --no-block power-display-user.service 2>/dev/null || true
  '';

  # Hyprland'de tazeleme sabit; VRR fişe bağlı, karar main.lua power_sync()'te.
  powerDisplayUserScript = pkgs.writeShellScript "power-display-user" ''
    # Hyprland: VRR'ı yeniden hesaplat ve çık; cosmic-randr burada kalıcı wlr override bırakırdı.
    case "''${XDG_CURRENT_DESKTOP:-}" in
      *Hyprland*)
        ${pkgs.coreutils}/bin/timeout 5 ${config.programs.hyprland.package}/bin/hyprctl \
          eval 'power_sync()' >/dev/null 2>&1 || true
        exit 0
        ;;
    esac

    AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)

    # timeout: Wayland soketi var ama compositor cevap vermiyorsa sonsuza dek asılmasın.
    RANDR="${pkgs.coreutils}/bin/timeout 5 ${pkgs.cosmic-randr}/bin/cosmic-randr"
    # Oturum yoksa (Wayland soketi yok) burada sessizce çık — hata basma.
    $RANDR list >/dev/null 2>&1 || exit 0

    if [ "$AC" = "0" ]; then
      HZ=60      # Pil: 60Hz → scanout yükü düşer
    else
      HZ=165     # AC: tam yenileme (adaptive-sync'e DOKUNULMUYOR, otomatik kalır)
    fi

    $RANDR mode eDP-1 2560 1600 --refresh "$HZ" >/dev/null 2>&1 || true
  '';
in
{
  services.upower.enable = true;

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", \
      RUN+="${pkgs.systemd}/bin/systemctl start --no-block power-display.service"
  '';

  # wantedBy=graphical.target (multi-user DEĞİL): PPD After=multi-user.target taşıyor → sıralama döngüsü.
  systemd.services.power-display = {
    description = "AC/BAT webcam + power-profile adaptation";
    wantedBy = [ "graphical.target" ];
    after    = [ "power-profiles-daemon.service" "nvidia-powerd.service" ];
    wants    = [ "power-profiles-daemon.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayScript;
    };
  };

  systemd.user.services.power-display-user = {
    description = "AC/BAT ekran tazeleme hızı adaptasyonu (COSMIC)";
    wantedBy = [ "cosmic-session.target" ];
    after    = [ "cosmic-session.target" ];
    partOf   = [ "cosmic-session.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = powerDisplayUserScript;
    };
  };
}
