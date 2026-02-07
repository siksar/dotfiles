{ config, pkgs, lib, inputs, ... }:

let
  # AMD XDNA driver package (from chaotic nyx or custom)
  amdXdnaDriver = config.boot.kernelPackages.amd-xdna-driver or null;
  
  # Ryzen AI SDK and tools
  ryzenAiSdk = pkgs.stdenv.mkDerivation rec {
    pname = "ryzen-ai-sdk";
    version = "1.3.0";
    
    src = pkgs.fetchurl {
      url = "https://www.xilinx.com/bin/public/openDownload?filename=ryzen-ai-sdk-${version}.tar.gz";
      sha256 = lib.fakeSha256; # Replace with actual hash when available
    };
    
    nativeBuildInputs = with pkgs; [
      autoPatchelfHook
      cmake
      python3
    ];
    
    buildInputs = with pkgs; [
      stdenv.cc.cc.lib
      libxml2
      zlib
    ];
    
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
    
    meta = with lib; {
      description = "AMD Ryzen AI SDK for NPU development";
      license = licenses.unfree;
      platforms = [ "x86_64-linux" ];
    };
  };

  # NPU monitoring tool
  npuMon = pkgs.writeShellScriptBin "npu-mon" ''
    #!${pkgs.runtimeShell}
    
    # Check if XDNA driver is loaded
    if ! ${pkgs.kmod}/bin/lsmod | ${pkgs.gnugrep}/bin/grep -q "amdxdna"; then
      echo "❌ AMD XDNA driver not loaded"
      exit 1
    fi
    
    # Display NPU info
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
      if [ -f /sys/class/accel/accel0/device/enable ]; then
        echo "Enabled: $(cat /sys/class/accel/accel0/device/enable)"
      fi
    else
      echo "NPU Device: Not found"
    fi
    
    # Memory info
    if [ -f /sys/class/accel/accel0/device/heap_size ]; then
      echo "Heap Size: $(cat /sys/class/accel/accel0/device/heap_size)"
    fi
    
    # Firmware version
    if [ -f /sys/class/accel/accel0/device/fw_version ]; then
      echo "Firmware: $(cat /sys/class/accel/accel0/device/fw_version)"
    fi
    
    # Temperature (if available)
    if [ -f /sys/class/accel/accel0/device/hwmon/hwmon*/temp1_input ]; then
      TEMP_FILE=$(ls /sys/class/accel/accel0/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
      if [ -n "$TEMP_FILE" ]; then
        TEMP=$(( $(cat "$TEMP_FILE") / 1000 ))
        echo "Temperature: ''${TEMP}°C"
      fi
    fi
    
    # Power consumption (if available)
    if [ -f /sys/class/accel/accel0/device/hwmon/hwmon*/power1_average ]; then
      POWER_FILE=$(ls /sys/class/accel/accel0/device/hwmon/hwmon*/power1_average 2>/dev/null | head -1)
      if [ -n "$POWER_FILE" ]; then
        POWER=$(( $(cat "$POWER_FILE") / 1000000 ))
        echo "Power: ''${POWER}W"
      fi
    fi
    
    echo ""
    echo "=== NPU Processes ==="
    ${pkgs.procps}/bin/ps aux | ${pkgs.gnugrep}/bin/grep -i "[a]mdxdna\|[n]pu\|[x]dna" || echo "No NPU processes found"
  '';

  # NPU benchmark tool
  npuBench = pkgs.writeShellScriptBin "npu-bench" ''
    #!${pkgs.runtimeShell}
    
    echo "=== AMD XDNA NPU Benchmark ==="
    echo "Note: Full benchmark requires Ryzen AI SDK installation"
    echo ""
    
    # Check driver
    if ! ${pkgs.kmod}/bin/lsmod | ${pkgs.gnugrep}/bin/grep -q "amdxdna"; then
      echo "❌ AMD XDNA driver not loaded"
      echo "Run: sudo modprobe amdxdna"
      exit 1
    fi
    
    echo "✅ NPU driver loaded"
    
    # Check device
    if [ -c /dev/accel/accel0 ] || [ -c /dev/accel0 ]; then
      echo "✅ NPU device node available"
    else
      echo "⚠️  NPU device node not found"
    fi
    
    # Check permissions
    if [ -r /dev/accel/accel0 ] || [ -r /dev/accel0 ]; then
      echo "✅ NPU device readable"
    else
      echo "⚠️  NPU device not readable (may need permissions)"
    fi
    
    # List NPU capabilities
    echo ""
    echo "=== NPU Capabilities ==="
    if [ -d /sys/class/accel/accel0/device ]; then
      for f in /sys/class/accel/accel0/device/*; do
        if [ -f "$f" ] && [ -r "$f" ]; then
          NAME=$(basename "$f")
          VALUE=$(cat "$f" 2>/dev/null)
          if [ -n "$VALUE" ] && [ ''${#VALUE} -lt 100 ]; then
            echo "  $NAME: $VALUE"
          fi
        fi
      done
    fi
  '';

in
{
  # =============================================================================
  # AMD XDNA NPU SUPPORT - Strix Point (Ryzen AI 9 HX 370)
  # =============================================================================
  
  # Kernel configuration for NPU
  boot.kernelPatches = lib.mkAfter [
    {
      name = "amdxdna-config";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        # Enable accelerator subsystem
        DRM_ACCEL = yes;
        
        # AMD XDNA driver (if available in kernel)
        DRM_ACCEL_AMDXDNA = module;
        
        # IOMMU for NPU
        AMD_IOMMU = yes;
        AMD_IOMMU_V2 = yes;
        IOMMU_SVA = yes;
        
        # DMA and memory
        DMABUF_MOVE_NOTIFY = yes;
        DMABUF_DEBUG = no;
        
        # FPGA/Accelerator framework
        FPGA = yes;
        FPGA_BRIDGE = yes;
        FPGA_REGION = yes;
        
        # Heterogeneous memory management
        HMM_MIRROR = yes;
        
        # Device memory (for NPU memory allocation)
        DEVICE_PRIVATE = yes;
        DEVICE_GENERIC = yes;
      };
    }
  ];

  # =============================================================================
  # KERNEL MODULES
  # =============================================================================
  
  boot.kernelModules = [ 
    "amdxdna"           # AMD XDNA NPU driver
    "accel"             # Accelerator framework
    "amd_iommu"         # AMD IOMMU
    "amd_iommu_v2"      # AMD IOMMU v2
  ];

  boot.initrd.kernelModules = [ 
    "amdxdna"
    "accel"
  ];

  # =============================================================================
  # FIRMWARE
  # =============================================================================
  
  hardware.firmware = with pkgs; [
    # AMD firmware including NPU firmware
    linux-firmware
    
    # Custom NPU firmware if needed
    (runCommand "amdxdna-firmware" {} ''
      mkdir -p $out/lib/firmware/amdxdna
      # Firmware files will be loaded from linux-firmware
      # If specific firmware needed, add here
    '')
  ];

  # Ensure firmware is loaded
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  # =============================================================================
  # KERNEL PARAMETERS FOR NPU
  # =============================================================================
  
  boot.kernelParams = [
    # IOMMU for NPU
    "amd_iommu=on"
    "iommu=pt"
    
    # NPU specific
    "amdxdna.enable=1"
    "amdxdna.drv_debug=0"
    
    # Shared Virtual Memory
    "iommu.svm=1"
    
    # Memory management
    "hugepagesz=1G"
    "hugepages=4"
    "transparent_hugepage=madvise"
  ];

  # =============================================================================
  # UDEV RULES - NPU Device Permissions
  # =============================================================================
  
  services.udev.extraRules = ''
    # AMD XDNA NPU device permissions
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", ATTR{vendor}=="*AMD*", TAG+="uaccess"
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", ATTR{vendor}=="*Xilinx*", TAG+="uaccess"
    
    # Alternative device node naming
    KERNEL=="accel[0-9]*", SUBSYSTEM=="accel", MODE="0666", TAG+="uaccess"
    
    # NPU power management
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", ATTR{power/control}="auto"
    
    # DRI/render nodes for NPU
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", TAG+="uaccess", MODE="0666"
  '';

  # =============================================================================
  # PACKAGES
  # =============================================================================
  
  environment.systemPackages = with pkgs; [
    # NPU monitoring and tools
    npuMon
    npuBench
    
    # Accelerator tools
    accel-config        # Intel/AMD accelerator config (if available)
    
    # AI/ML libraries with NPU support
    python3Packages.onnxruntime  # ONNX Runtime (may have NPU support)
    
    # Development tools
    vulkan-tools        # For GPU/NPU interop
    clinfo              # OpenCL info
    
    # ROCm (for AMD GPU/NPU compute)
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    
    # AI frameworks
    # ollama             # Local LLMs (can use NPU if supported)
  ] ++ lib.optionals (amdXdnaDriver != null) [
    # Include driver package if available
  ];

  # =============================================================================
  # USER GROUPS
  # =============================================================================
  
  users.groups.accel = {};
  users.groups.render = {};
  
  # Add user to NPU groups
  users.users.zixar.extraGroups = [ 
    "accel" 
    "render" 
    "video"
  ];

  # =============================================================================
  # SYSTEM CONFIGURATION
  # =============================================================================
  
  # Enable accelerator subsystem
  hardware.accel = {
    # Configuration for accelerator devices
  };

  # =============================================================================
  # SERVICES
  # =============================================================================
  
  # NPU monitoring service
  systemd.services.npu-monitor = {
    description = "AMD XDNA NPU Monitor";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${npuMon}/bin/npu-mon";
      StandardOutput = "journal";
    };
  };

  # NPU initialization service
  systemd.services.npu-init = {
    description = "AMD XDNA NPU Initialization";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "npu-init" ''
        #!${pkgs.runtimeShell}
        
        # Load NPU driver if not loaded
        if ! ${pkgs.kmod}/bin/lsmod | ${pkgs.gnugrep}/bin/grep -q "amdxdna"; then
          echo "Loading AMD XDNA driver..."
          ${pkgs.kmod}/bin/modprobe amdxdna || true
        fi
        
        # Set NPU power profile
        if [ -f /sys/class/accel/accel0/device/power_dpm_state ]; then
          echo "performance" > /sys/class/accel/accel0/device/power_dpm_state 2>/dev/null || true
        fi
        
        # Enable NPU
        if [ -f /sys/class/accel/accel0/device/enable ]; then
          echo 1 > /sys/class/accel/accel0/device/enable 2>/dev/null || true
        fi
        
        echo "NPU initialization complete"
      '';
    };
  };

  # =============================================================================
  # ENVIRONMENT VARIABLES
  # =============================================================================
  
  environment.sessionVariables = {
    # NPU device path
    "AMD_XDNA_DEVICE" = "/dev/accel/accel0";
    
    # ROCm paths (for GPU/NPU compute)
    "ROCM_PATH" = "${pkgs.rocmPackages.rocm-core}";
    "HIP_PATH" = "${pkgs.rocmPackages.hip}";
    
    # Library paths
    "LD_LIBRARY_PATH" = lib.mkDefault [
      "${pkgs.rocmPackages.rocm-runtime}/lib"
      "${pkgs.rocmPackages.hip}/lib"
    ];
  };

  # =============================================================================
  # SHELL ALIASES
  # =============================================================================
  
  environment.shellAliases = {
    "npu-status" = "npu-mon";
    "npu-test" = "npu-bench";
    "npu-load" = "sudo modprobe amdxdna";
    "npu-unload" = "sudo modprobe -r amdxdna";
  };

  # =============================================================================
  # DOCUMENTATION
  # =============================================================================
  
  environment.etc."npu/README.md".text = ''
    # AMD XDNA NPU Configuration
    
    ## Hardware
    - **Device**: AMD Ryzen AI 9 HX 370 (Strix Point)
    - **NPU**: XDNA 2 Architecture
    - **Compute**: ~50 TOPS AI performance
    
    ## Quick Start
    
    ### Check NPU Status
    ```bash
    npu-mon          # Display NPU status
    npu-bench        # Run basic benchmark
    ```
    
    ### Load/Unload Driver
    ```bash
    sudo modprobe amdxdna      # Load driver
    sudo modprobe -r amdxdna   # Unload driver
    ```
    
    ### Device Node
    - Primary: `/dev/accel/accel0`
    - Alternative: `/dev/accel0`
    
    ## Development
    
    ### Using NPU in Applications
    The NPU can be accessed through:
    - **AMD XDNA Driver**: Direct kernel interface
    - **ROCm**: For GPU/NPU unified compute
    - **ONNX Runtime**: For ML inference
    - **Ryzen AI SDK**: For optimized AI workloads
    
    ### Environment Variables
    - `AMD_XDNA_DEVICE`: NPU device path
    - `ROCM_PATH`: ROCm installation path
    
    ## Troubleshooting
    
    ### Driver Not Loading
    ```bash
    # Check kernel messages
    dmesg | grep -i xdna
    
    # Check firmware
    ls /lib/firmware/amdxdna/
    
    # Manual load with debug
    sudo modprobe amdxdna dyndbg=+p
    ```
    
    ### Permission Issues
    ```bash
    # Check device permissions
    ls -la /dev/accel/
    
    # Add user to groups
    sudo usermod -aG accel,render $USER
    ```
    
    ## Resources
    - [AMD Ryzen AI Documentation](https://www.amd.com/en/products/processors/consumer/ryzen-ai.html)
    - [XDNA Driver Source](https://github.com/amd/xdna-driver)
  '';

  # =============================================================================
  # NOTES
  # =============================================================================
  
  # The AMD XDNA driver is still evolving. For latest support:
  # 1. Use linuxPackages_latest or newer
  # 2. Check chaotic nyx for bleeding edge packages
  # 3. Monitor https://github.com/amd/xdna-driver for updates
}
