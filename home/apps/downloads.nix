# Varia (aria2: çoklu bağlantı) + qBittorrent. Servis yok: pencere kapanınca durur.
{ pkgs, ... }:

{
  # Varia aria2'yi kendi kapanışında getirir; `aria2c` PATH'te değil.
  home.packages = [
    pkgs.varia
    pkgs.qbittorrent
  ];

  # .desktop DBusActivatable; paketin servis dosyası göreli `Exec=varia` → 203/EXEC.
  # XDG_DATA_HOME'daki aynı adlı dosya tam yolla gölgeler.
  xdg.dataFile."dbus-1/services/io.github.giantpinkrobots.varia.service".text = ''
    [D-BUS Service]
    Name=io.github.giantpinkrobots.varia
    Exec=${pkgs.varia}/bin/varia
  '';
}
