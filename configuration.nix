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
    ./modules/hardware/keyboard-rgb/system.nix
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

  # Electron/Chromium uygulamaları native Wayland'de çalışsın (kullanıcı isteği 30 Tem).
  # nixpkgs'in Electron sarmalayıcıları şu kalıbı taşır:
  #   ${NIXOS_OZONE_WL:+ --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}
  # Değişken boşken flag hiç eklenmiyordu → VSCodium/Vesktop/1Password/claude-desktop
  # XWayland'de koşuyordu. İki kazanç: (1) HiDPI'de net render + kesirli ölçekleme,
  # (2) WaylandWindowDecorations sayesinde xdg-decoration konuşuluyor; Hyprland bu
  # protokole DAİMA MODE_SERVER_SIDE cevabı verdiği için uygulama kendi süslemesini
  # çizmiyor — pencerenin tek çerçevesi Hyprland'ın border+rounding'i oluyor.
  #
  # KAPSAM UYARISI: sessionVariables sistem geneli, GNOME oturumunu da etkiler
  # (orada mutter gerçek başlık çubuğu çizer — normal davranış). Uygulamanın KENDİ
  # tasarladığı chrome (VSCodium'un sekme çubuğu, Vesktop'un başlığı) bu flag'le
  # GİTMEZ; o uygulama başına ayardır — VSCodium'unki modules/apps/vscodium.nix'te.
  # GTK/libadwaita başlıkları (nautilus vb.) hiçbir şekilde kaldırılamaz: GtkHeaderBar
  # bir süsleme değil, içinde yol çubuğu/arama/menü taşıyan uygulama arayüzüdür.
  #
  # Regresyon izle: ibus (GTK_IM_MODULE=ibus) Wayland'de text-input-v3'e geçer —
  # Electron uygulamalarında Türkçe/emoji girişini bir teyit et. Ekran paylaşımı
  # portal'a (xdg-desktop-portal) düşer. Bozarsa bu satırı sil, rebuild yeter.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    vim
    git
    gh

    # Masaüstü araçları (ekran görüntüsü GNOME yerleşik: PrintScreen)
    brightnessctl     # CLI parlaklık (script/servisler)
    wl-clipboard      # wl-copy / wl-paste
    pavucontrol       # PulseAudio / PipeWire GUI

    # TUI sistem ayarları (GUI olmadan terminalden bluetooth/wifi/ses)
    bluetuith         # Bluetooth TUI — eşleştirme/bağlan/güven/ses profili (bluez üstünde)
    wiremix           # PipeWire native ses mikseri TUI — pulse uyumluluk katmanı gerekmez
    # WiFi TUI zaten var: nmtui — networking.networkmanager.enable paketi otomatik ekliyor

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
