# tty'siz bağlamlarda (Claude Code kabuğu, .desktop, user unit) sudo için grafik istem.
# SUDO_ASKPASS tek başına yetmez: her zaman `sudo -A`. sessionVariables yeni girişte görünür.
{ pkgs, ... }:

let
  askpass = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";
in
{
  environment.systemPackages = [ pkgs.kdePackages.ksshaskpass ];

  environment.sessionVariables.SUDO_ASKPASS = askpass;
}
