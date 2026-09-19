# Lollypop — yerel müzik çalar + yerleşik EQ (streamrip.nix ile inen kütüphane
# ve build_playlists.py'nin ürettiği tür playlist'leri için).
#
# NEDEN LOLLYPOP, DeaDBeeF DEĞİL (13 Eyl 2026): DeaDBeeF fonksiyonel olarak
# doğruydu (SuperEQ, en hafif seçenek, +15 MiB) ama arayüzü GTK2 çağından
# kalma, Stylix'in boyayabildiği bir yüzey sunmuyor — "çirkin görünüyor"
# geri bildirimi üzerine değiştirildi. Lollypop GTK3 (`gi.require_version
# ("Gtk", "3.0")`, kaynağından doğrulandı — GTK4/libadwaita DEĞİL) ama COSMIC/
# Stylix'in GTK hedefinin boyayabileceği modern bir GNOME arayüzü kullanıyor,
# kapak sanatı ızgarası + bulanık arkaplan tasarımıyla GNOME ekosisteminin en
# "temiz" çalarlarından biri.
#
# ÖZELLİK PARİTESİ KORUNDU:
#   - EQ: lollypop/widgets_equalizer.py + view_equalizer.py (yerleşik, plugin değil)
#   - Playlist: build_playlists.py'nin ürettiği .m3u8'leri totem-pl-parser ile
#     import ediyor (playlists.py: import_tracks(), TotemPlParser.Parser) —
#     Rap.m3u8/Cloud Rap.m3u8/vb. doğrudan sürükle-bırak veya "Import
#     Playlist" ile çalışır.
#
# ÖLÇÜLDÜ (downloads.nix'teki yöntem, taban sisteme göre net kapanış artışı):
#   deadbeef    +15 MiB  ← çirkin bulundu, kaldırıldı
#   lollypop    +34 MiB  ← seçilen
#   audacious   +30 MiB  ← Winamp-tarzı, denenmedi (Lollypop'un GNOME
#                          entegrasyonu — Last.fm, MPRIS, kapak sanatı —
#                          burada daha değerli görüldü)
#
# DAHA "TAM GTK4" bir alternatif olan `resonance` (nixpkgs'te var, gerçekten
# libadwaita) bilerek SEÇİLMEDİ: yukarı akış kendini "EARLY STAGE ALPHA
# RELEASE SOFTWARE" olarak tanımlıyor, EQ'su yok, m3u import'u belgesiz.
# COSMIC daha oturunca tekrar değerlendirilebilir.
{ pkgs, ... }:

{
  home.packages = [ pkgs.lollypop ];
}
