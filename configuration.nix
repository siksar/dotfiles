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
    ./modules/hardware/tlp.nix

    # Desktop
    ./modules/desktop/sddm.nix
    ./modules/desktop/theme.nix

    # System
    ./modules/networking.nix
    ./modules/locale.nix
    ./modules/audio.nix
    ./modules/users.nix
  ];


  programs.firefox.enable = true;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/etc/nixos";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    gh

    # Rust / Nix / Kubernetes platform engineering
    rustup
    doctl
    kubectl
    kubernetes-helm
    kustomize
    k9s

    # IDE
    jetbrains-toolbox

    # LLM-assisted development
    antigravity
    claude-code
    codex
  ];

  system.stateVersion = "26.05";
}
