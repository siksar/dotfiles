{ config, pkgs, lib, ... }:

let
  zen5Cores = "0-3,8-11";
  zen5cCores = "4-7,12-15";

  withCores = pkgs.writeShellScriptBin "with-cores" ''
    usage() {
      echo "Usage: with-cores [perf|eff] <command>"
      echo "  perf - Zen 5 performance cores (0-3,8-11)"
      echo "  eff  - Zen 5c efficiency cores (4-7,12-15)"
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
    enable = true;
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

  services.power-profiles-daemon.enable = false;
  services.tlp.enable = lib.mkForce false;
  services.thermald.enable = true;

  # NOTE: programs.gamemode is configured in modules/gaming.nix

  environment.shellAliases = {
    "perf-run" = "with-cores perf";
    "eff-run" = "with-cores eff";
  };
}
