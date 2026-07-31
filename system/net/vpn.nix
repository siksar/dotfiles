# Mullvad VPN (daemon + GUI).
# DNS etkileşimi: tünel açıkken Mullvad kendi DNS'ini tünel arayüzüne per-link
# yazar; system/net/core.nix'teki systemd-resolved cache-only kurulumu bunu
# bilerek bozmuyor (dnsovertls kapalı — şifreli DNS'i tünelin kendisi veriyor).
#
# 31 Tem 2026 üstakım bölünmesi: nixpkgs `mullvad-vpn`i ikiye ayırdı —
# `pkgs.mullvad` = daemon, `pkgs.mullvad-vpn` = GUI. Eskiden burada
# `package = pkgs.mullvad-vpn` yazıyordu; artık o GUI-only olduğu için modülün
# `cfg.package.hasMullvadDaemon` assertion'ı eval'i durduruyor. Doğru biçim:
# `package`e HİÇ DOKUNMA (varsayılanı zaten daemon), GUI'yi ayrı bayrakla aç.
{ ... }:

{
  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };
}
