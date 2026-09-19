# ARŞİV — KDE Plasma 6, karantinalı ikinci oturum (24 Ağu – 16 Eyl 2026)

> **DONMUŞ.** Plasma 16 Eyl 2026'da ağaçtan çıkarıldı; yerine GNOME geldi
> (`system/desktop/gnome.nix`). Aşağıdaki yollar, dosya adları ve durumlar
> KASITLI olarak eskidir — `system/desktop/plasma.nix` artık yok. Burası neden
> öyle kurulduğunun ve neyin ölçüldüğünün kaydıdır; "düzeltme".
>
> Devralınan üç şey GNOME modülünde yaşamaya devam ediyor: karantina sözleşmesi
> (oturum dışına sızan kapatılır), DRM guard zorunluluğu (sözdizimi orada udev
> etiketi), ve ölçülmemiş kalan soru — oturumun güç yığını ile
> `power-display.nix` arasındaki sahiplik yarışı.

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
