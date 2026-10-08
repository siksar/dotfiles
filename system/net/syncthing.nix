# Syncthing HM kullanıcı servisi (home/apps/syncthing.nix) → portlar elle.
_:

{
  networking.firewall = {
    allowedTCPPorts = [ 22000 ];
    allowedUDPPorts = [
      22000
      21027
    ];
  };
}
