# Oyun performans altyapısı (sistem katmanı)
# Kullanım: Steam launch options → gamerun %command%   (ayrıntı: docs/gaming.md)
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
  # Yalnız AC'de yazılır; EC uçucu → stop'ta profil 0 (boot varsayılanı) +
  # gigabyte-power-profile ACBT 80/fan modunu geri kurar.
  # Ayrıntı: docs/aerox16-1vh-wmi.md "Deneysel 0xED" tablosu.
  gamePerfStart = pkgs.writeShellScript "game-perf-start" ''
    if [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "1" ] \
       && [ -w /proc/acpi/call ]; then
      echo '\_SB.PCI0.AMW0.WMBD 0 0xED 2' > /proc/acpi/call
      cat /proc/acpi/call > /dev/null
    fi
  '';
  gamePerfStop = pkgs.writeShellScript "game-perf-stop" ''
    if [ -w /proc/acpi/call ]; then
      echo '\_SB.PCI0.AMW0.WMBD 0 0xED 0' > /proc/acpi/call
      cat /proc/acpi/call > /dev/null
    fi
    /run/current-system/sw/bin/systemctl start gigabyte-power-profile.service || true
  '';
in
{
  # ---------- GameMode: oyun süresince perf boost (tek aktivasyon noktası) ----------
  programs.gamemode = {
    enable = true;
    enableRenice = true;
    settings = {
      general = {
        renice = 10; # oyun süreci nice -10
        ioprio = 0;  # IO best-effort en yüksek öncelik
        # GNOME org.freedesktop.ScreenSaver sağlar → oyun sırasında ekran
        # kararması/kilidi bastırılır (yalnız oyun oturumunda, idle maliyeti yok)
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
  # stop'ta PartOf scx'i durdurur. ExecStopPost "tlp start": oyun bitiminde
  # governor/EPP'yi TLP'nin GÜNCEL AC/BAT profiline geri bastırır (oyun
  # ortasında fiş takılır/çekilirse gamemode'un bayat restore'una karşı).
  # Faz E kanıtlanan kol: 0xED profil 2 (start, AC'de) / profil 0 (stop).
  systemd.services.game-perf = {
    description = "Oyun performans profili (scx_lavd + 0xED) — gamemode kancaları tetikler";
    wants = [ "scx.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${gamePerfStart}";
      ExecStopPost = [ "${gamePerfStop}" "${pkgs.tlp}/bin/tlp start" ];
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
    nvtopPackages.full # AMD+NVIDIA GPU izleme (TUI)
  ];
  # gamescope: isteğe bağlı upscale/frame-limit aracı (yalnız launch options'ta
  # yazıldığı oyunda devreye girer). capSysNice=false kalmalı (NVIDIA sorunlu).
  programs.gamescope.enable = true;
}
