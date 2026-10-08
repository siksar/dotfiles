# Hyprland — yalnız sistem katmanı (compositor + UWSM + hyprlock PAM + DRM seçimi); HM: home/desktop/hyprland/.
# Greeter'da doğru girdi "Hyprland (uwsm-managed)"; düz girdide HM servisleri gelmez.
{ config, lib, ... }:

let
  cfg = config.desktop.hyprland;
in
{
  options.desktop.hyprland.enable = lib.mkEnableOption
    "Hyprland — karantinali ucuncu oturum (UWSM, Lua config)";

  config = lib.mkIf cfg.enable {
    # enableWlrPortal = false: global wlr portalı Hyprland ScreenCast isteklerini kapabiliyor.
    programs.hyprland = {
      enable = true;
      withUWSM = true;
    };

    # hyprlock PAM servisi şart; yoksa kilit parolayı hiç kabul etmez.
    programs.hyprlock.enable = true;

    # Modülün sistem hypridle'ı KAPALI: wants-symlink'i GNOME/COSMIC/GDM'e sızıyordu. Tek sahibi HM (session.nix).
    services.hypridle.enable = lib.mkForce false;

    # AQ_DRM_DEVICES: ':' ile bölünür, her parça DOSYA YOLU → iki nokta içermeyen udev symlink'leri.
    # İlk kart birincil (render) = iGPU. hl.env geç kalır (aquamarine config'ten önce kurulur).
    # DÜZ ATAMA: mux.nix mkForce ile ezer.
    environment.sessionVariables.AQ_DRM_DEVICES =
      if config.desktop.externalDisplay.enable then
        "/dev/dri/hypr-igpu:/dev/dri/hypr-dgpu"
      else
        "/dev/dri/hypr-igpu";

    # card0 → nvidia (10de:2d19), card1 → amdgpu (1002:1114); DRIVERS ile eşleş, numara kayar.
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="amdgpu", SYMLINK+="dri/hypr-igpu"
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DRIVERS=="nvidia", SYMLINK+="dri/hypr-dgpu"
    '';
  };
}
