{ config, pkgs, lib, ... }:
{
	# ========================================================================
	# FASTFETCH - Fast System Information Tool
	# ========================================================================
	
	programs.fastfetch = {
		enable = true;

		settings = {
			logo = {
				# Miasma Orange for NixOS Logo
				color = {
					"1" = "38;2;187;119;68"; # #bb7744
					"2" = "38;2;187;119;68"; # #bb7744
				};
			};

			display = {
				separator = " ➜  ";
				# Miasma Brown/Copper for Key Icons
				color = {
					keys = "38;2;179;109;67"; # #b36d43
					title = "38;2;187;119;68"; # #bb7744 (Title Orange)
				};
			};

			modules = [
				{
					type = "title";
					color = {
						user = "38;2;187;119;68"; # Orange
						at = "38;2;179;109;67";    # Brown
						host = "38;2;187;119;68";  # Orange
					};
				}
				{
					type = "separator";
					string = "─";
				}
				{
					type = "os";
					key = " OS";
				}
				{
					type = "host";
					key = "󰌢 Host";
				}
				{
					type = "kernel";
					key = " Kernel";
				}
				{
					type = "uptime";
					key = "󰅐 Uptime";
				}
				{
					type = "packages";
					key = "󰏖 Packages";
				}
				{
					type = "shell";
					key = " Shell";
				}
				{
					type = "wm";
					key = " WM";
				}
				{
					type = "terminal";
					key = " Terminal";
				}
				{
					type = "terminalfont";
					key = " Font";
				}
				{
					type = "cpu";
					key = " CPU";
				}
				{
					type = "gpu";
					key = "󰢮 GPU";
					hideType = "integrated";
				}
				{
					type = "memory";
					key = "󰍛 Memory";
				}
				{
					type = "disk";
					key = "󰋊 Disk";
					folders = "/";
				}
				{
					type = "battery";
					key = "󰁹 Battery";
				}
				{
					type = "separator";
					string = "─";
				}
				{
					type = "colors";
					paddingLeft = 2;
					symbol = "circle";
				}
			];
		};
	};
}
