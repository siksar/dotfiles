# system/desktop — oturumlar, giriş ekranı, tema

Yalnız bu dizinde çalışırken yüklenir. Katmanlar arası kurallar kök `CLAUDE.md`'de,
tasarım defteri `Documentation/desktop.md`'de.

**Yerleşim:** `login.nix` COSMIC greeter'ı açar; `cosmic.nix` varsayılan oturumu,
`plasma.nix` ikinci oturumu kurar; `theme.nix` Stylix'in NixOS tarafıdır;
`mux.nix` dGPU-only bayrağıdır ve **varsayılan kapalıdır** (dört DRM köprüsünü
birden çevirir).

## Burada bilinmesi gereken üç şey

- **Her oturumun kendi iGPU kilidi var ve sözdizimleri birbirinin tersi.**
  Plasma `KWIN_DRM_DEVICES = "/dev/dri/kwin-igpu"` ile kendi udev symlink'ini
  kullanır (değerde `:` olamaz); COSMIC ise `COSMIC_DRM_ALLOW_DEVICES` ile
  `0x1002:0x1114` gibi virgülle ayrılan bir liste bekler, yani symlink'e ihtiyacı
  yoktur. Oturumlar birbirinin dosyasına dayanmaz — biri kapatılınca diğeri
  çalışmaya devam etsin diye. Yanlış yaparsan dGPU açık bir DRM fd'si tutar, D3cold'a
  hiç inmez ve boşta güç 4.28 W'tan ~7 W'a çıkar.

- **`defaultSession` bu dizinde değil, `configuration.nix`'te belirlenir**
  (`= "cosmic"`, düz atama). Plasma modülü `mkDefault "plasma"` diyor; düz atama onu
  yener. Buradaki satırı `mkDefault`'a çevirirsen greeter sessizce Plasma'ya döner.

- **Karantina sınırı: "o oturumun dışında da koşuyor mu?"** Yalnız oturumun içinde
  yaşayan şeyler (powerdevil, baloo, kded6) varsayılanında bırakılır — sen o oturumda
  değilken bir şeye mal olmazlar. Sistem geneline sızanlar kapatılır: Plasma'nın
  `fwupd`'ı (kalıcı `fwupd-refresh.timer` kurar, boşta-yoklama yasağına takılır),
  COSMIC'in `avahi` ve `orca`'sı. Her dosyadaki "karantina sınırı" bloğuna bak.

**`~/.config/cosmic` altına Nix'ten hiçbir şey yazma.** cosmic-config'in kullanıcı
katmanı sistem katmanını ezer; oraya konan bir store symlink'i ayar GUI'sinin
kaydetmesini **sessizce** bozar. COSMIC ayarları kasıtlı olarak imperatif bırakıldı:
Stylix köprüsü ve HM modülü yok.
