# Uygulamalar — seçim gerekçeleri ve kapanış ölçümleri

*Durum: 24 Eyl 2026. Modüller: `home/apps/` — `streamrip.nix`, `lollypop.nix`,
`downloads.nix`, `opencode.nix`.*

Tarihli seçim analizleri ve ölçümler. Kural/tuzak uyarıları ilgili `.nix` yorumlarında
ve `MAINTAINERS`'ta.

---

## Kapanış artışı ölçme yöntemi

Aşağıdaki "+N MiB" rakamları taban sisteme göre **net** kapanış artışıdır:

1. Paketin kapanış yollarını `nix path-info -r` ile al.
2. `/run/current-system`'in kapanışıyla `comm -23` yap.
3. Kalan yolların narSize'ını topla.

**Taban SİSTEM kapanışı.** `hms` (standalone HM) çıktısı daha büyük artış gösterir —
o profilin tabanı ayrı, python3.14/yt-dlp orada yoktu (19 Ağu 2026). Çelişki değil,
farklı taban.

---

## İndirme aracı ölçümü (19 Ağu 2026)

Modül: `home/apps/downloads.nix`.

```
varia       +57  MiB  (15 store yolu)   ← seçilen
gopeed      +79  MiB
motrix      +280 MiB  ← Electron; sisteme İKİNCİ bir Chromium yığını
persepolis  +584 MiB  ← Qt + kendi python yığını
```

Varia ucuz çünkü GTK4/libadwaita/gstreamer zaten sistemde; yalnız aria2 + birkaç python
modülü + yt-dlp ekliyor. Motrix'in elenme gerekçesi edfbb3c ile aynı (deezer-enhanced
ikinci Chromium yığını yüzünden kaldırılmıştı; kural: `MAINTAINERS` TARAYICILAR).

---

## Torrent istemcisi ölçümü (24 Eyl 2026)

Modül: `home/apps/downloads.nix`.

```
qbittorrent         5.2.3  +24  MiB  (2 store yolu)   ← seçilen
transmission_4-gtk  4.1.3  +34  MiB  (2)
fragments           3.0.1  +41  MiB  (3)  ← GTK4/libadwaita, transmission motoru
deluge              2.2.0  +178 MiB  (70) ← kendi python yığını
```

qBittorrent hem en olgun motor (libtorrent-rasterbar; reklam/izleme yok) hem en ucuzu —
Qt yığını sistemde var. Varia'nın aria2'si torrent için ikinci sınıf. **Idle kuralı:**
`qbittorrent-nox` servisi eklenmedi; seed yalnız pencere açıkken sürer (bkz.
`system/kernel/sched.nix` tasarım kısıtı).

---

## streamrip seçimi (13 Eyl 2026)

Modül: `home/apps/streamrip.nix`. GitHub'da 20+ aday tarandı (deemix ve fork'ları,
kmille'nin deezer-downloader'ı, Deezy, godeez):

- Yalnız streamrip bu flake'in **pinli** nixpkgs'inde paketli —
  `nix eval .#nixosConfigurations.nixos.pkgs.streamrip.version` → 2.2.0. Diğerleri flake
  input ya da elle paketleme gerektirirdi.
- En yüksek yıldız/aktiflik (4916 ★, son push 2026-08-04, GPL-3); Qobuz/Tidal/SoundCloud'u
  da kapsıyor.

---

## Lollypop seçimi ve kapanış ölçümü (13 Eyl 2026)

Modül: `home/apps/lollypop.nix`.

**Neden DeaDBeeF değil:** DeaDBeeF fonksiyonel olarak doğruydu (SuperEQ, en hafif) ama
GTK2 çağı arayüzü Stylix'in boyayabildiği bir yüzey sunmuyor — "çirkin görünüyor" geri
bildirimiyle değiştirildi. Lollypop GTK3 (`gi.require_version("Gtk", "3.0")`, kaynaktan
doğrulandı — GTK4/libadwaita DEĞİL), Stylix'in GTK hedefi boyayabiliyor.

**Özellik paritesi:**

- EQ: `lollypop/widgets_equalizer.py` + `view_equalizer.py` (yerleşik).
- Playlist: `build_playlists.py`'nin `.m3u8`'leri totem-pl-parser ile import ediliyor
  (`playlists.py`: `import_tracks()`, `TotemPlParser.Parser`).

```
deadbeef    +15 MiB  ← çirkin bulundu, kaldırıldı
lollypop    +34 MiB  ← seçilen
audacious   +30 MiB  ← denenmedi (Lollypop'un Last.fm/MPRIS/kapak sanatı
                       entegrasyonu daha değerli görüldü)
```

---

## opencode model gecikme ölçümü (17 Eyl 2026)

Modül: `home/apps/opencode.nix`.

**Sabit model listesi neden kaldırıldı:** elle sabitlenen dört modelin dördü de 17 Eyl
2026'da NIM'de ölüydü (qwen3-coder-480b → HTTP 410 "end of life on 2026-06-11").

**Öntanımlı model:** `nvidia/nvidia/nemotron-3-super-120b-a12b` — araç tanımlı
`/chat/completions` çağrısına 1,1 s'de 200 + "PONG". Aynı turda kimi-k3, glm-5.3,
glm-5.3-flash ve deepseek-v4-flash 60-120 s içinde yanıt vermedi (ücretsiz katman
kuyruğu); kimi-k2.6 `/v1/models`'da görünmesine rağmen 404 — canlı liste
"çağrılabilir"in üst sınırı, garantisi değil.
