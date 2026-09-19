# AERO X16 1VH — klavye aydınlatması (HID LampArray)

Ölçüm tarihi: 2026-07-29. Modül: `system/drivers/input/keyboard-rgb/`.

Kısa özet: klavye **standart HID LampArray** (Usage Page 0x59) konuşuyor. Bu
yüzden renk kontrolü, bu repodaki fan/güç işlerinin aksine, DSDT kazısı ya da
EC tahmini gerektirmiyor — yayımlanmış bir spesifikasyon var ve firmware onu
eksiksiz implemente etmiş.

## Neden WMI/EC değil

İlk aday `Documentation/aerox16/wmi-ec.md`'de zaten haritalanmış olan WMBD `0xF6`
(`KBLL = Arg2`, MOF adı `SetKeyBoardBackLight`, EC alanı `@0x31`) idi. Elendi:

- `aorus-laptop` sürücüsünde klavye desteği **yok** — ne sysfs düğümü, ne
  `led_classdev`. Derlenmiş `.ko`'nun string'lerinde ve upstream kaynakta
  `KBLL`/`backlight`/`brightness` hiç geçmiyor.
- `/sys/class/leds/` altında yalnız capslock/numlock/scrolllock var;
  `kbd_backlight` düğümü **yok**.
- `0xF6` tek bayt → en iyi ihtimalle parlaklık, **renk değil**.
- Canlı test: WMBD `0xF6`'ya 0–4 yazıldı, WMBC `0xF6` geri okuması yazılan
  değeri **doğru döndürdü** (register tutuyor), ama görsel etki gözlenmedi.
  ⚠️ Test aydınlatma KAPALIYKEN yapıldığı için **sonuç belirsizdir** — KBLL'in
  ölü mü yoksa Fn+Space'in master anahtarına tabi mi olduğu çözülmedi. Renk
  yolu LampArray'de bulunduğu için bu soru takip edilmedi.

Hazır araç durumu da elverişsizdi: OpenRGB bu nesil Gigabyte klavyelerini
desteklemiyor, `paul-ridgway/aero-keyboard` eski Aero 15 HID protokolü.

## Cihaz profili (ölçülen)

USB `0414:8104` ("GIGABYTE USB-HID Keyboard"), 5 arayüz. `.0009` arayüzü
LampArray; `/dev/hidraw8` (**numara kararlı değil**, aşağıya bak).

Diğer arayüzler: `.0006` ve `.0008` satıcı tanımlı 64-baytlık boru
(`0xFF00`/`0xFF01`) — muhtemelen RGB Fusion'ın özel kanalı, kurcalanmadı.

`LampArrayAttributesReport` (id=1) çıktısı:

| Alan | Değer | Yorum |
|---|---|---|
| `LampCount` | **1** | Tek bölge → tuş-başına efekt İMKÂNSIZ |
| Sınırlayıcı kutu | 12000 × 16000 × 2000 µm | **YANLIŞ** (1.2 × 1.6 cm) |
| `LampArrayKind` | 6 = Notification | **YANLIŞ** (1 = Keyboard olmalıydı) |
| `MinUpdateInterval` | 100 µs | 60 FPS animasyona fazlasıyla yeter |

Lamba #0 öznitelikleri (`LampAttributesResponseReport`, id=3):

| Alan | Değer | Sonuç |
|---|---|---|
| R/G/B kademe | 255 / 255 / 255 | Tam 8-bit renk |
| `IntensityLevelCount` | **1** | **Ayrı parlaklık kanalı YOK** |
| `IsProgrammable` | 1 | — |
| `LampPurposes` | 0x1 (Control) | Beklenen 0x10 (Illumination) idi |
| `InputBinding` | 0x00 | Tuş eşlemesi yok |

**Firmware metadata'sı güvenilmez.** `Kind=Notification` ve 1.2×1.6 cm'lik kutu
küçük bir durum LED'ini işaret ediyordu; canlı test ise renklerin **tüm
klavyede** çalıştığını gösterdi. Üretici alanları özensiz doldurmuş — bu
cihazda metadata'ya değil ölçüme güven.

**`IntensityLevelCount = 1`'in pratik sonucu:** rapordaki Intensity baytı
işlevsiz. Parlaklık ancak RGB değerlerini ölçekleyerek yapılabilir
(`(255,0,0)` → `(64,0,0)`). Araç bu yüzden "temel renk + yüzde" durumu tutar;
yoksa parlaklığı düşürmek rengi geri döndürülemez biçimde kaybettirirdi.

## Protokol (USB HID Usage Tables v1.4 §26)

Feature report'ları, `HIDIOCSFEATURE`/`HIDIOCGFEATURE` ioctl'i ile:

| ID | Rapor | Boyut | Kullanım |
|---|---|---|---|
| 1 | `LampArrayAttributesReport` | 23 B | oku: lamba sayısı, tür |
| 2 | `LampAttributesRequestReport` | 3 B | yaz: lamba seç |
| 3 | `LampAttributesResponseReport` | 29 B | oku: konum, kademeler |
| 4 | `LampMultiUpdateReport` | 51 B | 8 lambaya ayrı renk (burada gereksiz) |
| 5 | `LampRangeUpdateReport` | 10 B | **yaz: aralığa tek renk** |
| 6 | `LampArrayControlReport` | 2 B | **yaz: `AutonomousMode` 0/1** |

Akış: `AutonomousMode=0` (firmware efektlerini devral) → `LampRangeUpdate`
(flags=1 `LampUpdateComplete` → atomik uygula) → iş bitince `AutonomousMode=1`.

**`AutonomousMode=0` yazılmadan renk yazmak işe yaramaz** — firmware kendi
efektiyle üstüne yazar.

## Mimari

- **`package.nix` + `src/main.rs`** — `kbd-rgb` aracı. `ioctl` elle bildirildiği
  için **sıfır crate bağımlılığı**: cargo/`Cargo.lock`/`cargoHash`/vendoring
  zinciri hiç kurulmuyor, `rustc -O main.rs` yetiyor. Kapanışa katkı 453 KiB;
  `rustc` yalnız `nativeBuildInputs`, runtime kapanışına girmiyor.
- **Cihaz keşfi descriptor imzasından** — `/sys/class/hidraw/*/device/report_descriptor`
  içinde `05 59 09 01 A1 01` aranır. **`/dev/hidrawN` numarası boot'tan boot'a
  değişir**, asla sabit yol yazma.
- **udev `TAG+="uaccess"`** — `/dev/hidraw`'ı oturum açmış kullanıcıya açar.
  `fan_mode`'un root+polkit+systemd zincirine burada gerek YOK, çünkü orada
  sysfs düğümü root'a sabitti.

  ⚠️ **Kural `70-kbd-rgb.rules`'ta olmak ZORUNDA, `extraRules` ile DEĞİL.**
  `services.udev.extraRules` `99-local.rules`'a yazar; systemd'nin etiketi
  ACL'e çeviren kuralı `73-seat-late.rules`'ta ve udev dosyaları leksik
  sırayla işlendiği için 73, 99'dan önce çalışır → etiket geç eklenir, ACL
  hiç uygulanmaz. **Belirti:** `sudo kbd-rgb` çalışır ama kullanıcı olarak
  "Permission denied". 29 Tem'de bizzat yaşandı; `services.udev.packages`
  ile 70-öneki kullanılarak çözüldü.
- **`kbd-rgb-anim@.service`** (kullanıcı servisi, şablon) — `wantedBy` YOK,
  boot'ta/oturumda AÇILMAZ. **4.28W idle bütçesi** gereği: idle'da dönen hiçbir
  şey olamaz. `ExecStopPost` firmware efektlerini iade eder, böylece Rust
  tarafında sinyal yakalamaya gerek kalmaz.
- **Tema entegrasyonu — üçüncü kuşak (11 Eyl 2026).** Renk artık doğrudan
  **Stylix paletinden** geliyor: `kbd-rgb-theme.service` (kullanıcı servisi,
  `system.nix`) oturum açılışında bir kez `kbd-rgb set <base0D>` çağırır.
  `wantedBy = graphical-session.target` olduğu için hem COSMIC'te hem Plasma'da
  çalışır; `Type = oneshot` olduğu için yazdıktan sonra süreç ölür → idle
  maliyeti sıfır. Palet `lib/theme.nix`'te değişince rebuild sonrası kendiliğinden
  takip eder.

  **Neden üç kuşak oldu — buradaki ders:** bu köprü iki kez sessizce koptu,
  çünkü her iki kez de çağrıyı YAPAN taraf repo dışındaki bir tema motoruydu.
  1. kuşak (–9 Ağu 2026): matugen `[templates.keyboard]` + `post_hook`.
  2. kuşak (9 Ağu – Eyl 2026): Caelestia'nın tema motoru + `theme.postHook`.
  3. kuşak (bugün): sahibi bu repo — Stylix değeri eval zamanında gömülü, arada
  şablon dosyası, state dizini ya da üçüncü parti hook yok. Kopacak bir halka
  kalmadı.
- **Animasyon durumu 0.5 sn'de bir tazeler** — böylece animasyon dönerken
  tema rengi değiştirse ya da parlaklık bind'ına basılsa efekt canlı uyum
  sağlar; iki yazarın aynı lambayı çekiştirip titretmesi önlenir.

## Kontrol yolları

**Model (19 Eyl 2026): iki yol, tek durum dosyası.** Eski `SUPER+ALT+Z/X/C/V`
bind tablosu bu defterden ÇIKARILDI — Hyprland ağaçtan çıkınca o bind'lar zaten
gitmişti ve kullanıcı yerlerine bir şey istemedi. Yerine gelen iki yol:

| Yol | Ne için | Nerede yaşıyor |
|---|---|---|
| **Fn + kombinasyon** | hızlı işlem: aç/kapa, parlaklık ± | `system/arch/aerox16/fn-keys.nix` köprüsü (0xFF02 tür 1) |
| **aero-control GUI** | tam ayar: renk, parlaklık, animasyon, ön ayar | `~/aero-eg61h/app/aero-control` |

İkisi de aynı aracı (`kbd-rgb`) ve aynı durum dosyasını
(`$XDG_STATE_HOME/kbd-rgb/state`) kullanır — tek gerçek kaynak orasıdır.

CLI: `kbd-rgb info|status [--json]|set <renk>|on|off|toggle|bright <+N|-N|N>|auto <on|off>|anim <mod>`

`status --json` GUI ve betikler içindir; cihaz **takılı değilken de** çalışır
(`device:null` döner, hata vermez).

### Fn+Space ve AutonomousMode — ÖLÇÜLDÜ (19 Eyl 2026)

Klavyenin kendi aydınlatma tuşu, ışık **firmware kontrolündeyken** çalışır ve
**biz devraldığımızda ölür**. Ölçüm: `kbd-rgb auto on` yazıldıktan sonra tuş
canlandı; `kbd-rgb set …` (yani `AutonomousMode=0`) yazılı durumdayken hiçbir
görünür etki yapmıyordu.

**Ama bu bir takas DEĞİL.** Firmware tuşu görmeyi ve raporlamayı sürdürüyor;
yalnız ışığa dokunamıyor. Tuş `AutonomousMode=0` iken de 0xFF02'ye rapor
düşürüyor (kanıt: `fn-keys.md`, tür 1 kanalı, 15:28 kayıtları bizim
kontrolümüzdeyken alındı). Yani raporu yakalayıp rengi kendimiz değiştirerek
**her iki dünyayı da** alabiliyoruz: Stylix rengi + çalışan Fn tuşu.

### COSMIC kısayolları

COSMIC tarafında kısayol **imperatif** tanımlanır (Ayarlar → Klavye →
Kısayollar). `~/.config/cosmic` altına Nix'ten yazmak YASAK (kök `CLAUDE.md`),
bu yüzden burada deklaratif bir karşılığı olamaz — bilinçli bir eksiktir.
Bağlanacak komutlar: `kbd-rgb toggle`, `kbd-rgb bright +10`, `kbd-rgb bright -10`,
`kbd-anim breathe`, `kbd-anim rainbow`.

## Durum dosyası

`$XDG_STATE_HOME/kbd-rgb/state` — tek satır, üç alan: `<hex> <yüzde> <on|off>`.

Üçüncü alan **19 Eyl 2026'da** eklendi. Öncesinde `off` yalnız (0,0,0) yazıyor,
duruma hiç dokunmuyordu; "hangi renge geri açacağız" bilgisi hiçbir yerde
saklanmadığı için `toggle` yazılamıyordu. Üçüncü alan yoksa dosya eski iki
alanlı biçimdedir ve `on` varsayılır — eski dosyalar kırılmaz.

Yazma **atomik** (tmp + rename): dosyanın artık üç yazarı var (`kbd-rgb-theme`
oturum servisi, Fn köprüsü, GUI) ve animasyon döngüsü onu 0.5 sn'de bir okuyor.

⚠️ **Köprü root koşuyor.** `state_file()` `$HOME`'a bağlı olduğu için
`fn-keys.nix` servise `XDG_STATE_HOME`'u kullanıcıya sabitler; yoksa root kendi
`/root/.local/state`'ine yazar ve iki ayrı "gerçek" oluşur.

## Açık sorular

- **Boot/uyanma sonrası renk geri yüklenmiyor.** Firmware her açılışta
  `AutonomousMode=1`'e dönüyor; `kbd-rgb-theme.service` yalnız oturum açılışında
  bir kez koşuyor. Uyandıktan sonrası için `systemd-sleep` post hook'u
  eklenebilir — tek atışlık olduğu için idle maliyeti sıfır (CLAUDE.md kural 6'ya
  uyar). Şimdilik kasten eklenmedi.
- **`0xF6` KBLL ölü.** `fn-keys.md` (16 Eyl 2026) aydınlatma YANARKEN alanı 0
  okudu → bu alan aydınlatmayı sürmüyor. Bu defterin eski "belirsiz" notu
  kapandı; renk yolu LampArray'dir.
- **Tür 1 kod sözlüğü eksik.** 0xFF02'nin aydınlatma kanalında `0x00, 0x18,
  0x20, 0x32` kodları görüldü ama hangisinin hangi tuş/seviye olduğu
  ölçülmedi. Protokol ve tablo: `fn-keys.md`.
