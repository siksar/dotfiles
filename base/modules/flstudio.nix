{ config, pkgs, lib, ... }:  # lib eklendi!
{
	# ════════════════════════════════════════════════════════════════
	# WINE / BOTTLES FIX
	# ════════════════════════════════════════════════════════════════
  
	security.pam.loginLimits = [
		{
			domain = "*";
			type = "soft";
			item = "nice";
			value = "-20";
		}
		{
			domain = "*";
			type = "hard";
			item = "nice";
			value = "-20";
		}
		{
			domain = "*";
			type = "soft";
			item = "rtprio";
			value = "99";
		}
		{
			domain = "*";
			type = "hard";
			item = "rtprio";
			value = "99";
		}
	];

	security.rtkit.enable = true;

	services.pipewire = {
		enable = true;
		alsa.enable = true;
		alsa.support32Bit = true;
		pulse.enable = true;
		jack.enable = true;
	};

	hardware.graphics = {
		enable = true;
		enable32Bit = true;
	};

	# CPU Governor audio için
	powerManagement.cpuFreqGovernor = lib.mkForce "performance";
}
