# Hibrit çekirdek: boot/pil maskesi Zen5c (1,3,5,7 + SMT 9,11,13,15). Fişte power-display.nix
# maskeyi 0-15'e açar ama scaling_max_freq'i 4.5 GHz'e kapar. sched_setaffinity (AllowedCPUs
# değil): gamerun'ın taskset kaçışı mümkün kalsın.
{ ... }:

{
  systemd.settings.Manager.CPUAffinity = "1,3,5,7,9,11,13,15";

  # nix-daemon muaf: derlemeler 16 CPU'yu kullanır, ama SCHED_BATCH + düşük G/Ç ile oturumla yarışmaz.
  systemd.services.nix-daemon.serviceConfig.CPUAffinity = "0-15";

  nix.daemonCPUSchedPolicy = "batch";
  nix.daemonIOSchedClass = "best-effort";
  nix.daemonIOSchedPriority = 7;
}
