{ config, pkgs, lib, ... }:

let
	# Ryzen AI 7 350 (Krackan Point) - 8 Cores / 16 Threads
	# Topology: Interleaved (P-E-P-E-P-E-P-E)
	# Cores: 0, 2, 4, 6 (Zen 5 Perf) -> SMT: 8, 10, 12, 14
	# Cores: 1, 3, 5, 7 (Zen 5c Eff)  -> SMT: 9, 11, 13, 15
	zen5Cores = "0,2,4,6,8,10,12,14";
	zen5cCores = "1,3,5,7,9,11,13,15";

	withCores = pkgs.writeShellScriptBin "with-cores" ''
		usage() {
			echo "Usage: with-cores [perf|eff] <command>"
			echo "  perf - Zen 5 performance cores (0,2,4,6 + SMT)"
			echo "  eff  - Zen 5c efficiency cores (1,3,5,7 + SMT)"
			exit 1
		}
		[ $# -lt 2 ] && usage
		MODE="$1"; shift
		case "$MODE" in
			perf) exec taskset -c ${zen5Cores} "$@" ;;
			eff)  exec taskset -c ${zen5cCores} "$@" ;;
			*) usage ;;
		esac
	'';
in
{
	environment.systemPackages = [ withCores ];

	services.auto-cpufreq = {
		enable = false; # Disabled in favor of PPD
		settings = {
			charger = {
				governor = "performance";
				energy_performance_preference = "performance";
				scaling_min_freq = 800000;
				scaling_max_freq = 5100000;
				turbo = "auto";
			};
			battery = {
				governor = "powersave";
				energy_performance_preference = "power";
				scaling_min_freq = 400000;
				scaling_max_freq = 2000000;
				turbo = "auto";
				enable_thresholds = true;
				start_threshold = 40;
				stop_threshold = 80;
			};
		};
	};

	# services.power-profiles-daemon.enable = false; # Removed to allow PPD from power-management.nix
	services.tlp.enable = lib.mkForce false;
	services.thermald.enable = true;

	# NOTE: programs.gamemode is configured in modules/gaming.nix

	environment.shellAliases = {
		"perf-run" = "with-cores perf";
		"eff-run" = "with-cores eff";
	};


}
