{ config, pkgs, ... }:
{
  # ========================================================================
  # NETWORKING CONFIGURATION
  # ========================================================================
  
  networking = {
    hostName = "nixos";
    
    networkmanager = {
      enable = true;
      wifi.powersave = false;
    };
    
    
    # DNS Servers (Cloudflare)
    nameservers = [ "1.1.1.1" "1.0.0.1" ];

    firewall = {
      enable = true;
      allowedTCPPorts = [ 27015 27036 ];
      allowedUDPPorts = [ 27015 27031 27036 ];
      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = [ ];
    };

    # Bluetooth

  };

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Blueman Applet
  services.blueman.enable = true;

  # Systemd-resolved
  services.resolved = {
    enable = true;
    dnssec = "false";
    domains = [ "~." ];
    fallbackDns = [ "8.8.8.8" "8.8.4.4" ];
  };
}
