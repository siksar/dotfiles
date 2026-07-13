{ config, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  # tangalbert919/gigabyte-laptop-wmi — EC erişimi (WMBC/WMBD WMI metodları)
  # Uyumluluk doğrulandı: DMI product_family "GIGABYTE AERO" eşleşiyor,
  # WMI GUID'leri (ABBC0F6F/72/75) bu makinede mevcut.
  # Sunar: hwmon (CPU/GPU sıcaklık, fan RPM), fan_mode, charge_mode/charge_limit
  aorus-laptop = pkgs.stdenv.mkDerivation {
    pname = "aorus-laptop";
    version = "unstable-2026-06-08";

    src = pkgs.fetchFromGitHub {
      owner = "tangalbert919";
      repo  = "gigabyte-laptop-wmi";
      rev   = "912b4e958aebf8c541124606e48fbe4bfcd5bb41";
      hash  = "sha256-AoPKhoPk0/lJ+f+YJZPFpJEZjeY/2CY8WnZ0VmfrJ8A=";
    };

    # Sessiz mod (fan_mode 1) düzeltmesi: sürücünün model-yaşı yoklaması bu
    # 2025 AMD şasisini yanlışlıkla "eski" sanıp fan_modes[1]=0xFA (boş WMBD
    # case) yapıyordu → sessiz mod no-op. Patch, yoklamayı 0xFA yerine yeni
    # sessiz selector 0x57'yi doğrudan feature-detect edecek şekilde değiştirir
    # (0x57 çalışıyorsa yeni model). Ölçüm/gerekçe: docs/aerox16-1vh-wmi.md
    # "Faz F" + docs/aerox16-1vh-test-plan.md. Upstream'e de önerildi (issue #22).
    patches = [ ./aorus-laptop-silent-0x57.patch ];

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
  # bkz. docs/aerox16-1vh-wmi.md "Faz D+E sonuçları"). power-profile kullanıyor.
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
  # docs/aerox16-1vh-wmi.md). Varsayılan: BAT=1 (sessiz), AC=0 (dengeli) —
  # kullanıcı tercihi (eski AC=2/oyun'dan değişti). Fan modu ayrıca Süper+M ile
  # canlı döndürülebiliyor (0→1→2→5, bkz. aşağıdaki fan-mode-cycle servisi);
  # AC/uyku değişimi bu otomatik varsayılanı yeniden uygular (manuel geçici). ACBT
  # (0x4C, ×8W): AC'de 80W → nvidia-powerd GPU tavanını 50→75W+ yapar; pilde 0
  # (verim). gpu_boost (0x51) yazılMIYOR: bu DSDT'de 2=no-op, 3=dGPU eject!
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
          echo 1 > "$P/fan_mode"   # sessiz
          ACBT=0                   # pilde boost bütçesi kapalı
        else
          echo 0 > "$P/fan_mode"   # AC: dengeli (kullanıcı tercihi; eski: 2=oyun)
          ACBT=10                  # 10×8 = 80W Dynamic Boost bütçesi
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

  # Süper+M fan modu döngüsü (0→1→2→5). fan_mode sysfs'i root gerektirir; bu root
  # oneshot servis yazar, sonra masaüstü bildirimini zixar oturumuna runuser +
  # kullanıcı DBus'ı üzerinden gönderir. GNOME kısayolundan polkit ile ŞİFRESİZ
  # tetiklenir (bkz. gnome-hm.nix "Fan mode cycle"). ACBT'ye DOKUNMAZ — dGPU boost
  # ayrı (AC/oyun profili yönetir). Modlar: 0=Dengeli·1=Sessiz·2=Gaming·5=Turbo.
  # (Not: Fn+F7 denendi ama Linux'a güvenilir input/ACPI olayı olarak ulaşmıyor.)
  systemd.services.fan-mode-cycle = {
    description = "aorus-laptop fan modunu döndür (0→1→2→5) + masaüstü bildirimi";
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "fan-mode-cycle" ''
        P=/sys/devices/platform/aorus_laptop/fan_mode
        [ -w "$P" ] || exit 0
        cur=$(${pkgs.coreutils}/bin/cat "$P" 2>/dev/null || echo 0)
        case "$cur" in
          0) next=1; name="Sessiz"  ;;
          1) next=2; name="Gaming"  ;;
          2) next=5; name="Turbo"   ;;
          5) next=0; name="Dengeli" ;;
          *) next=0; name="Dengeli" ;;   # beklenmedik okuma → başa dön
        esac
        echo "$next" > "$P"
        uid=$(${pkgs.coreutils}/bin/id -u zixar 2>/dev/null || echo 1000)
        ${pkgs.util-linux}/bin/runuser -u zixar -- \
          ${pkgs.coreutils}/bin/env \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
            XDG_RUNTIME_DIR="/run/user/$uid" \
          ${pkgs.libnotify}/bin/notify-send -a Fan -u low -t 2000 \
            "Mevcut Mod $next" "$name" >/dev/null 2>&1 || true
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

  # Şarj limiti %100 (tam kapasite; %80 pil-ömrü modu istenirse burayı düşür) —
  # EC'nin reboot sonrası hatırlaması garanti değil, her boot'ta yeniden uygula.
  # charge_limit yalnız custom charge_mode'da (1) çalışır.
  systemd.services.gigabyte-charge-limit = {
    description = "Pil şarj limiti %%100 (aorus-laptop WMI)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "gigabyte-charge-limit" ''
        P=/sys/devices/platform/aorus_laptop
        [ -d "$P" ] || exit 0
        echo 1   > "$P/charge_mode"
        echo 100 > "$P/charge_limit"
      '';
    };
  };
}
