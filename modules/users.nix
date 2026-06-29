{ pkgs, ... }:

{
  users.users.zixar = {
    isNormalUser = true;
    description  = "zixar";
    extraGroups  = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
      bitwarden-desktop
    ];
  };
}
