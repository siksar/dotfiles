{ pkgs, ... }:

let
  # claude-code pini: Opus 5.5 için 2.1.280+ gerekli, nixpkgs geride. Manifestten yalnız
  # version + linux-x64 binary/checksum okunur. GEÇİCİ: nixpkgs yetişince sil
  # (nix eval --raw github:nixos/nixpkgs/nixos-unstable#claude-code.version).
  claude-code-280 = pkgs.claude-code.override {
    manifest = {
      version = "2.1.280";
      platforms.linux-x64 = {
        binary = "claude.zst";
        checksum = "27910e2ae704d8f2e8024897d8fdf1e7710807baf4f6982c0e3797c058315384";
      };
    };
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./system/nix.nix

    ./system/arch/aerox16/wmi.nix
    ./system/arch/aerox16/acpi.nix
    ./system/arch/aerox16/fn-keys.nix

    ./system/drivers/gpu.nix
    ./system/drivers/input/keyboard-rgb/system.nix
    ./system/drivers/input/openrgb.nix
    ./system/drivers/usb-dac.nix
    ./system/drivers/firmware.nix

    ./system/kernel/power.nix
    ./system/kernel/power-display.nix
    ./system/kernel/sched.nix
    ./system/kernel/cores.nix
    ./system/kernel/ryzen-smu.nix
    ./system/kernel/memory.nix

    ./system/init/limine.nix
    ./system/init/locale.nix

    ./system/net/core.nix
    ./system/net/vpn.nix
    ./system/net/censorship.nix
    ./system/net/localsend.nix
    ./system/net/syncthing.nix
    ./system/net/geoclue.nix

    ./system/sound.nix
    ./system/virt.nix

    ./system/security/users.nix
    ./system/security/keyring.nix
    ./system/security/askpass.nix
    ./system/security/onepassword.nix

    ./system/desktop/login.nix
    ./system/desktop/theme.nix
    ./system/desktop/gnome.nix
    ./system/desktop/cosmic.nix
    ./system/desktop/hyprland.nix
    ./system/desktop/mux.nix
    ./system/desktop/external-display.nix

    ./usr/steam.nix
    ./usr/netflix.nix
    ./usr/github-copilot.nix
    ./usr/claude-desktop.nix
    ./usr/aero-eg61h.nix
  ];


  desktop.gnome.enable = true;
  desktop.cosmic.enable = true;
  desktop.hyprland.enable = true;

  # HDMI portu muxsuz, doğrudan dGPU'ya bağlı.
  desktop.externalDisplay.enable = true;
  services.displayManager.defaultSession = "gnome";

  programs.dconf.enable = true;

  fonts.packages = with pkgs; [ nerd-fonts.jetbrains-mono ];

  # Electron/Chromium native Wayland. ibus Türkçe girişi / ekran paylaşımı bozulursa sil.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    vim
    git
    gh

    brightnessctl
    wl-clipboard
    pavucontrol

    bluetuith
    wiremix

    iw
    ethtool

    rustup
    deadnix
    statix
    nixfmt  # ağaç geneli çalıştırma: hizalı yorumları bozar
    jq

    claude-code-280
    codex
    opencode

    dualsensectl
  ];

  system.stateVersion = "26.05";
}
