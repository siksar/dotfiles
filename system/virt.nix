# Claude Desktop Cowork VM'i için: qemu + OVMF + virtiofsd, kvm grubu.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    qemu_kvm
    virtiofsd
  ];

  users.users.zixar.extraGroups = [ "kvm" ];
}
