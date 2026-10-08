{ lib, pkgs, osConfig ? { }, ... }:

let
  enabled = osConfig.desktop.hyprland.enable or false;

  # UWSM hedef adı oturum dosyası kimliğinden türer: wayland-session@hyprland.desktop.target
  sessionTarget = "wayland-session@hyprland.desktop.target";

  scripts = import ./scripts.nix { inherit pkgs; };

  hyprglass = pkgs.callPackage ./hyprglass.nix {
    inherit (pkgs.hyprlandPlugins) mkHyprlandPlugin;
    hyprland = osConfig.programs.hyprland.package or pkgs.hyprland;
  };

  # Betikler PATH'te değil; Lua store yollarını bu tablodan alır.
  luaPaths = {
    files       = lib.getExe pkgs.nautilus;
    notify      = lib.getExe' pkgs.libnotify "notify-send";
    playerctl   = lib.getExe pkgs.playerctl;
    colorPicker = "${lib.getExe pkgs.hyprpicker} --autocopy --format=hex";
    osd         = lib.getExe scripts.osd;
    screenshot  = lib.getExe scripts.screenshot;
    nightLight  = lib.getExe scripts.nightLight;
    dnd         = lib.getExe scripts.dnd;
  };
in
{
  imports = [
    ./bar.nix
    ./session.nix
  ];

  config = lib.mkIf enabled {
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      portalPackage = null;

      # Açık yaz: stateVersion kayması sessizce hyprlang'e çevirmesin.
      configType = "lua";

      plugins = [ hyprglass ];

      # HM'in hyprland-session.target'ı KAPALI: UWSM ile birlikteyken stop'u compositor'ı indirir.
      systemd.enable = false;

      # Lua dosyaları readFile ile gömülü → lua/ adları serbest. Alfabetik require edilir.
      extraLuaFiles = {
        binds = builtins.readFile ./lua/binds.lua;
        look = builtins.readFile ./lua/look.lua;
        main = builtins.readFile ./lua/main.lua;
        rules = builtins.readFile ./lua/rules.lua;
        voice = builtins.readFile ./lua/voice.lua;

        nixpaths = {
          autoLoad = false;
          content = ''
            -- Home Manager üretti (home/desktop/hyprland/default.nix, luaPaths).
            return {
            ${lib.concatStrings (lib.mapAttrsToList (n: v: "  ${n} = ${builtins.toJSON v},\n") luaPaths)}}
          '';
        };
      };
    };

    # Ghostty zemini yalnız Hyprland'de saydam (hyprglass camı): isteğe bağlı ek config
    # runtime dizininde, yalnız bu oturumda var.
    programs.ghostty.settings.config-file = "?/run/user/1000/ghostty-hyprland";

    systemd.user.services.ghostty-glass = {
      Unit = {
        Description = "ghostty saydam zemin (yalnız Hyprland oturumu, hyprglass)";
        PartOf = [ sessionTarget ];
        Before = [ sessionTarget ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c 'printf \"background-opacity = 0.4\\nbackground-opacity-cells = true\\n\" > %t/ghostty-hyprland'";
        ExecStop = "${pkgs.coreutils}/bin/rm -f %t/ghostty-hyprland";
      };
      Install.WantedBy = [ sessionTarget ];
    };

    # Karantina: tüm HM Wayland servisleri yalnız UWSM'in Hyprland hedefine bağlanır
    # (graphical-session.target GNOME/COSMIC'te de etkin).
    wayland.systemd.target = sessionTarget;

    # UWSM ortamı yalnız Hyprland'de okunur; oturuma özel env buraya, sessionVariables'a değil.
    xdg.configFile."uwsm/env-hyprland".text = ''
      # Qt uygulamaları Wayland'de; XWayland yedek.
      export QT_QPA_PLATFORM="wayland;xcb"
      # Electron: NIXOS_OZONE_WL sistemde zaten var; bu, nixpkgs sarmalayıcısı
      # olmayan ikililer için (AppImage'lar, github-copilot).
      export ELECTRON_OZONE_PLATFORM_HINT=auto
      # SDL_VIDEODRIVER BİLEREK YOK: eski SDL2 (<2.0.22) virgüllü listeyi tanımaz
      # ve görüntüyü hiç açamaz — Steam'in yerel Linux oyunları bundan etkilenir.
    '';
  };
}
