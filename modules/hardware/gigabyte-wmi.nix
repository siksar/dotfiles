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
  boot.extraModulePackages = [ aorus-laptop ];
  boot.kernelModules = [ "aorus-laptop" ];

  # Şarj limiti %80 (pil ömrü) — EC'nin reboot sonrası hatırlaması garanti değil,
  # her boot'ta yeniden uygula. charge_limit yalnız custom charge_mode'da (1) çalışır.
  systemd.services.gigabyte-charge-limit = {
    description = "Pil şarj limiti %%80 (aorus-laptop WMI)";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "gigabyte-charge-limit" ''
        P=/sys/devices/platform/aorus_laptop
        [ -d "$P" ] || exit 0
        echo 1  > "$P/charge_mode"
        echo 80 > "$P/charge_limit"
      '';
    };
  };
}
