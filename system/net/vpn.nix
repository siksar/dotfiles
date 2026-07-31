# Mullvad VPN (daemon + GUI).
# DNS etkileşimi: tünel açıkken Mullvad kendi DNS'ini tünel arayüzüne per-link
# yazar; system/net/default.nix'teki systemd-resolved cache-only kurulumu bunu
# bilerek bozmuyor (dnsovertls kapalı — şifreli DNS'i tünelin kendisi veriyor).
{ pkgs, ... }:

{
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
  };
}
