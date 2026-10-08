# AERO X16 1VH — klavye aydınlatması (HID LampArray)

Ölçüm tarihi: 2026-07-29. Modül: `system/drivers/input/keyboard-rgb/`.

Klavye **standart HID LampArray** (Usage Page 0x59) konuşuyor ve firmware onu
eksiksiz implemente etmiş — renk kontrolü DSDT kazısı ya da EC tahmini
gerektirmiyor. Ayrıca Gigabyte'ın satıcı protokolünü (`0xFF01`) konuşuyor ve
orada **per-key renk + 13 donanım modu** var; LampArray tek bölge sunar. İkisi de
kullanımda: `kbd-rgb` LampArray'de, OpenRGB satıcı kanalında.

## Neden WMI/EC değil

İlk aday `wmi-ec.md`'de haritalanmış WMBD `0xF6` (`KBLL = Arg2`, MOF adı
`SetKeyBoardBackLight`, EC alanı `@0x31`) idi. Elendi:

- `aorus-laptop` sürücüsünde klavye desteği yoktu (`KBLL`/`backlight`/`brightness`
  kaynakta hiç geçmiyor); `/sys/class/leds/` altında `kbd_backlight` düğümü yok.
- `0xF6` tek bayt → en iyi ihtimalle parlaklık, renk değil.
- Canlı test: WMBD `0xF6`'ya 0–4 yazıldı, WMBC `0xF6` geri okuması yazılan değeri
  döndürdü (register tutuyor), görsel etki yok. Test aydınlatma kapalıyken
  yapıldığı için belirsiz kalmıştı; 16 Eyl 2026'da kapandı — KBLL ölü (bkz.
  "Açık sorular").

`paul-ridgway/aero-keyboard` eski Aero 15 HID protokolü. 2026-07'de "OpenRGB bu
nesli desteklemiyor" denmişti; **yanlıştı** (19 Eyl 2026) — protokolü biliyor,
yalnız PID listesinde bizimki yoktu. Bkz. "Satıcı protokolü (0xFF01)".

## Cihaz profili (ölçülen)

USB `0414:8104` ("GIGABYTE USB-HID Keyboard"), 5 arayüz. `.0009` arayüzü
LampArray (`/dev/hidrawN`, **numara kararlı değil**). `.0006` ve `.0008` satıcı
tanımlı 64-baytlık borular (`0xFF00`/`0xFF01`).

`LampArrayAttributesReport` (id=1) çıktısı:

| Alan | Değer | Yorum |
|---|---|---|
| `LampCount` | **1** | LampArray'de tek bölge. CİHAZ için değil: satıcı kanalı per-key sürüyor (19 Eyl 2026) |
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

**Firmware metadata'sı güvenilmez:** `Kind=Notification` ve 1.2×1.6 cm'lik kutu
küçük bir durum LED'ini işaret ediyordu, renkler ise **tüm klavyede** çalışıyor.

**`IntensityLevelCount = 1`:** rapordaki Intensity baytı işlevsiz; parlaklık RGB
ölçeklenerek yapılır (`(255,0,0)` → `(64,0,0)`). Araç bu yüzden "temel renk +
yüzde" durumu tutar — yoksa parlaklığı düşürmek rengi geri dönülmez biçimde
kaybettirirdi.

## Satıcı protokolü (0xFF01) — gerçek yetenek BURADA (19 Eyl 2026)

### Nasıl bulundu

OpenRGB'nin `GigabyteAorusLaptopController`'ının desteklenen PID listesi
`7A3F`/`7A42`/`7A43`/`7A44` (Aorus 17X ve 15BKF); bizimki `8104`. Protokolün bizde
geçerli olduğu ölçümle saptandı:

| OpenRGB detector | Bizim klavye |
|---|---|
| arayüz 3, usage page `0xFF01`, usage `0x01` | input3 = `0xFF01`, usage `0x01` |
| 8 baytlık feature report, Report ID YOK | descriptor `95 08 b1 02`, unnumbered |
| parlaklık `0x00`..`0x32` | Fn+Space ölçümü: `0x00, 0x18, 0x20, 0x32` |

Üçüncü satır belirleyici: Fn+Space'in bildirdiği değerler tam olarak bu
protokolün parlaklık ölçeği ve `0x32` onun tavanı (`fn-keys.md`, tür 1 kanalı).

### Ölçülen yetenek

`system/drivers/input/openrgb.nix` PID'i detector'e ekliyor (tek satırlık
`postPatch`, protokol kodu değişmiyor). Sonuç:

```
0: Gigabyte AERO X16 Keyboard
   Location: HID: /dev/hidraw8    Serial: AP0000000003
   Modes: Direct Static Breathing 'Rainbow Wave' 'Spectrum Cycle' Droplet
          Spiral Reactive Marquee 'Circle Marquee' 'Rainbow Marquee' Ripple
          Hedge Custom
   Zones: Keyboard, 'Keyboard layout'
   LEDs:  'Key: Escape' 'Key: F1' … 'Key: Space' …   (tüm tuşlar tek tek)
```

Seri numarası cihazdan **okundu** → iletişim çift yönlü. LED listesi **per-key**.

### Paket biçimi

8 baytlık feature report, checksum korumalı:

```
Direct:  08 01 RR GG BB Br 00 Ch        Br = 0x00..0x32
Mode:    08 00 M  Sp Br Cl Dr Ch        Sp = 0x01..0x09 hız
                                        Dr = 1 sağ, 2 sol, 3 yukarı, 4 aşağı
Ch = 0xFF - (bayt 1..7 toplamı), 8 bit
```

`Custom` modu (`0x33`) renk **ve konum** dizisi alır — özel tema bu kapıdan
geçiyor. Mod değerleri: OpenRGB kaynağında
`Controllers/GigabyteAorusLaptopController/`. Canlı Direct paketi
(`HIDIOCSFEATURE`) kabul edildi.

### Açık mimari sorusu — İKİ YAZAR

| Yol | Ne sunuyor | Kim kullanıyor |
|---|---|---|
| LampArray (`hidraw9`) | tek bölge, 8-bit renk, AutonomousMode anahtarı | `kbd-rgb`, Stylix köprüsü |
| Satıcı 0xFF01 (`hidraw8`) | **per-key**, 13 donanım modu, hız/yön | OpenRGB |

İkisi birbirinden habersiz; aynı anda yazıldığında hangisinin kazandığı
**ölçülmedi**. Karar bekleyen soru: `kbd-rgb` satıcı protokolüne taşınsın mı?
Taşınırsa Stylix rengi per-key yeteneğiyle birleşir (ör. palet renklerini tuş
bölgelerine dağıtmak), ama sıfır bağımlılık sadeliği ve AutonomousMode devralma
mantığı yeniden yazılır.

## Protokol (LampArray)

Feature report'ları (`HIDIOCSFEATURE`/`HIDIOCGFEATURE`); kullanılanlar: id 1/3
okuma, id 5 `LampRangeUpdateReport` (aralığa tek renk), id 6
`LampArrayControlReport` (`AutonomousMode` 0/1).

Akış: `AutonomousMode=0` → `LampRangeUpdate` (flags=1 `LampUpdateComplete`) → iş
bitince `AutonomousMode=1`. **`AutonomousMode=0` yazılmadan renk yazmak işe
yaramaz** — firmware kendi efektiyle üstüne yazar.

## Mimari

- **`package.nix` + `src/main.rs`** — `kbd-rgb` aracı. `ioctl` elle bildirildiği
  için **sıfır crate bağımlılığı**: `rustc -O main.rs` yetiyor. Kapanışa katkı
  453 KiB; `rustc` yalnız `nativeBuildInputs`.
- **Cihaz keşfi descriptor imzasından** — `/sys/class/hidraw/*/device/report_descriptor`
  içinde `05 59 09 01 A1 01` aranır. `/dev/hidrawN` numarası boot'tan boot'a
  değişir, sabit yol yazma.
- **udev `TAG+="uaccess"`** — `/dev/hidraw`'ı oturumdaki kullanıcıya açar;
  root+polkit zincirine gerek yok.

  ⚠️ **Kural `70-kbd-rgb.rules`'ta olmak ZORUNDA, `extraRules` ile DEĞİL.**
  `services.udev.extraRules` `99-local.rules`'a yazar; etiketi ACL'e çeviren
  kural `73-seat-late.rules`'ta ve 73, 99'dan önce çalışır → ACL hiç uygulanmaz.
  **Belirti:** `sudo kbd-rgb` çalışır ama kullanıcı olarak "Permission denied".
  29 Tem'de yaşandı; `services.udev.packages` ile 70-öneki kullanılarak çözüldü.
- **`kbd-rgb-anim@.service`** (kullanıcı servisi, şablon) — `wantedBy` YOK,
  boot'ta/oturumda açılmaz (4.28 W boşta bütçesi). `ExecStopPost` firmware
  efektlerini iade eder, Rust tarafında sinyal yakalamaya gerek kalmaz.
- **Tema entegrasyonu — üçüncü kuşak (11 Eyl 2026).** Renk doğrudan **Stylix
  paletinden**: `kbd-rgb-theme.service` (kullanıcı servisi, `system.nix`, `Type =
  oneshot`, `wantedBy = graphical-session.target`) oturum açılışında bir kez
  `kbd-rgb set <base0D>` çağırır — hem COSMIC'te hem GNOME'da, boşta maliyet sıfır.

  **Neden üç kuşak oldu:** köprü iki kez sessizce koptu, çünkü iki kez de çağrıyı
  yapan taraf repo dışındaki bir tema motoruydu — 1. kuşak (–9 Ağu 2026): matugen
  `[templates.keyboard]` + `post_hook`; 2. kuşak (9 Ağu – Eyl 2026): Caelestia
  tema motoru + `theme.postHook`. 3. kuşakta sahibi bu repo: Stylix değeri eval
  zamanında gömülü, arada şablon dosyası, state dizini ya da üçüncü parti hook yok.
- **Animasyon durumu 0.5 sn'de bir tazeler** — animasyon dönerken renk/parlaklık
  değişirse efekt uyum sağlar; iki yazarın aynı lambayı çekiştirip titretmesi
  önlenir.

## Kontrol yolları

**Model (19 Eyl 2026): iki yol, tek durum dosyası.** (Hyprland dönemi
`SUPER+ALT+Z/X/C/V` bind'ları ağaçla birlikte gitti, yerine bir şey istenmedi.)

| Yol | Ne için | Nerede yaşıyor |
|---|---|---|
| **Fn+Space** | dört kademe: kapalı → düşük → orta → yüksek → başa | `system/arch/aerox16/fn-keys.nix` köprüsü (0xFF02 tür 1) |
| **aero-control GUI** | tam ayar: renk, parlaklık, animasyon, ön ayar | `~/aero-eg61h/app/aero-control` |

İkisi de `kbd-rgb`'yi ve `$XDG_STATE_HOME/kbd-rgb/state`'i kullanır — tek gerçek
kaynak orası.

CLI: `kbd-rgb info|status [--json]|set <renk>|on|off|toggle|bright <+N|-N|N>|auto <on|off>|anim <mod>`

`status --json` cihaz **takılı değilken de** çalışır (`device:null` döner).

Fn+ok tuşlarında aydınlatma **yok** (PageUp/PageDown/Home/End üretiyor, ölçüldü,
`fn-keys.md`); aç/kapa ve parlaklığın tek tuşu Fn+Space.

### Fn+Space ve AutonomousMode — ÖLÇÜLDÜ (19 Eyl 2026)

Klavyenin kendi aydınlatma tuşu ışık **firmware kontrolündeyken** çalışır ve **biz
devraldığımızda ölür**: `kbd-rgb auto on` sonrası tuş canlandı; `kbd-rgb set …`
(`AutonomousMode=0`) yazılıyken görünür etkisi yoktu.

**Ama bu bir takas DEĞİL.** Tuş `AutonomousMode=0` iken de 0xFF02'ye rapor
düşürüyor (kanıt: `fn-keys.md`, tür 1 kanalı, 15:28 kayıtları). Raporu yakalayıp
rengi kendimiz değiştirerek Stylix rengi + çalışan Fn tuşu birlikte alınıyor.

### COSMIC kısayolları

COSMIC'te kısayol **imperatif** tanımlanır (Ayarlar → Klavye → Kısayollar);
`~/.config/cosmic`'e Nix'ten yazmak yasak — bilinçli eksik.
Bağlanacak komutlar: `kbd-rgb toggle`, `kbd-rgb bright +10`, `kbd-rgb bright -10`,
`kbd-anim breathe`, `kbd-anim rainbow`.

## Durum dosyası

`$XDG_STATE_HOME/kbd-rgb/state` — tek satır, üç alan: `<hex> <yüzde> <on|off>`.

Üçüncü alan **19 Eyl 2026'da** eklendi (öncesinde `off` yalnız (0,0,0) yazıyordu,
geri açılacak renk saklanmadığından `toggle` yazılamıyordu). Üçüncü alan yoksa
eski iki alanlı biçimdir ve `on` varsayılır.

Yazma **atomik** (tmp + rename): üç yazar var (`kbd-rgb-theme` oturum servisi,
Fn köprüsü, GUI) ve animasyon döngüsü dosyayı 0.5 sn'de bir okuyor.

⚠️ **Köprü root koşuyor.** `state_file()` `$HOME`'a bağlı olduğu için
`fn-keys.nix` servise `XDG_STATE_HOME`'u kullanıcıya sabitler; yoksa root
`/root/.local/state`'e yazar ve iki ayrı "gerçek" oluşur.

## Açık sorular

- **Boot/uyanma sonrası renk geri yüklenmiyor.** Firmware her açılışta
  `AutonomousMode=1`'e dönüyor; `kbd-rgb-theme.service` yalnız oturum açılışında
  koşuyor. Tek atışlık bir `systemd-sleep` post hook'u eklenebilir (4.28 W bütçesi'ya
  uyar); şimdilik kasten eklenmedi.
- **`0xF6` KBLL ölü (kapandı).** `fn-keys.md` (16 Eyl 2026) aydınlatma YANARKEN
  alanı 0 okudu → aydınlatmayı sürmüyor; renk yolu LampArray.
- **Fn kilidi (Fn+Esc, kod `0x95`) ile aydınlatma ilişkisi.** Kilit açıkken
  Fn+Space hâlâ tür 1 raporu gönderiyor mu? Ölçülmedi; 19 Eyl ölçümünde Fn+Esc
  sonrası adımlar bu yüzden boş göründü.
