{ config, pkgs, ... }:
{
	# ========================================================================
	# NETWORKING CONFIGURATION
	# ========================================================================
  
	networking = {
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
		settings.Resolve = {
			DNSSEC = "false";
			Domains = [ "~." ];
			FallbackDNS = [ "8.8.8.8" "8.8.4.4" ];
		};
	};
}
