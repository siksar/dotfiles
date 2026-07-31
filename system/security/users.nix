{ pkgs, ... }:

{
  # fish — eskiden sway rice'ın parçasıydı (sway-rice/system.nix), tek oturum
  # kalınca sistem katmanına taşındı. HM tarafındaki abbr/alias/function seti
  # modules/desktop/fish.nix'te (artık koşulsuz).
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
