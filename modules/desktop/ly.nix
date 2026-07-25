# ly — TUI display manager (GDM'nin yerine, 2026-07-18)
#
# GDM yerine seçildi: TTY üstünde çalışan minimal bir greeter → GDM'in tam bir
# GNOME/mutter greeter oturumu açmasına gerek kalmaz (daha hafif) ve GNOME + opt-in
# Hyprland oturumları için temiz bir seçici olur. dGPU'ya dokunmaz (TTY fbcon amdgpu'da)
# → D3cold/idle bütçesi etkilenmez.
#
# TEMA: ly 1.4.1 renkleri 0xSSRRGGBB (32-bit) truecolor olarak alır — TTY'nin 16 renk
# paletine DEĞİL. Bu yüzden Stylix base16 hex'lerini (kanagawa-dragon) doğrudan
# besliyoruz; Stylix konsol hedefi ayrıca TTY paletini de temalıyor (tutarlı).
# Stylix'in ly hedefi YOK, tema elle bağlanır.
#
# NOT (bilinçli tercih): GNOME resmî olarak Wayland oturumu için yalnız GDM'i destekler;
# ly'den GNOME-Wayland başlatmak pratikte sorunsuz çalışır ama "resmî dışı"dır. Sorun
# çıkarsa gnome.nix'te GDM'e tek satırla dönülür.
{ config, ... }:

let
  c = config.lib.stylix.colors;
  # ly renk formatı: 0x + SS(stil baytı, 00=düz) + RRGGBB. Stylix hex'i #'siz verir.
  hx = h: "0x00${h}";
in
{
  services.displayManager.ly = {
    enable = true;

    settings = {
      # --- Görünüm (kullanıcı seçimi 2026-07-18: temiz + büyük saat) ---
      animation = "none";        # arka plan animasyonu yok — en sade/hafif
      bigclock = "en";           # üstte iri ASCII saat (24s)
      bigclock_12hr = false;
      hide_borders = false;      # temalı kutu kenarlığı görünsün

      # --- Renkler (Stylix / kanagawa-dragon) ---
      bg        = hx c.base00-hex;   # koyu zemin
      fg        = hx c.base05-hex;   # ana metin + saat
      border_fg = hx c.base0D-hex;   # mavi aksan kutu kenarlığı
      error_bg  = hx c.base00-hex;
      error_fg  = hx c.base08-hex;   # hata = kırmızı (base08)
    };
  };
}
