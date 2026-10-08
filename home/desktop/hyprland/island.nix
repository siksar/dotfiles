# Ada (bar.nix) ile başlatıcının (session.nix) ortak ölçüleri; başlatıcı yüksekliği hesaplanır.
let
  header = 26;
  rowHeight = 48;
  # Arama kutusu, başlık, alt ipucu satırı ve iç boşluklar (style.css):
  # 4 + 44 arama + 32 başlık + 34 ipucu + 14 alt boşluk.
  chrome = 128;
  mode = width: rows: {
    inherit width rows;
    height = header + chrome + rows * rowHeight;
  };
in
{
  inherit header;
  radius = 18; # adanın alt köşeleri
  fillet = 14; # üst kenarla birleşen içbükey köşenin yarıçapı

  panelWidth = 560;

  # Yay fiziği (waybar-island.patch): [tepki süresi s, sönüm]; sönüm < 1 aşıp esner.
  spring = {
    open = [ 0.55 0.58 ];
    close = [ 0.42 1.0 ];
  };

  # Pencere SABİT boyutta (yeniden boyutlama 1 px titretiyordu); en büyük hal + aşma
  # payı sığmalı, ÇİFT olmalı.
  window = {
    width = 760;
    height = 580;
  };

  launcher = {
    inherit rowHeight;
    iconSize = 32;
    restWidth = 198;
    leadMs = 24;
    closeLead = 0.85; # kapanışta içerik kabının yayı adanınkinden bu oranda hızlı
    modes = {
      apps = mode 560 7;
      clip = mode 640 7;
      power = mode 380 5;
    };
  };
}
