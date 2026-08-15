# Hyprland oturumu — HM katmanının çekirdeği: pencere yöneticisi + polkit ajanı.
# Bar/launcher/bildirim/kilit/idle/tema artık Caelestia kabuğunda (bkz.
# home/desktop/caelestia/default.nix) — bu dosya yalnız WM'i ve WM'siz kalamayacak
# tek bir polkit ajanını taşır (Caelestia kendi polkit ajanını SAĞLAMIYOR).
#
# Bayrak BURADA tanımlı, her iki modül de aynı `desktop.hyprland.enable`'ı okur.
# Ayrıntı: Documentation/desktop.md · tuzaklar: home/desktop/CLAUDE.md
{ config, lib, pkgs, osConfig ? { }, ... }:

let
  cfg = config.desktop.hyprland;
in
{
  options.desktop.hyprland.enable = lib.mkOption {
    type = lib.types.bool;
    # Gömülü HM: sistemdeki desktop.hyprland.enable'ı osConfig ile izler —
    # tek anahtar configuration.nix'te. Standalone `hms` yolunda osConfig
    # olmadığından varsayılan false; gerekirse home.nix'te elle açılır.
    default = osConfig.desktop.hyprland.enable or false;
    defaultText = lib.literalExpression "osConfig.desktop.hyprland.enable or false";
    description = "Hyprland + Caelestia rice'ının HM katmanı (WM, kabuk, tema motoru)";
  };

  config = lib.mkIf cfg.enable {
    # Stylix'in gtk hedefi gtk.enable=true yapar ama ikon teması ayarlamaz —
    # Stylix'te ayrı bir icons modülü yok. adwaita-icon-theme daha önce
    # GNOME'un systemPackages'ından geliyordu; olmadan tüm GTK diyalogları
    # ikonsuz kalır. (Caelestia kendi ikon temasını — Papirus — kullanır ama
    # GTK dosya seçicisi gibi native diyaloglar hâlâ Adwaita'ya düşebilir.)
    gtk.iconTheme = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
    };

    home.packages = [ pkgs.adwaita-icon-theme ];

    #### Hyprland — tamamen hyprland.lua üzerinden (0.55+ Lua çağı) ####
    wayland.windowManager.hyprland = {
      enable = true;
      package = null; # sistemdeki programs.hyprland paketi (çifte kurulum olmasın)
      portalPackage = null; # portal da sistemden
      configType = "lua"; # ~/.config/hypr/hyprland.lua üretilir
      systemd.enable = true; # hyprland-session.target — aşağıdaki servisler buna bağlanır
      # `settings` attrset'i YERİNE saf Lua dosyaları: hem HM'nin attrset→Lua
      # çevirisindeki emekleme dönemi sorunlarından kaçınır (HM #9468) hem de
      # config gerçek Lua olarak okunur/düzenlenir. hyprland.lua bunları
      # otomatik require eder (alfabetik: autostart, binds, main, rules, theme).
      # autostart.lua kaldırıldı (30 Tem→09 Ağu): yalnız ölü `theme-apply --restore`
      # çağrısını taşıyordu. Caelestia son şemayı ~/.local/state/caelestia/
      # altında kalıcı tutuyor — reboot sonrası theme.lua dosyayı doğrudan taze
      # okuyor, ayrı bir restore adımı gerekmiyor.
      extraLuaFiles = {
        binds = ./wm/binds.lua;
        main = ./wm/main.lua;
        rules = ./wm/rules.lua;
        theme = ./wm/theme.lua;
      };
    };

    #### Polkit GUI ajanı — Caelestia kendi ajanını SAĞLAMIYOR, bu KALMALI ####
    # Repoda hiç polkit ajanı yok — GNOME'un gnome-shell'e gömülü ajanı bugüne
    # kadar bunu sağlıyordu. Ajan olmadan 1Password'ün "sistem kimlik
    # doğrulaması", Mullvad ve fan-mode dışındaki her polkit isteği sessizce
    # reddedilir (polkit daemon'ın kendisi networkmanager.nix'ten geliyor,
    # yalnız GUI onay penceresi eksikti).
    systemd.user.services.hyprpolkitagent = {
      Unit = {
        Description = "Hyprland polkit kimlik doğrulama ajanı";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };
  };
}
