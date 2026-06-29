{ ... }:

{
  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    wifi.backend = "iwd";
  };
  networking.modemmanager.enable = false;
}
