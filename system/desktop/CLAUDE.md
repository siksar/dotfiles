# system/desktop — oturumlar, giriş ekranı, tema

Yalnız bu dizinde çalışırken yüklenir. Katmanlar arası kurallar kök `CLAUDE.md`'de,
tasarım defteri `Documentation/desktop.md`'de.

**Yerleşim:** `login.nix` COSMIC greeter'ı açar; `cosmic.nix` varsayılan oturumu,
`gnome.nix` ikinci oturumu kurar; `theme.nix` Stylix'in NixOS tarafıdır;
`mux.nix` dGPU-only bayrağıdır ve **varsayılan kapalıdır** (dört DRM köprüsünü
birden çevirir). KDE Plasma 16 Eyl 2026'da ağaçtan çıktı — defteri
`Documentation/archive/desktop-plasma.md`'de donduruldu.

## Burada bilinmesi gereken dört şey

- **Her oturumun kendi iGPU kilidi var ve üçünün sözdizimi birbirine benzemiyor.**
  COSMIC `COSMIC_DRM_ALLOW_DEVICES` ile `0x1002:0x1114` gibi virgülle ayrılan bir
  liste bekler. GNOME'da böyle bir ortam değişkeni **yoktur**: mutter bir udev
  ETİKETİ okur, `TAG+="mutter-device-ignore"` (libmutter-18.so.0'da doğrulandı),
  yani kilidi kartı etiketleyerek kurarsın. (Arşivdeki Plasma üçüncü bir varyanttı:
  `KWIN_DRM_DEVICES`, değerinde `:` olamayan bir udev symlink'i.) Oturumlar
  birbirinin dosyasına dayanmaz — biri kapatılınca diğeri çalışmaya devam etsin
  diye. Yanlış yaparsan dGPU açık bir DRM fd'si tutar, D3cold'a hiç inmez ve boşta
  güç 4.28 W'tan ~7 W'a çıkar.

- **`defaultSession` bu dizinde değil, `configuration.nix`'te belirlenir**
  (`= "cosmic"`, düz atama). GNOME modülü — plasma6'nın aksine — bu seçeneğe hiç
  dokunmuyor ve GDM'i de zorlamıyor (`gdm.enable = true` satırı yalnız
  `nixos-generate-config` şablonunda). Yani Plasma dönemindeki "mkDefault'a
  çevirirsen greeter sessizce diğer oturuma döner" tuzağı artık yok.

- **Karantina sınırı: "o oturumun dışında da koşuyor mu?"** Yalnız oturumun içinde
  yaşayanlar (gsd-*, evolution-data-server, goa) varsayılanında bırakılır — sen o
  oturumda değilken bir şeye mal olmazlar. Sistem geneline sızanlar kapatılır ve
  GNOME çok şey sızdırır: `localsearch`/`tinysparql` (dosya indeksleyici, kural 6
  ihlali), `rygel`/`dleyna`/`gnome-user-share`/`gnome-remote-desktop` (ağ servisleri),
  `avahi`, `orca`, `i18n.inputMethod`. Gerekçeler `gnome.nix`'in karantina bloğunda.

- **Bir seçeneği kapatmadan önce repoda kendi dosyası var mı diye bak.**
  `geoclue2` tam olarak böyle: `system/net/geoclue.nix` onu düz `true` ile açıyor
  ve orada ölçülmüş (D-Bus aktivasyonlu, boşta koşmuyor). `gnome.nix`'e `false`
  yazmak eval'i çakışmayla düşürür — 16 Eyl 2026'da bir build bu yüzden düştü.

**`~/.config/cosmic` altına Nix'ten hiçbir şey yazma.** cosmic-config'in kullanıcı
katmanı sistem katmanını ezer; oraya konan bir store symlink'i ayar GUI'sinin
kaydetmesini **sessizce** bozar. COSMIC ayarları kasıtlı olarak imperatif bırakıldı:
Stylix köprüsü ve HM modülü yok. GNOME tarafında bu kısıt YOK — dconf deklaratif
yazılabilir (Home Manager `dconf.settings`), yani kısayollar Nix'ten bağlanabilir.
