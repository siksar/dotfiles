# LocalSend — yerel ağda cihazlar arası dosya paylaşımı (AirDrop muadili).
# openFirewall modülün kendi portunu (53317/tcp+udp) açar; elle firewall kuralı
# eklemeye gerek yok.
{ ... }:

{
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };
}
