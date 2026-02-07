{ config, pkgs, lib, inputs, ... }:

let
  # NPU monitoring tool
  npuMon = pkgs.writeShellScriptBin "npu-mon" ''
    #!${pkgs.runtimeShell}

    # Check if XDNA driver is loaded
    if ! ${pkgs.kmod}/bin/lsmod | ${pkgs.gnugrep}/bin/grep -q "amdxdna"; then
      echo "AMD XDNA driver not loaded"
      exit 1
    fi

    echo "=== AMD XDNA NPU Status ==="

    # Driver version
    if [ -f /sys/class/accel/accel0/device/driver/module/version ]; then
      echo "Driver Version: $(cat /sys/class/accel/accel0/device/driver/module/version)"
    fi

    # NPU device info
    if [ -d /sys/class/accel/accel0 ]; then
      echo "NPU Device: Available"
      if [ -f /sys/class/accel/accel0/device/power_state ]; then
        echo "Power State: $(cat /sys/class/accel/accel0/device/power_state)"
      fi
    else
      echo "NPU Device: Not found"
    fi

    echo ""
    echo "=== NPU Processes ==="
    ${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep -i "[a]mdxdna\|[n]pu\|[x]dna" || echo "No NPU processes found"
  '';

  # NPU benchmark tool
  npuBench = pkgs.writeShellScriptBin "npu-bench" ''
    #!${pkgs.runtimeShell}

    echo "=== AMD XDNA NPU Benchmark ==="

    # Check driver
    if ! ${pkgs.kmod}/bin/lsmod | ${pkgs.gnugrep}/bin/grep -q "amdxdna"; then
      echo "AMD XDNA driver not loaded"
      echo "Run: sudo modprobe amdxdna"
      exit 1
    fi

    echo "NPU driver loaded"

    # Check device
    if [ -c /dev/accel/accel0 ] || [ -c /dev/accel0 ]; then
      echo "NPU device node available"
    else
      echo "NPU device node not found"
    fi
  '';

in
{
  # AMD XDNA NPU SUPPORT - Strix Point
  boot.kernelPatches = lib.mkAfter [
    {
      name = "amdxdna-config";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        DRM_ACCEL = yes;
        DRM_ACCEL_AMDXDNA = module;
        AMD_IOMMU = yes;
        IOMMU_SVA = yes;
      };
    }
  ];

  boot.kernelModules = [
    "amdxdna"
    "amd_iommu"
  ];

  boot.initrd.kernelModules = [
    "amdxdna"
  ];

  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  boot.kernelParams = [
    "amd_iommu=on"
    "iommu=pt"
    "amdxdna.enable=1"
    "transparent_hugepage=madvise"
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", MODE="0666", TAG+="uaccess"
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", TAG+="uaccess", MODE="0666"
  '';

  environment.systemPackages = with pkgs; [
    npuMon
    npuBench
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
  ];

  users.groups.accel = {};
  users.groups.render = {};

  users.users.zixar.extraGroups = [
    "accel"
    "render"
    "video"
  ];

  systemd.services.npu-init = {
    description = "AMD XDNA NPU Initialization";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "npu-init" ''
        ${pkgs.kmod}/bin/modprobe amdxdna 2>/dev/null || true
      '';
    };
  };

  environment.sessionVariables = {
    "AMD_XDNA_DEVICE" = "/dev/accel/accel0";
  };

  environment.shellAliases = {
    "npu-status" = "npu-mon";
    "npu-test" = "npu-bench";
  };
}
