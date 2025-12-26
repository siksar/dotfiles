{ config, pkgs, ... }:

{
  # ========================================================================
  # NETWORKING CONFIGURATION
  # ========================================================================
  
  networking = {
    hostName = "nixos";
    
    networkmanager = {
      enable = true;
      wifi.powersave = false;  # Disable for lower latency
    };
    
    # Firewall configuration
    firewall = {
      enable = true;
      
      # Gaming ports (Steam, Discord, etc.)
      allowedTCPPorts = [ 
        # Steam
        27015 27036
        # Discord Voice (uncomment if needed)
        # 50000-65535
      ];
      
      allowedUDPPorts = [
        # Steam
        27015 27031 27036
        # Discord Voice (uncomment if needed)
        # 50000-65535
      ];
      
      # Allow specific services
      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = [ ];
    };
  };

  # DNS optimization
  services.resolved = {
    enable = true;
    dnssec = "false";  # Some routers don't support DNSSEC
    extraConfig = ''
      DNS=1.1.1.1 1.0.0.1
      FallbackDNS=8.8.8.8 8.8.4.4
    '';
  };
}
