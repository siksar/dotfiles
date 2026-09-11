# Masaüstü — COSMIC (varsayılan) + KDE Plasma (ikinci oturum)

*Durum: 11 Eyl 2026. Giriş ekranı: COSMIC greeter (`system/desktop/login.nix`).*

Modüller: `system/desktop/` — `cosmic.nix`, `plasma.nix`, `login.nix`, `theme.nix`,
`mux.nix`. Dizin-içi kurallar (her defasında okunması gerekenler):
`system/desktop/CLAUDE.md`. Bu defter **neden** böyle kurulduğunu anlatır.

**Önceki dönem arşivde:** Hyprland + Caelestia + Serpantinum kurulumunun tamamı
(2 Tem – Eyl 2026) `Documentation/archive/desktop-hyprland-caelestia.md` içinde
donmuş olarak duruyor. Oradaki yollar kasıtlı eskidir.

---

## Greeter'daki oturumlar

`cosmic-randr`/`sessionData` üzerinden doğrulanan girdi listesi (11 Eyl 2026):

| Girdi | Kaynak | Not |
|---|---|---|
| `cosmic.desktop` | upstream cosmic modülü | **varsayılan** (`defaultSession = "cosmic"`) |
| `plasma.desktop` | upstream plasma-workspace | Wayland |
| `plasmax11.desktop` | upstream plasma-workspace | X11 |

Elle yazılmış girdi **yok**. 25 Ağu 2026'da eklenen `plasma-karantina.desktop`
sarmalayıcısı 11 Eyl 2026'da kaldırıldı: tek işi Caelestia'nın bıraktığı
`QT_QPA_PLATFORMTHEME=qt6ct` değerini geri çevirmekti, Caelestia gidince kaynağı
kalmadı ve no-op'a döndü (ölçüm: HM profilinde değişken yok, oturumdaki değer
zaten `kde`). Gerekçenin tamamı `plasma.nix`'in başında.

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
## KDE Plasma — karantinalı ikinci oturum (24 Ağu 2026)

`system/desktop/plasma.nix`, upstream nixpkgs modülünü (`services.desktopManager.plasma6`)
greeter'da **karantinalı bir oturum** olarak açar. `desktop.plasma.enable = false;` ile tek
satırda geri alınır. Serpantinum'dan iki yapısal farkı var:

- **HM tarafı YOK.** Serpantinum'da rice ağacını `$HOME`'a yerleştiren ayrı bir HM modülü
  gerekiyordu; Plasma'da oturumun tamamını upstream modül kuruyor. Bu dosyanın işi
  yalnızca o modülün bu makineye özgü kenarlarını yamamak.
- **Bir deneme değil, bir karar.** Serpantinum ikinci bir rice'ı denemekti; bu, Hyprland'i
  bırakıp bırakmama sorusunu ölçüye bağlamak için var.

### Neden karantina (ve neden soru "beğendim mi" değil)

Bu makinede Hyprland yalnız pencere yöneticisi değil, güç zincirinin bir halkası:

| Hyprland'de | Plasma'da karşılığı | Durum |
|---|---|---|
| `AQ_DRM_DEVICES=/dev/dri/hypr-igpu` (dGPU'ya hiç dokunma → D3cold) | `KWIN_DRM_DEVICES=/dev/dri/kwin-igpu` | kuruldu, **ölçülmedi** |
| `power-display-user.service` → `hyprctl keyword monitor` (60/165Hz + animasyon) | `kscreen-doctor` + `plasma-workspace.target` | **yazılmadı** — Plasma'da tazeleme geçişi yok |
| PPD profilini `power-display.nix` sürüyor (masaüstünde güç kaydırıcısı yok) | powerdevil kendi sürer | **çakışma bekleniyor** |
| Caelestia (bar/launcher/kilit/idle + 110-anahtarlı Material You) | plasmashell + Breeze + Stylix `kde` hedefi | Stylix `kde` hedefi zaten açık |

Zincirin geri kalanı (gamerun / gamemode / scx_lavd / WMI fan profilleri) tamamen sistem
katmanında, compositor'dan bağımsız — Plasma oturumunda da aynen çalışır.

### Karar kriteri — iki sayı

`Documentation/aerox16/power.md`'nin yöntemiyle, **Plasma oturumunda**, pilde, %40
parlaklık, temiz idle (120 s sakinleşme + 6×10 s örnek):

```bash
# 1) idle watt — 4.28W ± gürültü mü?
paste /sys/class/power_supply/BAT1/current_now /sys/class/power_supply/BAT1/voltage_now \
  | awk '{printf "%.2f W\n", $1*$2/1e12}'

# 2) dGPU gerçekten uykuda mı? (D3cold bekleniyor)
cat /sys/bus/pci/devices/0000:64:00.0/power_state
```

~7 W çıkıyorsa cevap net: `KWIN_DRM_DEVICES` tutmamış, geçiş kapalı. 4.28 W çıkıyorsa
geçiş **teknik olarak** açık demektir; geriye Caelestia'yı bırakmaya değip değmediği
tercihi kalır (7 el-bakımlı 110-anahtarlı şema + tema→klavye RGB hook zinciri).

### Karantina sınırı — kural

**"Plasma oturumunun dışında koşuyor mu?"** Koşmuyorsa varsayılan bırakıldı, koşuyorsa
kapatıldı.

- **Varsayılan bırakıldı** (yalnız Plasma'ya girilince ayakta): powerdevil, baloo
  (dosya indeksleyici), kded6, orca, kde-pim/akonadi. Caelestia'dayken maliyetleri sıfır.
- **Kapatıldı**: `services.fwupd` — plasma6 `mkDefault true` yapıyor ve `fwupd-refresh.timer`
  Plasma'ya hiç girilmese bile koşan **kalıcı** bir timer. `sched.nix`'in idle kuralı.

### Kapanış maliyeti — ÖLÇÜLDÜ (24 Ağu 2026)

`nix path-info -S`, aynı ağaçta yalnız bayrağı çevirerek (`extendModules` +
`lib.mkForce false`), yani downloads.nix gibi ilgisiz değişiklikler dışarıda:

| Yapılandırma | Kapanış |
|---|---|
| `desktop.plasma.enable = false` | 27.29 GB |
| `desktop.plasma.enable = true` | 29.90 GB |
| **Plasma'nın tek başına maliyeti** | **+2.62 GB** |

En büyük kalemler: qtwebengine 427 MB · mariadb-server 259 MB ·
plasma-workspace-wallpapers 255 MB · ibus 150 MB · openjdk-minimal-jre 90 MB ·
breeze-icons 72 MB · plasma-workspace 71 MB.

`mariadb-server` sürprizdir ve tek bir bayraktan gelir: `programs.kde-pim.enable`
(plasma6 modülü `mkDefault true` yapıyor) akonadi'yi çekiyor, akonadi de **kullanıcı
oturumu başına bir MariaDB örneği** çalıştırıyor. Ayrıca ölçüldü:

| | Kapanış |
|---|---|
| `programs.kde-pim.enable = false` | 29.50 GB |
| varsayılan (`true`) | 29.90 GB |
| **kde-pim maliyeti** | **+0.40 GB** (mariadb-server 259 MB + kdepim-runtime + akonadi) |

**Varsayılan bırakıldı, bilerek**: akonadi yalnız Plasma oturumu ayaktayken koşar,
Caelestia'dayken sıfır maliyetlidir — yukarıdaki karantina kuralının tam olarak
"içeride" tarafı. Bu makinede posta/takvim istemcisi kullanılmıyorsa tek satırla düşer:

```nix
programs.kde-pim.enable = false;   # system/desktop/plasma.nix içine
```

### Kayda geçen, kapatılmayan sızıntılar

1. plasma6 koşulsuz olarak `XDG_CONFIG_DIRS`'e `$HOME/.config/kdedefaults` ekliyor — PAM
   üzerinden Caelestia oturumuna da girer. Ölçülebilir maliyeti yok, kapatmak modülü
   `mkForce`'la dövmek olurdu.
2. `xdg-desktop-portal-kde` ve `kwallet` portalı `extraPortals`'a giriyor. İkisi de
   `.portal` dosyasındaki `UseIn=kde` ile sınırlı (doğrulandı), xdph'ninki ise
   `UseIn=wlroots;Hyprland;sway;…` — yani Caelestia'da devreye girmezler. Yine de
   Hyprland'de ekran paylaşımı bozulursa **ilk bakılacak yer burası**;
   `xdg.portal.config.Hyprland` ile açıkça pinlemek çözüm olur.

### Bilinen eksik — AC/BAT tazeleme geçişi

`power-display-user.service` `hyprland-session.target`'a bağlı ve `hyprctl` yoksa sessizce
`exit 0` yapıyor (script'in kendi satırı). Yani Plasma oturumunda panel **165 Hz'de kalır**
ve animasyonlar pilde kapanmaz — deneme ölçümünü yaparken bunu hesaba kat, ya da ölçümden
önce elle 60 Hz'e al:

```bash
kscreen-doctor output.eDP-1.mode.2560x1600@60
```

Deneme kalıcılaşırsa yapılacak iş, o user service'i `plasma-workspace.target` için
ikizlemek (`kscreen-doctor` ile) — ama önce yukarıdaki iki sayı.

### İlk deneme neden kabuksuz açıldı (25 Ağu 2026) — ve düzeltmesi

Belirti: Plasma seçildi, oturum açıldı, **bar/launcher/kabuk hiç gelmedi**. Journal her
QML bileşeninde aynı satırı bastı:

```
plasmashell: qrc:/qt/qml/org/kde/kirigami/templates/Heading.qml: module "breeze" is not installed
plasmashell: QQmlApplicationEngine failed to load component
systemsettings: Fatal error while loading the sidebar view qml component  → SIGABRT
```

**SDDM ile ilgisi yok** — SDDM bu sistemde hiç kurulu değil (`sddm.service could not be
found`, ikili sistem profilinde yok) ve zaten bir greeter'dır: `plasmashell`'i o
başlatmaz. Greeter oturumu `exec` eder, gerisi oturumun kendi işidir.

Gerçek zincir, `systemctl --user show-environment` ve `definitionsWithLocations` ile
ölçüldü:

1. `services.desktopManager.plasma6.enable = true` → `qt.enable = true`.
2. `qt.enable` o ana dek **false**'tu. Stylix'in NixOS qt hedefi
   (`stylix/modules/qt/nixos.nix`) `qt.platformTheme = "kde"` ve `qt.style = "breeze"`
   değerlerini **zaten yazıyordu**, ama `nixos/modules/config/qt.nix`'in
   `config = mkIf cfg.enable` bloğu hiç çalışmadığı için hiçbir ortam değişkeni
   çıkmıyordu. Ayar yıllardır orada duruyordu, uykudaydı.
3. Plasma o bloğu **uyandırdı**: sistem geneline `QT_QPA_PLATFORMTHEME=kde` ve
   `QT_STYLE_OVERRIDE=breeze` girdi.
4. Ama Home Manager, Caelestia için `QT_QPA_PLATFORMTHEME=qt6ct` diyor
   (`home/desktop/caelestia/default.nix:123`) ve **HM kazanıyor**:
   `hm-session-vars.sh` giriş kabuğunun `profile.d`'sinden gelir, `pam_env`'den
   *sonra*. Kanıt: oturumdaki değer `qt6ct`, `kde` değil.
5. Sonuç: Plasma'da KDE platform teması (`plasma-integration`) hiç yüklenmiyor —
   yerine qt6ct yükleniyor — ama QStyle hâlâ zorla `breeze`. Breeze'in QML/QQC2
   entegrasyonunu sağlayan bileşen platform temasıydı; o gelmeyince Plasma'nın tüm
   QML sahnesi çöküyor.

> **SONRADAN DÜŞTÜ (11 Eyl 2026).** Aşağıdaki düzeltme artık ağaçta YOK.
> Zincirin 4. halkası (HM'in `qt6ct` değeri) Caelestia'yla birlikte ortadan
> kalkınca sarmalayıcı no-op'a döndü ve kaldırıldı — ölçüm: HM profilinde
> `QT_QPA_PLATFORMTHEME` tanımlı değil, oturumdaki değer zaten `kde`.
> Greeter bugün yalnız upstream girdilerini listeliyor. Metin, **teşhis yöntemi**
> öğretici olduğu için duruyor: bir seçeneğin değerini upstream'in `default =`
> satırından çıkarma, `definitionsWithLocations` ile kimin yazdığına bak.

**Düzeltme (tarihî)**: `plasma.nix`'teki `sessionWrapper` değişkeni **yalnız bu oturumun
exec'inde** geri alıyor (`export QT_QPA_PLATFORMTHEME=kde`) ve kendi greeter girdisini
kuruyor: **"Plasma (karantina)"**. Stok `Plasma` / `Plasma (X11)` girdileri listede
durmaya devam eder ve hâlâ bozuktur — greeter'da karantina girdisi seçilecek.

HM'e dokunulmadı, bilerek: `qt6ct` Caelestia'da gerçekten gerekli, ve karantina kuralı
düzeltmenin oturumun kendi tarafında kalmasını istiyor.

#### Bu olayın asıl dersi

24 Ağu'daki not şöyle diyordu: *"QT_QPA_PLATFORMTHEME sistem geneline set edilmez
(`qt.platformTheme = null`), yani Breeze ile qt6ct arasında bir çekişme yok."* Yanlıştı
ve çökmenin sebebi tam olarak buydu. Hata, upstream kaynağındaki **`default = null`**
satırını okuyup değerin o olduğunu varsaymaktı; gerçek değeri Stylix yazıyordu. Bir
seçeneğin gerçek değeri ve **kimin yazdığı** tek komutla görülür:

```bash
nix eval --impure --json --expr '
  let f = builtins.getFlake "git+file:///home/zixar/nixos-zixar";
  in map (d: d.file)
     f.nixosConfigurations.nixos.options.qt.platformTheme.definitionsWithLocations'
```

Kök `CLAUDE.md`'nin "grep/okuma ile türetilen bulgu, bir şey çalıştırılana kadar bulgu
değildir" kuralının modül-sistemi versiyonu budur.

#### Yeni sızıntı: QT_STYLE_OVERRIDE

Aynı uyanma yüzünden `QT_STYLE_OVERRIDE=breeze` artık **sistem geneli** — Caelestia
oturumundaki Qt uygulamalarına da giriyor (plasma6 öncesi hiç set edilmiyordu). Bu bir
regresyon *olmayabilir*: Stylix'in qt hedefi tam olarak bunu istiyor ve renkleri
kanagawa-dragon'dan alıyor, yani kök `CLAUDE.md`'nin "Stylix tek kaynak" kuralıyla
uyumlu. Kapatmak istenirse tek satır (`plasma.nix` içine):

```nix
qt.style = lib.mkForce null;
```

`breeze` paketi plasma6'nın kendi `systemPackages`'ından geldiği için kaybolmaz
(`plasma6.nix:129`, doğrulandı).

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
