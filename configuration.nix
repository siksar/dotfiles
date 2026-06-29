{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    ./hardware-configuration.nix

    # Boot
    ./modules/boot/limine.nix
    ./modules/boot/plymouth.nix

    # Hardware
    ./modules/hardware/gpu.nix
    ./modules/hardware/power.nix

    # Desktop
    ./modules/desktop/sddm.nix
    ./modules/desktop/theme.nix
    ./modules/desktop/hyprland/utils.nix

    # System
    ./modules/networking.nix
    ./modules/locale.nix
    ./modules/audio.nix
    ./modules/users.nix
  ];

  # Hyprland sistem seviyesi (UWSM session entry dahil)
  programs.hyprland = {
    enable   = true;
    withUWSM = true;
  };

  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    antigravity
  ];

  system.stateVersion = "26.05";
}
