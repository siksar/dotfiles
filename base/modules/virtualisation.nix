{ config, pkgs, lib, ... }:

{
  # ========================================================================
  # VIRTUALIZATION & GPU PASSTHROUGH
  # ========================================================================
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;

    };
    onBoot = "ignore";
    onShutdown = "shutdown";
  };

  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    virt-manager
    qemu
    looking-glass-client
    
    # Helper script to start VM with Looking Glass
    (pkgs.writeShellScriptBin "launch-void-vm" ''
       # Start the VM if not running
       if ! sudo virsh list --state-running | grep -q "void-linux"; then
         sudo virsh start void-linux
         sleep 5 # Wait for VM to init
       fi
       # Launch Looking Glass
       looking-glass-client -F
    '')
  ];

  # Looking Glass Shared Memory
  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 zixar kvm -"
  ];
  
  # Enable IOMMU by default (doesn't hurt performance much, needed for mapping)
  boot.kernelParams = [ "amd_iommu=on" "iommu=pt" ];

  # ========================================================================
  # VM GAMING MODE (GPU PASSTHROUGH)
  # ========================================================================
  # Boot into this mode to give the RTX 5060 to the VM completely.
  # Host will use AMD Radeon 860M (iGPU).
  specialisation."vm-gaming".configuration = {
    system.nixos.tags = [ "vm-gaming" ];

    # Isolate GPU for VFIO
    boot.kernelParams = [ 
      "vfio-pci.ids=10de:2d19,10de:22eb" 
    ];
    
    # Disable Host NVIDIA Drivers
    hardware.nvidia.modesetting.enable = lib.mkForce false;
    hardware.nvidia.powerManagement.enable = lib.mkForce false;
    services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];
    
    # Blacklist nvidia modules to ensure vfio-pci grabs it
    boot.blacklistedKernelModules = [ "nvidia" "nvidia_drm" "nvidia_modeset" ];
    
    # Auto-start VM service
    systemd.services.start-void-vm-at-boot = {
      description = "Auto-start Void Linux VM";
      after = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.libvirt}/bin/virsh start void-linux";
      };
    };
  };
}
