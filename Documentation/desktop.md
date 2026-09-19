# Masaüstü — COSMIC (varsayılan) + GNOME (ikinci oturum)

*Durum: 16 Eyl 2026. Giriş ekranı: COSMIC greeter (`system/desktop/login.nix`).*

Modüller: `system/desktop/` — `cosmic.nix`, `gnome.nix`, `login.nix`, `theme.nix`,
`mux.nix`. Dizin-içi kurallar (her defasında okunması gerekenler):
`system/desktop/CLAUDE.md`. Bu defter **neden** böyle kurulduğunu anlatır.

**Önceki dönemler arşivde**, ikisi de donmuş ve yolları kasıtlı eski:
Hyprland + Caelestia + Serpantinum (2 Tem – Eyl 2026) →
`Documentation/archive/desktop-hyprland-caelestia.md`; KDE Plasma karantinalı
ikinci oturum (24 Ağu – 16 Eyl 2026) → `Documentation/archive/desktop-plasma.md`.

---

## Greeter'daki oturumlar

Girdi listesi — `sessionData.desktops` store yolundan OKUNDU (16 Eyl 2026,
build sonrası; greeter'da ayrıca gözle doğrulanacak):

| Girdi | Kaynak | Not |
|---|---|---|
| `cosmic.desktop` | upstream cosmic modülü | **varsayılan** (`defaultSession = "cosmic"`) |
| `gnome.desktop` | upstream gnome-session | Wayland |

**X11 girdisi YOK.** Plasma iki girdi getiriyordu (`plasma` + `plasmax11`);
GNOME'un `gnome-xorg.desktop`'u bu yapılandırmada üretilmiyor —
`xsessions/` dizini boş. Aranan yer `sw/share/` DEĞİL:
`config.services.displayManager.sessionData.desktops` ayrı bir store yolu,
greeter oraya bakar (16 Eyl'de bir kez yanlış dizine bakıldı).

Elle yazılmış girdi **yok** — bu kural iki oturum değişikliğinden de sağ çıktı.
Plasma döneminde bir sarmalayıcı girdisi denenmiş ve kaldırılmıştı; gerekçesi
arşivde (`desktop-plasma.md`).

---

## Pencere süslemesi — taşınabilir ders

"Başlık çubuğu" üç ayrı şeyin adıdır ve **yalnız ikisi kontrol edilebilir**:

1. **xdg-decoration protokolünü konuşan uygulamalar** (Qt, Electron/Chromium
   native Wayland'de). Bileşken "sunucu dekore edecek" derse uygulama kendi
   çubuğunu çizmez. Bunu açan tek satır `configuration.nix`'teki
   `environment.sessionVariables.NIXOS_OZONE_WL = "1"` — nixpkgs'in Electron
   sarmalayıcıları `--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations`
   bayraklarını **tam olarak bu değişkene** bağlı ekliyor. Değişken yokken
   uygulamalar XWayland'de koşuyordu.
2. **GTK/libadwaita headerbar** — uygulamanın İÇİNDE çizilir, pencere süslemesi
   değildir. Hiçbir bileşken ayarıyla kaldırılamaz. Bu bir sınırdır, eksik değil.
3. **Uygulamanın kendi tasarladığı chrome** (sekme çubuğu, özel başlık) — ancak o
   uygulamanın kendi ayarıyla gider, sistem geneli bir kolu yoktur.

**COSMIC farkı:** Hyprland sunucu-taraflı süslemede yalnız kenarlık+yuvarlatma
çiziyordu, yani protokolü konuşan uygulama otomatik çubuksuz kalıyordu. COSMIC
**başlık çubuğu çizer** (Ayarlar → pencere yönetiminden kapatılabilir). Yani aynı
mekanizma, ters sonuç — "borderless" beklentisi COSMIC'te oturum ayarından geçer.
Hyprland dönemindeki tam araştırma arşiv defterinde.

---
## GNOME — karantinalı ikinci oturum (16 Eyl 2026, Plasma'nın yerine)

`system/desktop/gnome.nix`, upstream `services.desktopManager.gnome` modülünü
greeter'da ayrı bir girdi olarak açar; `desktop.gnome.enable = false;` ile tek
satırda geri alınır. Plasma'nın karantina sözleşmesi aynen devralındı; **önceki
oturumun defteri** `Documentation/archive/desktop-plasma.md`'de donduruldu.

### Neden Plasma çıktı

Karar kullanıcıya ait (16 Eyl 2026): iki değil üç oturum taşımak yerine GNOME
Plasma'nın yerine geçti. Teknik gerekçe değil, tercih — Plasma'nın ölçümleri
(idle 4.28 W, D3cold, kapanış maliyeti) arşivde geçerli kayıt olarak duruyor.

### DRM guard — ÜÇÜNCÜ sözdizimi

Bu deftere daha önce iki varyant yazılmıştı; GNOME bir üçüncüsünü getiriyor ve
**ortam değişkeni değil**:

| Oturum | Mekanizma | Değer biçimi |
|---|---|---|
| COSMIC | `COSMIC_DRM_ALLOW_DEVICES` | `0x1002:0x1114` — virgülle ayrılır, `:` serbest |
| Plasma (arşiv) | `KWIN_DRM_DEVICES` | udev symlink yolu — `:` YASAK |
| **GNOME** | **udev `TAG+="mutter-device-ignore"`** | env değişkeni YOK; kart etiketlenir |

`mutter-device-ignore` **iki bağımsız kanıtla** doğrulandı:
1. String libmutter-18.so.0'da var (mutter 50.4, flake pin'inden çekilip binary'de
   arandı — kwin'de kullanılan yöntemin aynısı).
2. **Upstream mutter'ın KENDİ udev kuralları bu etiketi kullanıyor** — build
   çıktısındaki `rules.d` içinde sanal sürücü için iki satır duruyor
   (`ID_PATH=="platform-vkms"` ve `DEVPATH==".../faux/vkms/..."`). Yani etiket
   tahmin değil, mutter'ın kendi kullandığı arayüz; bizimki üçüncü satır olarak
   NVIDIA kartına ekleniyor.
Kural kart numarasına değil sürücüye bakar; bu makinede ölçüldü (16 Eyl 2026):
`card0 = nvidia @ 0000:64:00.0`, `card1 = amdgpu @ 0000:65:00.0`, numaralar boot
sırasına göre yer değiştirebilir.

### GNOME'un sızıntıları — Plasma'nınkinden çok daha fazla

Plasma'da kapatılacak tek şey `fwupd`'ın timer'ıydı. GNOME modülü sistem geneline
şunları açıyor ve hepsi `gnome.nix`'te kapatıldı: `localsearch` + `tinysparql`
(dosya indeksleyici — kural 6'nın açık ihlali), `rygel` (DLNA sunucusu),
`dleyna`, `gnome-user-share`, `gnome-remote-desktop`, `geoclue2`, `avahi`,
`orca`, `i18n.inputMethod`, `gnome-browser-connector`, `gnome-initial-setup`.

Kapatılmayan, kayda geçen iki sızıntı: `evolution-data-server` (modül DÜZ `true`
yazıyor, kapatmak `mkForce` ister; D-Bus aktivasyonlu, boşta maliyeti yok) ve
`xdg-desktop-portal-gnome` (portal seçimi `UseIn=` ile masaüstü başına).

### Greeter değişmiyor

GNOME modülü GDM'i **zorlamıyor** — `services.displayManager.gdm.enable = true`
satırı yalnız `nixos-generate-config` şablonunda. `defaultSession` da güvende:
plasma6'nın aksine GNOME modülü ona hiç dokunmuyor, yani `"cosmic"` düz ataması
tek başına yeter (Plasma dönemindeki "mkDefault'a çevirirsen sessizce Plasma'ya
döner" tuzağı kalktı).

### Ölçülmeden yazılmayacaklar

1. **idle watt** — `Documentation/aerox16/power.md` yöntemi, GNOME oturumunda.
2. **dGPU D3cold** — `power_state` + `gnome-shell`'in açtığı DRM fd'leri.
3. ~~Closure farkı~~ → **ÖLÇÜLDÜ (16 Eyl 2026)**: Plasma'lı çalışan sistem
   **26.47 GiB**, GNOME'lu build **24.93 GiB** → **net −1.54 GiB**. Sezginin
   tersi: GNOME daha küçük geldi. Giden (kf6 yığını, xapian/baloo, drkonqi,
   xdg-desktop-portal-kde ≈ 4.1 MiB, sycoca birimleri) gelenden
   (webkitgtk 167 MiB, yelp, vte, xdg-desktop-portal-gnome) fazla.
   Yöntem: `nix path-info -S /run/current-system ./result`.
4. **`gsd-power` ↔ `power-display.nix`** — parlaklık/PPD sahipliği yarışı
   (Plasma'da `powerdevil` için sorulan aynı soru, orada da ölçülmemişti).
5. **Fn köprüsü** — GNOME `KEY_MICMUTE`/`KEY_TOUCHPAD_TOGGLE`'ı kendi işlediği
   için `fn-bridge` o oturumda eylemi atlıyor (`gnome_running()`). Çift toggle
   olmadığı GNOME'a ilk girişte doğrulanmalı. Ayrıntı:
   `Documentation/aerox16/fn-keys.md`.

---


## COSMIC (System76) — kurulum defteri (2 Eyl 2026; 11 Eyl 2026'de VARSAYILAN oldu)

`system/desktop/cosmic.nix`, upstream nixpkgs modülünü
(`services.desktopManager.cosmic`) greeter'da ayrı bir girdi olarak açar.
`desktop.cosmic.enable = false;` ile tek satırda geri alınır — bayrak kapatıldığında
toplevel **bit-aynı** dönüyor (doğrulandı).

Serpantinum ve Plasma'dan **statü** olarak ayrılıyor: bu bir rice denemesi değil,
**ileride ana masaüstü olma adayı** ve o kalitede kuruldu. Caelestia şimdilik
varsayılan oturum olarak kalıyor (`defaultSession = "hyprland-uwsm"`); geçiş kararı
ölçüme bağlı.

**Ne olduğu:** Pop!_OS'un GNOME eklentisi (`pop-shell`) yamama döneminin ardılı.
System76 GNOME'un üstüne katman yazmayı bırakıp masaüstünü sıfırdan Rust'la yazdı;
bileşken `cosmic-comp` (Smithay üzerine), arayüz toolkit'i GTK/Qt değil `iced`.

### Ayarlar neden imperatif — mimariden geliyor, hile değil

Kullanıcı isteği açıktı: *"menüden seçtiğim ayarlamaların kalıcı olmasını istiyorum,
burada deklaratiflikten çok imperatif kullanım iyi olur."* COSMIC bunu ek bir
düzenek gerektirmeden veriyor, çünkü `cosmic-config` iki katmanlı.
`libcosmic/cosmic-config/src/lib.rs`'te `ConfigGet::get()`:

```rust
match self.get_local(key) {                              // ~/.config/cosmic/<ad>/v<N>/<key>
    Ok(value) => Ok(value),
    Err(Error::NotFound) => self.get_system_default(key), // $XDG_DATA_DIRS/cosmic/...
    Err(why) => Err(why),
}
```

Her anahtar ayrı bir dosya (RON formatı) ve **kullanıcı katmanı her zaman kazanır**;
sistem katmanı yalnızca fallback. Yani Nix `~/.config/cosmic`'e dokunmadığı sürece
GUI'den seçilen hiçbir şey bir rebuild'de ezilemez.

Bunun sonucu, bu bölümün en önemli maddesi bir *yapma* değil bir **yapmama** maddesi:

> **`~/.config/cosmic` altına Nix'ten hiçbir şey yazılmayacak** — ne `home.file`, ne
> `xdg.configFile`, ne activation script. Oraya bir store symlink'i koymak dosyayı
> salt-okunur yapar ve ayar menüsü **sessizce kaydedemez** hâle gelir (hata vermez,
> sadece kaydetmez — teşhisi zor bir arıza). Sistem varsayılanı gerçekten gerekirse
> tek meşru yol `/share/cosmic/<ad>/v<N>/<key>`'dir; modül onu zaten
> `environment.pathsToLink`'e ekliyor. Bu planda hiç kullanılmadı.

Aynı gerekçeyle **Stylix köprüsü kurulmadı**. Stylix'in NixOS hedefleri arasında
`cosmic` zaten yok, yani "hiçbir şey yapmamak" burada doğru davranış — eksiklik
değil. Bedeli bilinçli kabul edildi: COSMIC, Caelestia'nın kanagawa-dragon paletiyle
eşleşmez, kendi teması olur.

### DRM guard — bu repodaki `:` kuralı burada TERSİNE dönüyor

`session.nix`, `login.nix` ve `plasma.nix` aynı uyarıyı üç kez tekrarlıyor:
*"değer İKİ NOKTA İÇEREMEZ"* (aquamarine ve kwin, `:` ile ayrılmış cihaz listesi
bekler). **Bu kuralı cosmic.nix'e kopyalamak aktif bir hata olur.**
`cosmic-comp/src/utils/env.rs` okundu:

```rust
pub fn dev_list_var(name: &str) -> Option<Vec<DeviceIdentifier>> {
    let value = std::env::var(name).ok()?;
    Some(value.split(',').flat_map(try_parse_dev_from_str).collect())
}
```

- Liste ayırıcısı **virgül**, iki nokta değil.
- Kabul edilen dört biçimden **üçü iki nokta içermek zorunda**:

| Biçim | Anlamı |
|---|---|
| `0xVVVV:0xDDDD` | PCI vendor:device — **kullanılan** |
| `major:minor` | char cihaz numarası |
| `pci-0000:65:00.0` | `/dev/dri/by-path/<ad>-render` okunur |
| `<ad>` | `/dev/dri/<ad>` yolu |

Bu yüzden COSMIC için **udev symlink'i yok** — `hypr-igpu`/`kwin-igpu`/`sddm-igpu`
desenini burada tekrarlama. PCI kimliğiyle eşleşmek boot sırasından zaten bağımsız,
symlink gereksiz bir dolaylılık olurdu.

Değer ölçüldü (1 Eyl 2026). `DeviceIdentifier::Id::matches()` **render node**'un
`/sys/dev/char/<major>:<minor>/device/{vendor,device}` dosyalarını okuyor:

| GPU | PCI | render node | char | vendor/device |
|---|---|---|---|---|
| AMD Radeon 860M (iGPU) | `65:00.0` | renderD128 | 226:128 | **`0x1002` / `0x1114`** ← izinli |
| NVIDIA RTX 5060 (dGPU) | `64:00.0` | renderD129 | 226:129 | `0x10de` / `0x2d19` |

```nix
environment.sessionVariables.COSMIC_DRM_ALLOW_DEVICES = "0x1002:0x1114";
```

Gerekçe diğer üçüyle aynı: bileşken dGPU'nun DRM node'unu açarsa o açık fd kartın
RTD3/D3cold'a girmesini bloke eder, idle taban ~4.3 W'tan ~7 W'a çıkar.

#### Guard ÇALIŞIYOR — ölçüldü (2 Eyl 2026, ilk COSMIC oturumu)

Üç bağımsız kanıt, en zayıftan en güçlüye:

```bash
# 1) değişken cosmic-comp'un GERÇEK ortamında mı (systemd değil, /proc)
tr '\0' '\n' < /proc/$(pgrep cosmic-comp)/environ | grep COSMIC_DRM
#   → COSMIC_DRM_ALLOW_DEVICES=0x1002:0x1114

# 2) dGPU uykuda mı
cat /sys/bus/pci/devices/0000:64:00.0/power_state
#   → D3cold

# 3) EN GÜÇLÜ KANIT — cosmic-comp hangi DRM node'larını gerçekten AÇTI
ls -l /proc/$(pgrep cosmic-comp)/fd | grep -o '/dev/dri/[a-zA-Z0-9]*' | sort | uniq -c
#   → 4 /dev/dri/card1        (AMD iGPU)
#     card0 (NVIDIA) HİÇ AÇILMAMIŞ
```

3. madde neden en güçlüsü: `power_state` bir *sonuç*, açık fd listesi ise *sebep*.
D3cold başka bir nedenle de doğru okunabilirdi; `card0`'ın fd listesinde hiç
bulunmaması, allow-list'in gerçekten uygulandığını doğrudan gösteriyor.

Not: `AQ_DRM_DEVICES` de cosmic-comp'un ortamında görünüyor — beklenen ve etkisiz
sızıntı (o değişkeni yalnız aquamarine okur).

### Oyun bu oturumda çalışmaz — kasıtlı

Allow-list yalnız iGPU'ya izin verdiği için COSMIC oturumunda dGPU **hiç açılmaz**,
yani `gamerun`'ın PRIME offload'ı burada devre dışı. Bu bir eksiklik değil, kullanıcı
sırası: *"oyun vs. ayarlarını ilk önce sorunsuz workstation kullanımı sağlandıktan
sonra geçilecek."* Oyun fazına gelindiğinde ilk dokunulacak yer bu değişkendir
(`COSMIC_DRM_BLOCK_DEVICES` ve/veya `COSMIC_RENDER_DEVICE` ile yeniden tasarlanır).

### Karantina sınırı — maliyet neden iki satır

Plasma'daki kuralın aynısı: *"COSMIC oturumunun dışında koşuyor mu?"* Modülün
getirdiği servisler mevcut sisteme karşı tek tek ölçüldü (`systemctl is-enabled`):

| Servis | Modül ne diyor | Sistemde durumu | Sonuç |
|---|---|---|---|
| `avahi` | `mkDefault true` | **not-found** | ⚠ yeni kalıcı daemon → `false` |
| `orca` | `mkDefault …` | **not-found** | ⚠ yeni → `false` |
| `acpid` | `mkDefault true` | enabled/active | değişiklik yok |
| `upower` | `true` | active | değişiklik yok |
| `accounts-daemon` | `true` | active | değişiklik yok |
| `geoclue2` | `true`, `enableDemoAgent=false` | enabled, D-Bus aktivasyonlu | `geoclue.nix` ile aynı değerler — çakışma yok |
| `power-profiles-daemon` | `mkDefault` | active | `power.nix` kazanır |
| `networkmanager`/`bluetooth`/`gvfs` | `mkDefault true` | zaten açık | değişiklik yok |

**avahi nedir:** mDNS/Bonjour daemon'ı — ağ yazıcısını, SMB/NAS paylaşımını,
Chromecast benzeri cihazları IP yazmadan bulmaya yarar. Bunu yapabilmek için sürekli
açık durup ağı dinler. Bu makinede hiç kurulu değildi ve isteyen bir tüketici de yok,
yani kazanç sıfır / bedel kalıcı. **Ağ yazıcısı eklenirse geri açılacak satır budur.**

### Session wrapper gerekmedi

`plasma.nix`'in `sessionWrapper`'ı, HM'in Caelestia için koyduğu
`QT_QPA_PLATFORMTHEME=qt6ct` değeri Breeze'i çökerttiği için vardı. COSMIC iced/GTK
tabanlı, Qt değil — o çekişme burada yok. Upstream'in `cosmic-session` oturum paketi
doğrudan kullanılıyor, elle `.desktop` üretilmiyor:

```
Exec=…/cosmic-session-1.6.0/bin/start-cosmic
DesktopNames=COSMIC
```

### Kapanış maliyeti — ÖLÇÜLDÜ (2 Eyl 2026)

Plasma girdisindeki yöntemin aynısı: aynı ağaçta yalnız bayrak çevrilerek.

| Yapılandırma | Kapanış |
|---|---|
| `desktop.cosmic.enable = false` | 28.54 GB |
| `desktop.cosmic.enable = true` | 30.65 GB |
| **fark** | **+2.11 GB** |

(Karşılaştırma için: Plasma +2.62 GB.) En büyük kalemler `pop-icon-theme` 65.8 MiB,
`xdg-desktop-portal-cosmic` 55.9 MiB, `pop-launcher` 9.5 MiB,
`network-manager-applet` 5.6 MiB.

### Kayda geçen, kapatılmayan sızıntılar

- `xdg.portal.configPackages` — `hyprland`, `plasma6` ve `cosmic` modüllerinin
  **üçü de `mkDefault`** kullanıyor, yani eşit öncelikte birleşiyorlar; eval ile
  doğrulandı, liste artık `[xdg-desktop-portal-cosmic, plasma-workspace, hyprland]`.
  Elle ekleme gerekmedi. Portal *seçimi* `.portal` dosyasındaki `UseIn=` ile masaüstü
  başına yapıldığından Caelestia etkilenmemeli — ama liste değiştiği için Hyprland'de
  ekran görüntüsü/paylaşımı switch sonrası bir kez sınanmalı.
- `environment.sessionVariables.X11_{BASE,EXTRA}_RULES_XML` — modül koşulsuz yazıyor,
  her oturuma girer. Zararsız (yalnız libcosmic/xkb tarafı okur).
- `xdg.icons.fallbackCursorThemes = mkDefault [ "Cosmic" ]` — yalnız *fallback*;
  Stylix imleci açıkça verdiği için o kazanır.
- `COSMIC_DRM_ALLOW_DEVICES` Caelestia oturumuna da sızar; maliyeti **sıfır** — bu
  değişkeni yalnız `cosmic-comp` okur (`KWIN_DRM_DEVICES` de bugün aynı şekilde sızıyor).

### XWayland — açık bırakıldı

Kullanıcı "olabildiğince Wayland" istedi ama XWayland açık bırakıldı, çünkü ölçüm
kapatmayı desteklemedi: o an Hyprland'de açık 6 pencereden 3'ü XWayland'di ve
**üçü de Steam**'di — workstation uygulamalarının tamamı zaten native Wayland
(`NIXOS_OZONE_WL` sistem geneli). Kapatmanın workstation'a kazandıracağı bir şey
yoktu, oyun fazında ise geri açılması gerekirdi.

**ÖLÇÜLDÜ (2 Eyl 2026, COSMIC oturumunda):** `xlsclients` boş dönmedi, iki satır
verdi — `steam` ve `steamwebhelper`. Yani X11'e düşen **tek şey Steam**, tıpkı
Hyprland'deki ölçümde olduğu gibi. Bu bir hata değil, tahmin edilen sonucun
doğrulanması: workstation uygulamalarının hiçbiri XWayland'e düşmüyor, düşen tek
yığın da zaten ertelenmiş olan oyun tarafı. Steam kapatıldığında liste boşalmalı.

### Doğrulama — sırayla

```bash
# 1) oturum greeter'da görünüyor mu
ls /run/current-system/sw/share/wayland-sessions/     # cosmic.desktop

# 2) COSMIC'e gir → dGPU gerçekten uykuda mı (ASIL KRİTER)
cat /sys/bus/pci/devices/0000:64:00.0/power_state      # D3cold BEKLENİYOR
systemctl --user show-environment | grep COSMIC_DRM    # değişken oturuma girdi mi

# 3) idle bütçesi — Documentation/aerox16/power.md yöntemi
#    (120 s sakinleşme + 6×10 s örnek), kriter 4.28 W ± gürültü

# 4) Wayland saflığı
xlsclients                                             # BOŞ dönmeli

# 5) İMPERATİF KALICILIK — bu planın sözleşmesi
#    Ayarlar'dan görünür bir şey değiştir, sonra:
ls -la ~/.config/cosmic/*/v1/     # normal DOSYA olmalı, store symlink'i DEĞİL
#    ardından `nixos-rebuild switch` + yeniden giriş → ayar YERİNDE DURMALI
```

### Caelestia regresyon kontrolü (switch sonrası)

Caelestia'ya dönüp şunlara bak: ekran görüntüsü/paylaşımı (portal listesi değişti),
Qt uygulamalarının görünümü (qt6ct hâlâ kazanıyor mu), imleç teması, ve
`~/.config/gtk-3.0/gtk.css`.

Sonuncusu **bilinen çakışma adayı ve henüz doğrulanmadı**: o dosyayı bugün Caelestia
CLI *imperatif* olarak yazıyor (`stylix.targets.gtk.enable = false`, HM `gtk.enable`
= false → hiçbir store symlink'i yok). COSMIC'in de aynı dosyayı yazıp yazmadığı
ölçülmedi. İki oturum arasında GTK uygulamalarının görünümü değişiyorsa sebep budur;
ikisi de imperatif olduğu için hata vermez, sadece **son yazan kazanır**. Ölçüldükten
sonra bu paragraf sonuçla değiştirilecek.
