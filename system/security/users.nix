{ pkgs, ... }:

{
  # fish — eskiden sway rice'ın parçasıydı (30 Tem'de silindi), tek oturum
  # kalınca sistem katmanına taşındı. HM tarafındaki abbr/alias/function seti
  # home/shell/fish.nix'te (artık koşulsuz).
  programs.fish.enable = true;

  users.users.zixar = {
    isNormalUser = true;
    description  = "zixar";
    extraGroups  = [ "networkmanager" "wheel" ];
    shell        = pkgs.fish;
    packages = with pkgs; [
      bitwarden-desktop
      btop
      nautilus
    ];

  };
}
