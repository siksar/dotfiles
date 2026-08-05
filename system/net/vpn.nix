# Mullvad VPN (daemon + GUI) — 01 Ağu 2026'da DEVRE DIŞI.
# NEDEN: system/net/zapret.nix eklendi. Mullvad tun0 arayüzünü default route'a
# yazar; zapret'in nfqueue kuralı OUTPUT hook'unda paketleri NFQ'ya çeker. İkisi
# aynı output paketlerini manipüle etmeye kalkınca tun0'a giden paketler
# zapret'e düşer → karşılıklı bozulma. Tek cihazda ikisini bir arada tutmanın
# temiz yolu yok; yalın zapret tercih edildi.
#
# Geri açmak için enable = true yap, ama o zaman zapret.nix'i de kapat
# (system/net/zapret.nix'i configuration.nix'ten import'tan kaldır veya
# systemd.services.zapret.wantedBy = []  yap). DNS etkileşimi notu aşağıda
# kalıyor — geri açan kişi hatırlasın diye.
#
# DNS etkileşimi (Mullvad aktifken): tünel açıkken Mullvad kendi DNS'ini tünel
# arayüzüne per-link yazar; system/net/core.nix'teki systemd-resolved cache-only
# kurulumu bunu bilerek bozmuyordu (dnsovertls kapalı — şifreli DNS'i tünelin
# kendisi veriyor).
#
# 31 Tem 2026 üstakım bölünmesi: nixpkgs `mullvad-vpn`i ikiye ayırdı —
# `pkgs.mullvad` = daemon, `pkgs.mullvad-vpn` = GUI. Eskiden burada
# `package = pkgs.mullvad-vpn` yazıyordu; artık o GUI-only olduğu için modülün
# `cfg.package.hasMullvadDaemon` assertion'ı eval'i durduruyor. Doğru biçim:
# `package`e HİÇ DOKUNMA (varsayılanı zaten daemon), GUI'yi ayrı bayrakla aç.
{ ... }:

{
  services.mullvad-vpn = {
    enable = false;
    gui.enable = false;
  };
}
