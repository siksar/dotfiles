# Gigabyte WMI/EC — ağaç-dışı aorus-laptop modülü + acpi_call ile ham EC yazımı.
# Fan eğrisi, sessiz mod, 0xED perf profili, ACBT dGPU boost bütçesi.
# DSDT/EC sürümüne bağlı, elle tersine mühendislik: Documentation/aerox16/wmi-ec.md
# UYARI: 0x4B ve 0xF1-F3 EC tarafından geri yazılıyor — denemeyin (31 Tem).
{ config, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  # tangalbert919/gigabyte-laptop-wmi — EC erişimi (WMBC/WMBD WMI metodları)
  # Uyumluluk doğrulandı: DMI product_family "GIGABYTE AERO" eşleşiyor,
  # WMI GUID'leri (ABBC0F6F/72/75) bu makinede mevcut.
  # Sunar: hwmon (CPU/GPU sıcaklık, fan RPM, 0.2.0'dan beri CPU+GPU fan duty'si
  # PWM kanalı olarak), fan_mode, charge_mode/charge_limit.
  # 0.2.0 notu: probe artık eğrinin 15 noktasını okuyor; WMBC 0x68'in içindeki
  # Sleep(100ms) yüzünden modül yüklenmesi ~1.5 sn uzuyor (idle bütçesine etkisiz).
  #
  # 16 Ağu 2026 — YEREL YAMALAR KALDIRILDI, ikisi de upstream'e girdi:
  #   fdfa76a0 "Exempt byte-swapping for newer Aero models"  → hwmon RPM swap'ı
  #            DMI dalına "GIGABYTE AERO" ekleyerek atlıyor (bizim raporumuzun
  #            önerdiği biçimin BİREBİR aynısı, wmi-ec.md "Faz F" §1).
  #   c0b0bd14 "Skip silent fan mode ID check for new models" → probe artık
  #            DMI ailesi eşleşince 0xFA yoklamasını hiç yapmadan doğrudan
  #            FAN_SILENT_MODE (0x57) seçiyor (wmi-ec.md "Faz F" §2).
  # Bizim çözümümüzden farklı yol, aynı sonuç: bu makinede product_family tam
  # olarak "GIGABYTE AERO" (ölçüldü) → iki dal da eşleşiyor.
  # Tag YOK: master'a pinliyoruz, çünkü 0.2.0 (5 Tem) bu düzeltmelerden ÖNCE.
  aorus-laptop = pkgs.stdenv.mkDerivation {
    pname = "aorus-laptop";
    version = "0.2.0-unstable-2026-08-08";

    src = pkgs.fetchFromGitHub {
      owner = "tangalbert919";
      repo  = "gigabyte-laptop-wmi";
      rev   = "8abb6655109726bca1d4fd869909d2cb0252e380";   # master (2026-08-08)
      hash  = "sha256-172QRXUnIDcEbdOVVEKs1YV1p3gepoikex1SR493SzE=";
    };

    nativeBuildInputs = kernel.moduleBuildDependencies;
    hardeningDisable  = [ "pic" ];

    makeFlags = [
      "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ];

    installPhase = ''
      runHook preInstall
      install -D aorus-laptop.ko \
        $out/lib/modules/${kernel.modDirVersion}/extra/aorus-laptop.ko
      runHook postInstall
    '';
  };
in
{
  # acpi_call KALICI: dGPU Dynamic Boost bütçesi (NPCF.ACBT) yalnız ham
  # WMBD 0x4C ile yazılabiliyor (sürücünün gpu_boost'u LCBT=0 yüzünden işlevsiz;
  # bkz. Documentation/aerox16/wmi-ec.md "Faz D+E sonuçları"). power-profile kullanıyor.
  boot.extraModulePackages = [ aorus-laptop config.boot.kernelPackages.acpi_call ];
  boot.kernelModules = [ "aorus-laptop" "acpi_call" ];

  # Çıplak Fn tuşu F20 (HID usage 0x7006f) gönderiyor ve xkb bunu
  # XF86AudioMicMute'a eşlediği için her Fn basışı mikrofonu aç/kapa
  # yapıyordu (basılı tutunca tekrar bile ediyor). Kernel seviyesinde sustur.
  # Dahili klavye: USB-HID 0414:8104 (GIGABYTE).
  services.udev.extraHwdb = ''
    evdev:input:b0003v0414p8104*
     KEYBOARD_KEY_7006f=reserved
  '';

  # AC/BAT'a göre otomatik fan modu + dGPU Dynamic Boost bütçesi (ölçümler:
  # Documentation/aerox16/wmi-ec.md). Varsayılan: BAT=1, AC=1 (16 Ağu 2026'da 4'ten
  # 1'e alındı — DÖRT MODUN DA ÖLÇÜLMESİNDEN sonra; tablo wmi-ec.md'de).
  #
  # Ölçümün kısası (4 thread Zen5, 60 sn, aynı yük):
  #   mod 4  98.1°C  53.9W  4849MHz  fan 4388/4556   boşta fan DURUR
  #   mod 1  95.0°C  45.3W  4742MHz  fan 2354/2715   boşta fan DURUR
  #   mod 2  99.4°C  53.3W  4840MHz  fan 4893/5186   boşta fan DÖNER (2156)
  #   mod 5  97.0°C  55.1W  4860MHz  fan 6362/6455   boşta fan DÖNER (6594)
  #
  # İki şey öğrenildi:
  # 1) Fan sürekli sıcaklığı DÜŞÜRMÜYOR, performansa çeviriyor. Mod 4→5'te hava
  #    %45 artıyor, sıcaklık yalnız 1.1°C düşüyor; kazanç güce (53.9→55.1W) ve
  #    saate (4849→4860MHz) gidiyor. Boost algoritması Tjmax'i HEDEFLİYOR.
  #    Yani "sürekli yükte 99°C" fanla çözülebilir bir problem değil.
  # 2) Mod 1 istisna: fan eğrisi değil, 95.0°C hedefli KAPALI ÇEVRİM denetleyici.
  #    8. sn'den itibaren Tctl tam 95.0'da çakılı; hedefi tutmak için gücü
  #    (51→45W) ve saati (4840→4742MHz) kırpıyor. Bedeli %2.1 saat, karşılığı
  #    4.4°C + fanın yarı devri. AC'de bu takas tercih edildi.
  # NOT: wmi-ec.md'nin eski "4/5 ölü" ve "mod 2-4 etkisiz olabilir" notları YANLIŞ —
  # dördü de canlı sistemde belirgin biçimde farklı davranıyor (16 Ağu ölçümü).
  # Bu servis fişi takınca/uykudan dönünce fan_mode'u yeniden yazdığı için, elle
  # 4'e almak KALICI DEĞİLDİ; kalıcılık tam olarak bu satırdan geliyor.
  # Fan modu ayrıca Süper+M ile canlı döndürülebiliyor (4→1→2→5, bkz. aşağıdaki
  # fan-mode-cycle servisi);
  # AC/uyku değişimi bu otomatik varsayılanı yeniden uygular (manuel geçici). ACBT
  # (0x4C, ×8W): AC'de 80W → nvidia-powerd GPU tavanını 50→75W+ yapar; pilde 0
  # (verim). gpu_boost (0x51) yazılMIYOR: bu DSDT'de 2=no-op, 3=dGPU eject!
  #
  # fan_mode İSTİSNASI (10 Ağu 2026): bu servis fişi takıp çekince VEYA uykudan
  # dönünce ACAD udev kuralıyla / resumeCommands ile tetikleniyor — game-perf.service
  # oyun ortasında fan_mode=5 (turbo) yazmışken bu servis araya girip KOŞULSUZ 0'a
  # geri yazıyordu, yani oyunun ortasında fişle oynama veya suspend-then-hibernate'ten
  # dönüş turbo'yu sessizce düşürüyordu. game-perf aktifken fan_mode'a DOKUNMA —
  # ACBT (dGPU boost bütçesi) AC/BAT'a göre yine burada yeniden uygulanmalı, o
  # yüzden yalnız fan_mode satırı koşullu, ACBT branch'i aynen kalıyor. `is-active`
  # burada doğru sorgu: game-perf Type=oneshot + RemainAfterExit=true, yani "oyun
  # oturumu sürüyor mu" sorusunun tam karşılığı — zapret defterindeki "is-active ile
  # sağlık ölçme" tuzağıyla AYNI ŞEY DEĞİL (orası Restart=always bir daemon'du).
  systemd.services.gigabyte-power-profile = {
    description = "AC/BAT fan modu + dGPU boost bütçesi (aorus-laptop WMI)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "gigabyte-power-profile" ''
        P=/sys/devices/platform/aorus_laptop
        [ -d "$P" ] || exit 0
        AC=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 1)
        if [ "$AC" = "0" ]; then
          FAN=1    # sessiz
          ACBT=0   # pilde boost bütçesi kapalı
        else
          FAN=1    # AC: sessiz — 95°C kilidi + yarı fan devri (16 Ağu ölçümü, yukarı bak)
          ACBT=10  # 10×8 = 80W Dynamic Boost bütçesi
        fi
        if ${pkgs.systemd}/bin/systemctl is-active --quiet game-perf.service; then
          : # oyun sürüyor — fan_mode'a dokunma, turbo (5) kalsın
        else
          echo "$FAN" > "$P/fan_mode"
        fi
        if [ -w /proc/acpi/call ]; then
          echo "\\_SB.PCI0.AMW0.WMBD 0 0x4C $ACBT" > /proc/acpi/call
          cat /proc/acpi/call > /dev/null
        fi
      '';
    };
  };

  # Suspend dönüşünde NPCF/EC durumu garanti değil — profili yeniden uygula
  powerManagement.resumeCommands = ''
    ${pkgs.systemd}/bin/systemctl start --no-block gigabyte-power-profile.service
  '';

  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", \
      RUN+="${pkgs.systemd}/bin/systemctl start --no-block gigabyte-power-profile.service"
  '';

  # Süper+M fan modu döngüsü (4→1→2→5). fan_mode sysfs'i root gerektirir; bu root
  # oneshot servis yazar, sonra masaüstü bildirimini zixar oturumuna runuser +
  # kullanıcı DBus'ı üzerinden gönderir. SUPER+M kısayolundan polkit ile ŞİFRESİZ
  # tetiklenir (bkz. home/desktop/wm/binds.lua). ACBT'ye DOKUNMAZ — dGPU boost
  # ayrı (AC/oyun profili yönetir). Modlar: 4=Dengeli·1=Sessiz·2=Gaming·5=Turbo.
  # (Not: Fn+F7 denendi ama Linux'a güvenilir input/ACPI olayı olarak ulaşmıyor.)
  systemd.services.fan-mode-cycle = {
    description = "aorus-laptop fan modunu döndür (4→1→2→5) + masaüstü bildirimi";
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "fan-mode-cycle" ''
        P=/sys/devices/platform/aorus_laptop/fan_mode
        [ -w "$P" ] || exit 0
        cur=$(${pkgs.coreutils}/bin/cat "$P" 2>/dev/null || echo 0)
        case "$cur" in
          4) next=1; name="Sessiz"  ;;
          1) next=2; name="Gaming"  ;;
          2) next=5; name="Turbo"   ;;
          5) next=4; name="Dengeli" ;;
          *) next=4; name="Dengeli" ;;   # beklenmedik okuma (0 DAHİL) → dengeliye dön
        esac
        echo "$next" > "$P"
        uid=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
        ${pkgs.util-linux}/bin/runuser -u zixar -- \
          ${pkgs.coreutils}/bin/env \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            XDG_RUNTIME_DIR="/run/user/$uid" \
          ${pkgs.libnotify}/bin/notify-send -a Fan -u low -t 2000 \
            "Mevcut Mod $next" "$name" >/dev/null 2>&1 || true
        # Kalıcı gösterge YOK (09 Ağu): waybar'ın custom/fan modülü Caelestia'ya
        # geçişte kaldırıldı — Caelestia bar'ı sabit 8 kimlikli girdi kabul
        # ediyor, özel modül eklenemiyor (plugin sistemi de boş repo). Bu
        # notify-send toast'ı tek gösterge; Caelestia bildirim daemon'u yakalar.
      '';
    };
  };

  # zixar, fan-mode-cycle.service'i şifresiz start edebilsin (Süper+M keybind)
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "fan-mode-cycle.service" &&
          subject.user == "zixar") {
        return polkit.Result.YES;
      }
    });
  '';

  # Şarj limiti %60 (pil-ömrü modu; masaüstü/prizde sürekli kullanım için —
  # yolculuk öncesi tam kapasite gerekiyorsa burayı 100'e çek + rebuild) —
  # EC'nin reboot sonrası hatırlaması garanti değil, her boot'ta yeniden uygula.
  # charge_limit yalnız custom charge_mode'da (1) çalışır.
  systemd.services.gigabyte-charge-limit = {
    description = "Pil şarj limiti %%60 (aorus-laptop WMI)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "gigabyte-charge-limit" ''
        P=/sys/devices/platform/aorus_laptop
        [ -d "$P" ] || exit 0
        echo 1   > "$P/charge_mode"
        echo 60  > "$P/charge_limit"
      '';
    };
  };
}
