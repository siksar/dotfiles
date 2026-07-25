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
    ./modules/hardware/power-display.nix
    ./modules/hardware/gigabyte-wmi.nix
    ./modules/hardware/gaming.nix
    ./modules/hardware/acpi-override.nix

    # Desktop
    ./modules/desktop/gnome.nix
    ./modules/desktop/ly.nix
    ./modules/desktop/stylix.nix
    ./modules/desktop/firefox.nix
    ./modules/desktop/hyprland-rice/system.nix
    ./modules/desktop/sway-rice/system.nix

    # Uygulamalar
    ./modules/apps/default.nix
    ./modules/apps/local-ai.nix
    ./modules/apps/onepassword.nix

    # System
    ./modules/networking.nix
    ./modules/locale.nix
    ./modules/audio.nix
    ./modules/users.nix
  ];


  # Hyprland + Matugen dinamik tema rice'ı (GNOME'a ek, GDM'de 2. oturum).
  # Açmak için yorum işaretini kaldır — HM tarafı osConfig ile otomatik izler.
  # Ayrıntı: docs/hyprland-rice.md
   rice.hyprland.enable = true;

  # Sway + noctalia-shell rice'ı (GNOME'a ek, ly'de 3. oturum, Hyprland rice'ından
  # bağımsız). HM tarafı osConfig ile otomatik izler. Ayrıntı: docs/sway-rice.md
  rice.sway.enable = true;

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

    # Ağ araçları (power-display WiFi PS servisi iw'yi kullanır + tanılama)
    iw                # regdomain/power_save sorgu-set (iw reg get, iw dev ... get power_save)
    ethtool           # Ethernet tanılama (link/ring/WoL)

    # Rust / Nix / Kubernetes platform engineering
    rustup
    doctl
    kubectl
    kubernetes-helm
    kustomize
    k9s

    # Nix lint/format — ölçülen marjinal closure +10.2 MiB (deadnix 1.5 / nixfmt 5.1 /
    # statix 3.6; bağımlılıklarının geri kalanı sistemde zaten vardı).
    # `nix run nixpkgs#...` ile ölçmek yanıltır: o registry'nin nixpkgs'ini çözer,
    # flake pin'ini değil — gerçek rakam `nix store diff-closures /run/current-system
    # ./result`. Hiçbiri boşta çalışmaz, idle bütçesine dokunmaz.
    # Kullanım + statix'in bu repoda neden filtre gerektirdiği: CLAUDE.md
    # "Lint / inspection tooling".
    deadnix           # kullanılmayan let-binding / lambda argümanı
    statix            # anti-pattern linter — statix.toml OLMADAN çalıştırma
    nixfmt-rfc-style  # resmi formatter — ağaç geneli çalıştırma, hizalamayı bozar

    # LLM-assisted development
    claude-code
    codex
    opencode
  ];

  system.stateVersion = "26.05";
}
