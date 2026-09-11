# AERO X16 kontrol uygulaması — yerel checkout'taki GUI için masaüstü başlatıcısı.
#
# Uygulamanın çalıştırılması `run.sh` üzerinden yapılır: libcosmic/winit'in
# çalışma zamanında ihtiyaç duyduğu Wayland kütüphanelerini .gcroots/gui-env
# üzerinden sağlar ve gerekirse bu ortamı kurar. GUI'nin Nix paketi ayrı bir
# çalışma koludur; libcosmic git bağımlılığı için hash tamamlanana kadar burada
# yerel, ölçülmüş çalışma yolu kullanılır.
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

  # COSMIC launcher system profilindeki XDG uygulama dizinini tarar; /etc/xdg
  # yapılandırma dizini uygulama kataloğu değildir.
  environment.pathsToLink = [ "/share/applications" ];
}
