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
    ./modules/hardware/gaming.nix
    ./modules/hardware/acpi-override.nix

    # Desktop
    ./modules/desktop/gnome.nix
    ./modules/desktop/stylix.nix
    ./modules/desktop/firefox.nix

    # Uygulamalar
    ./modules/apps/default.nix
    ./modules/apps/local-ai.nix

    # System
    ./modules/networking.nix
    ./modules/locale.nix
    ./modules/audio.nix
    ./modules/users.nix
  ];


  # HM dconf ayarları (GNOME kısayolları, gnome-hm.nix) için gerekli
  programs.dconf.enable = true;

  # JetBrainsMono Nerd Font (terminal/starship glif ikonları)
  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/zixar/nixos-zixar";
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

    # Masaüstü araçları (ekran görüntüsü GNOME yerleşik: PrintScreen)
    brightnessctl     # CLI parlaklık (script/servisler)
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
    opencode
  ];

  system.stateVersion = "26.05";
}
