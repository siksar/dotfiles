{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    ./hardware-configuration.nix

    # Boot
    ./modules/boot/limine.nix

    # Hardware
    ./modules/hardware/gpu.nix
    ./modules/hardware/power.nix
    ./modules/hardware/tlp.nix
    ./modules/hardware/gigabyte-wmi.nix

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

  # Hyprland — iGPU-only Wayland compositor (SDDM session + UWSM desteği)
  programs.hyprland = {
    enable   = true;
    withUWSM = true;
  };

  # Waybar için JetBrainsMono Nerd Font (pil/ağ ikonları)
  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

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

    # Hyprland araçları
    rofi              # uygulama başlatıcı (SUPER+SPACE)
    brightnessctl     # klavye kısayoluyla parlaklık
    grim              # Wayland ekran görüntüsü
    slurp             # alan seçici (grim ile)
    wl-clipboard      # wl-copy / wl-paste
    pavucontrol       # PulseAudio / PipeWire GUI

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
