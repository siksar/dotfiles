{ config, pkgs, ... }:

{
  boot = {
    # Bootloader Configuration
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Limit build generations in menu
        consoleMode = "max";     # Best resolution for boot menu
      };
      efi.canTouchEfiVariables = true;
      timeout = 2; # Brief timeout to select generation if needed
    };

    # 🎬 Boot & Shutdown Animation (Plymouth)
    plymouth = {
      enable = true;
      theme = pkgs.lib.mkForce "bgrt"; # Forces "bgrt" over Stylix's auto-config
      # Alternative themes: "spinner", "script", "fade-in"
    };

    # 🤫 Silent Boot Parameters (Essential for clean animation)
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_priority=3"
      "udev.log_priority=3"
    ];
  };
}
