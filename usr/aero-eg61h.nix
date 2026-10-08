# AERO X16 kontrol uygulaması (yerel checkout) başlatıcısı; run.sh Wayland kütüphanelerini sağlar.
{ pkgs, ... }:

let
  aeroControl = pkgs.writeShellApplication {
    name = "aero-control";
    runtimeInputs = [ pkgs.coreutils pkgs.nix ];
    text = ''
      exec /home/zixar/aero-eg61h/app/run.sh "$@"
    '';
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "aero-control";
    desktopName = "AERO Kontrol";
    comment = "Gigabyte AERO X16 güç, fan ve performans kontrolü";
    exec = "aero-control %U";
    categories = [ "Settings" "HardwareSettings" ];
    keywords = [ "AERO" "fan" "power" "battery" "thermal" ];
    terminal = false;
  };
in
{
  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "aero-control";
      paths = [ aeroControl desktopItem ];
      meta = {
        description = "Gigabyte AERO X16 control application";
        mainProgram = "aero-control";
        platforms = [ "x86_64-linux" ];
      };
    })
  ];

  # /share/applications pathsToLink'te: xdg.menus (varsayılan açık) zaten ekliyor.
}
