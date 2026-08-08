{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports = [
    ./hardware-configuration.nix

    # ══ system/ — makinenin tesisatı ═══════════════════════════════════════
    # arch/ — YALNIZ bu donanımda anlamlı, taşınamaz (EC/WMI, DSDT override).
    # Başka bir makineye geçilirse ilk silinecek dizin burasıdır.
    ./system/arch/aerox16/wmi.nix
    ./system/arch/aerox16/acpi.nix

    # drivers/ — aygıt sürücüleri ve aygıt-başı ayar
    ./system/drivers/gpu.nix
    ./system/drivers/input/keyboard-rgb/system.nix

    # kernel/ — çekirdek davranışı: güç, zamanlayıcı, bellek
    ./system/kernel/power.nix
    ./system/kernel/power-display.nix
    ./system/kernel/sched.nix

    # init/ — önyükleyici ve yerel ayar
    ./system/init/limine.nix
    ./system/init/locale.nix

    # net/ — ağ yığını, VPN (devre dışı), sansür aşma (DPI bypass + DoH),
    #        yerel paylaşım
    ./system/net/core.nix
    ./system/net/vpn.nix
    ./system/net/censorship.nix
    ./system/net/localsend.nix

    ./system/sound.nix
    ./system/virt.nix

    # security/ — hesaplar, anahtarlık, parola yöneticisi
    ./system/security/users.nix
    ./system/security/keyring.nix
    ./system/security/onepassword.nix

    # desktop/ — oturum katmanı (Hyprland + ly + Stylix)
    ./system/desktop/session.nix
    ./system/desktop/login.nix
    ./system/desktop/theme.nix

    # ══ usr/ — sistem geneli kurulan programlar ════════════════════════════
    ./usr/steam.nix
    ./usr/netflix.nix
    ./usr/firefox.nix
    ./usr/local-ai.nix
  ];


  # Hyprland + Matugen dinamik tema rice'ı — tek oturum (GNOME + Sway kaldırıldı,
  # 2026-07-30). Bayrak güvenlik valfi olarak kalıyor; kapatmak sistemi Hyprland'siz
  # bırakır (ly'de başka oturum yok). HM tarafı osConfig ile otomatik izler.
  # Ayrıntı: Documentation/desktop.md
  desktop.hyprland.enable = true;

  # hyprland paketi hem "hyprland.desktop" hem "hyprland-uwsm.desktop" oturum
  # dosyasını kurar; yalnız uwsm olanı bu makinede çalışıyor (withUWSM=true,
  # bkz. system/desktop/session.nix). Tek oturum kalınca ly listesinde ikisi yan
  # yana durur — defaultSession yanlış olanı seçmeyi zorlaştırır.
  services.displayManager.defaultSession = "hyprland-uwsm";

  # Stylix'in GTK hedefi + HM'in gtk.iconTheme/dconf.settings ayarları için gerekli
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
  # KAPSAM UYARISI: sessionVariables sistem geneli. Uygulamanın KENDİ tasarladığı
  # chrome (VSCodium'un sekme çubuğu, Vesktop'un başlığı) bu flag'le GİTMEZ; o
  # uygulama başına ayardır — VSCodium'unki home/apps/vscodium.nix'te.
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

    # Masaüstü araçları (ekran görüntüsü: home/desktop/session.nix'in hypr-screenshot'ı, Print)
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
    nixfmt            # resmi formatter (eski ad nixfmt-rfc-style artık aynı türeve
                      # çözülüyor ve uyarı veriyor) — ağaç geneli ÇALIŞTIRMA,
                      # elle hizalanmış yorum sütunlarını bozar

    # LLM-assisted development
    claude-code
    codex
    opencode

    # DualSense (PS5) / DualShock4 (PS4) controller CLI — LED/şarj/trigger okuma,
    # USB pairing modu. On-demand CLI; daemon DEĞİL → idle 4.28W bütçesine dokunmaz.
    # Emülatör controller desteği (hidapi/evdev/SDL3) home/apps/emu.nix'te.
    dualsensectl
  ];

  system.stateVersion = "26.05";
}
