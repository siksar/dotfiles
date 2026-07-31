# SwayNC — bildirim merkezi. Renk sahibi matugen (swaync-colors.css).
#
# HM modülü unit'i generic graphical-session.target'a bağlar; aşağıdaki
# mkForce onu hyprland-session.target'a daraltır — servis yalnız bu oturumda
# koşsun diye (bare TTY / ileride ikinci bir compositor senaryosu).
{ config, lib, ... }:

let
  cfg = config.desktop.hyprland;
  cfgHome = config.xdg.configHome;
in
{
  config = lib.mkIf cfg.enable {
    #### SwayNC ####
    services.swaync = {
      enable = true;
      settings = {
        positionX = "right";
        positionY = "top";
        control-center-width = 400;
        notification-window-width = 400;
      };
      style = ''
        @import "${cfgHome}/swaync/colors.css";
      '' + builtins.readFile ./swaync-style.css;
    };
    # swaync yalnız Hyprland oturumunda çalışsın (HM modülü generic
    # graphical-session.target'a bağlar → mkForce ile daralt)
    systemd.user.services.swaync.Install.WantedBy =
      lib.mkForce [ "hyprland-session.target" ];
  };
}
