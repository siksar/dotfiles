{ lib, pkgs, ... }:

let
  # Betiklerde tekrar eden iki parça (interpolasyonla gömülü). /nix/store değil:
  # koşan sistemin systemd'siyle konuşmalı.
  systemctl = "/run/current-system/sw/bin/systemctl";
  uidZixar = "UID_ZIXAR=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)";

  # gamemoded user servisi; modül PATH'i pkexec-only linkfarm'a mkForce'lar → mutlak store yolları.
  gameStart = pkgs.writeShellScript "gamemode-start" ''
    ${systemctl} start game-perf.service
  '';
  gameEnd = pkgs.writeShellScript "gamemode-end" ''
    ${systemctl} stop game-perf.service
  '';

  # 0xED profil 2 + fan_mode turbo, yalnız AC.
  gamePerfStart = pkgs.writeShellScript "game-perf-start" ''
    if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "1" ]; then
      # Turbo fan: aero_eg61h PECM+0x2C = 0x0C. Yazma tutmazsa -EIO (yutulur: yan etki oyunu engellemez).
      F=$(echo /sys/bus/wmi/devices/ABBC0F75-*/fan_mode)
      [ -w "$F" ] && echo turbo > "$F"
      # PPD varsayılan balanced (GPU-öncelik): performance CPU STAPM'ini yükseltip ortak Dynamic Boost
      # bütçesini yer, dGPU ~30W'a düşer. GR_CPUMAX=1 işaret dosyasıyla performance.
      ${uidZixar}
      if [ -f "/run/user/$UID_ZIXAR/gamerun-cpumax" ]; then PROF=performance; else PROF=balanced; fi
      ${pkgs.power-profiles-daemon}/bin/powerprofilesctl set "$PROF" 2>/dev/null || true

      # 0xED oyun profili PPD'DEN SONRA yazılmalı: aero_eg61h platform_profile handler'ı aynı register'ı
      # yazıyor, PPD set'i 0xED'i ezer. Bedel: sürücü önbelleği EC ile uyuşmaz; gamePerfStop senkronlar.
      if [ -w /proc/acpi/call ]; then
        echo '\_SB.PCI0.AMW0.WMBD 0 0xED 2' > /proc/acpi/call
        cat /proc/acpi/call > /dev/null
      fi

      # power-saver'dan kalan ~2 GHz scaling_max_freq'i aç ve cpufreq/boost=1 (yalnız AC, oyun başında).
      for C in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
        MAX=$(cat "$C/cpuinfo_max_freq" 2>/dev/null) || continue
        CUR=$(cat "$C/scaling_max_freq" 2>/dev/null) || continue
        [ "$CUR" != "$MAX" ] && echo "$MAX" > "$C/scaling_max_freq" 2>/dev/null || true
      done
      B=/sys/devices/system/cpu/cpufreq/boost
      [ -w "$B" ] && [ "$(cat "$B" 2>/dev/null)" != "1" ] && echo 1 > "$B" 2>/dev/null || true
    fi
  '';
  # OYUN ÇIKIŞI: fanı geri kuran birim aero-power-profile.service (ölü ad `|| true`'da yutulur);
  # ham 0xED 0 yazma (balanced = 1); platform_profile düğümüne yaz ki EC + sürücü önbelleği senkron kalsın.
  gamePerfStop = pkgs.writeShellScript "game-perf-stop" ''
    # GR_CPUMAX işaret dosyasını ÖNCE temizle: aşağıdaki power-display onu okuyor,
    # kalırsa oyun bitmişken performance'ta bırakır.
    ${uidZixar}
    rm -f "/run/user/$UID_ZIXAR/gamerun-cpumax" 2>/dev/null || true

    # Fan + ACBT: aero-power-profile hesaplar. ExecStopPost'ta birim "deactivating" → is-active başarısız, yazım koşar.
    ${systemctl} start aero-power-profile.service || true

    # 0xED'i platform_profile düğümünden geri getir (ham acpi_call değil: önbellek senkron kalsın).
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
    ${systemctl} start power-display.service || true
  '';

  # SIGKILL'de game-perf active kalır, fan/affinity yazıcıları susar → canlı gamerun PID'i yoksa durdur.
  gamePerfReap = pkgs.writeShellScript "game-perf-reap" ''
    ${systemctl} is-active --quiet game-perf.service || exit 0

    ${uidZixar}
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
    ${systemctl} stop game-perf.service || true
  '';
in
{
  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      general = {
        renice = 20;
                     # Gerçek RT değil: scx_lavd'ı bypass eder.
        ioprio = 0;
        inhibit_screensaver = 1;
      };
      custom = {
        start = "${gameStart}";
        end   = "${gameEnd}";
      };
    };
  };
  users.users.zixar.extraGroups = [ "gamemode" ];

  services.scx = {
    enable = true;
    package = pkgs.scx.rustscheds;
    scheduler = "scx_lavd";
    extraArgs = [ "--performance" ];
  };
  systemd.services.scx = {
    wantedBy = lib.mkForce [ ];
    partOf = [ "game-perf.service" ];
    # Upstream StartLimitBurst=2/30s iki hızlı oyun açılışında scx'i kalıcı failed'a düşürür → mkForce.
    startLimitIntervalSec = lib.mkForce 0;
  };

  # Birincil tetikleyici gamerun (systemctl start/stop, referans sayaçlı); gamemode kancaları yedek yol.
  # İki otorite: aynı anda ikisini koşturma.
  systemd.services.game-perf = {
    description = "Oyun performans profili (scx_lavd + 0xED) — gamerun tetikler";
    wants = [ "scx.service" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${gamePerfStart}";
      ExecStopPost = [ "${gamePerfStop}" ];
    };
  };

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

  # zixar game-perf.service'i şifresiz yönetebilsin.
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

  boot.kernelModules = [ "ntsync" ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 2147483642;  # bazı oyunlar varsayılan 1M'yi aşıyor
  };

  environment.systemPackages = with pkgs; [
    vulkan-tools
    nvtopPackages.full
  ];
  # gamescope bilinçli yok: bu hibritte çöküyor.
}
