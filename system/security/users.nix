{ pkgs, ... }:

{
  programs.fish.enable = true;

  users.users.zixar = {
    isNormalUser = true;
    description  = "zixar";
    extraGroups  = [ "networkmanager" "wheel" ];
    shell        = pkgs.fish;
    packages = with pkgs; [
      bitwarden-desktop
      nautilus
    ];

  };
}
