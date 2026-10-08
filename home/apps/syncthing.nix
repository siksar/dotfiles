# ~/StreamripDownloads → telefon. Laptop sendonly, telefon receiveonly.
# Klasör/cihaz bildirimsel: HM her başlangıçta REST ile POST eder, GUI'deki paylaşım silinir.
# Portlar system/net/syncthing.nix'te.
_:

{
  services.syncthing = {
    enable = true;
    overrideDevices = false;
    overrideFolders = false;
    settings = {
      options = {
        urAccepted = -1;
        crashReportingEnabled = false;
      };

      devices.telefon.id = "ZOOAH5A-LIZDSPT-MHS6Z2D-XAJZ7JE-NCEOZYW-44Q7V2V-U5P7HQY-UZ4NHQ5";

      folders.muzik = {
        label = "Müzik";
        path = "~/StreamripDownloads";
        type = "sendonly";
        devices = [ "telefon" ];
        fsWatcherEnabled = true;
        rescanIntervalS = 86400;
      };
    };
  };

  systemd.user.services.syncthing.Service = {
    Nice = 19;
    IOSchedulingClass = "idle";
  };
}
