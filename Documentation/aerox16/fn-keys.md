# AERO X16 EG61H — Fn tuş kombinasyonları: kanallar, EC'nin payı, sınırlar

Keşif tarihi: **16 Eyl 2026**. Kaynaklar: BIOS paketinden çıkarılmış EC imajı
(`EG61H-EC-F00A.bin`, 160 KiB), `dsdt.dsl.txt`, canlı sistem (sysfs/HID/acpi_call).
Fan/güç tarafı bu defterde YOK — o `wmi-ec.md`'de.

## Tek cümlelik hüküm

**Fn tuş matrisi EC'de değil ve EC bu işin içinde hiç yok.** Kombinasyonlar
dahili klavyenin kendi USB denetleyicisinde (`0414:8104`) çözülüyor; on iki
kombinasyonun tamamı ölçüldü ve **hiçbiri** EC olay kanalını tetiklemedi.
EC firmware'inden Fn eşlemesi değiştirilemez; kazanç, **klavyenin gönderdiğini
Linux tarafında yakalayıp bağlamakta** — üçü satıcı kanalında ölü, üçü yalnız
kısayol bekliyor.

## Bir Fn basımının çıkabileceği dört kanal

| # | Kanal | Nerede görünür | Linux şu an ne yapıyor |
|---|---|---|---|
| 1 | Standart HID klavye / consumer raporu | `hidraw5`/`hidraw7`, evdev | evdev tuşuna çevriliyor — **çalışıyor** |
| 2 | **Satıcı sayfası 0xFF02, Report ID 4 (3 bayt)** | yalnız `hidraw7` ham | çekirdek yok sayıyor — `aero-fn-bridge` köprüsü yakalıyor |
| 3 | Wireless Radio Control (Report ID 7) | evdev `event16` | `KEY_RFKILL` |
| 4 | EC → `_Q45` → WMI olayı | `journalctl -k` | `aero_eg61h` logluyor, **eyleme bağlı değil** |

Dört kanalın hiçbirinde görünmeyen kombinasyonu klavye denetleyicisi kendi
içinde yutuyor (ör. RGB efekt değişimi); yazılımdan erişilemez.

## Klavye HID haritası (descriptor'dan okundu, 16 Eyl 2026)

`0414:8104`, beş arayüz. `scripts/fn-probe.pl --list` bu tabloyu canlı üretir
(hidraw numaraları **kararlı değil**, rol etiketine bak).

| Arayüz | Rol | İçerik |
|---|---|---|
| input0 | klavye | LED çıkışı + 6KRO + 224-bit NKRO |
| input1 | satıcı 0xFF00 | 64 B giriş / 64 B çıkış borusu (RGB Fusion / GCC kanalı) |
| input2 | **karma** | ID 1 fare, **ID 3 consumer (usage 0x000-0x7FF)**, **ID 4 satıcı 0xFF02 3 B**, ID 5 NKRO klavye, ID 6 mutlak konum, **ID 0x5A satıcı 0xFF89 16 B feature**, ID 7 telsiz düğmesi |
| input3 | satıcı 0xFF01 | 64 B g/ç + 8 B feature |
| input4 | LampArray | tek bölge RGB (`keyboard-rgb.md`) |

- Consumer kanalı **tüm 0x000-0x7FF aralığını** deklare ediyor; evdev'deki tuş
  adı klavyenin yeteneğini değil, o an gönderdiğini anlatır.
- `ID 0x5A` feature bloğu `00 FF FF FF … FF` (hepsi 0xFF) döndü, `input3`'ün
  8 B feature'ı sıfır — ikisi de ayar saklamıyor.

## EC → OS olay zinciri (DSDT'den birebir)

```
EC   →  PECM+0x01 = WEVS (durum), PECM+0x02 = WEVN (olay no)   [0xFC7E0800]
     →  SCI, query 0x45
_Q45 →  SMGR (WEVN, WEVS)                                       dsdt.dsl:8334
SMGR →  AMW0.DSDC(WEVN, WEVS)  → DEVS[0]=WEVN, DEVS[1]=WEVS     dsdt.dsl:9740
     →  AMW0.WMBC(0, 0x03, WEVN) → Notify (AMW0, 0xD2)          dsdt.dsl:9525
_WED(0xD2) → DEVS (4 bayt: WEVN, WEVS, 0xBB, 0xCC)              dsdt.dsl:9721
```

Olay GUID'i `_WDG`'nin son kaydı: **ABBC0F72-8EA1-11D1-00A0-C90629100000**,
notify 0xD2, flags 0x08. Canlı: `/sys/bus/wmi/devices/ABBC0F72-…-3`, sürücüsü
`aero_eg61h_evt` (`kernel/aero-main.c:411`, `min_event_size = 2`).
`SMGR`'de tek istisna: `WEVN == 0xF7` ise DEVS güncellenmez, yalnız notify gider.

### Canlı kanıt (journal)

```
Eyl 15 23:26:49  EC olayi: no=0xef durum=0x00
Eyl 16 14:18:26  EC olayi: no=0xef durum=0x01     ← hemen ardından "uyanis" satırı
```

**Hipotez (doğrulanmadı):** `WEVN` = değişen özelliğin **WMBC selector numarası**,
`WEVS` = yeni değeri. `0xEF` = `GetLid1Status` (`wmi-ec.md`, WMBC tablosu) ve iki
olay kapak kapanışı/açılışıyla örtüşüyor.

## EC'nin klavye/Fn düğmeleri — canlı değerler (16 Eyl 2026)

`acpi_call` ile `\_SB.PCI0.SBRG.EC0.<alan>` okundu (salt okuma):

| Alan | PECM | Değer | Not |
|---|---|---|---|
| FNKS | 0x07.0 | **1** | dahili klavye ana şalteri (0 = tüm raporlar kesilir; `wmi-ec.md` Faz E) |
| FESC | 0xA1.0 | 0 | DSDT'de **yazan WMI selector'ü yok** — adı "Fn+Esc" imâ ediyor, doğrulanmadı |
| WINK | 0xA1.1 | 0 | WMBD **0xCB** yazıyor — Windows/Super tuşu kilidi adayı, test edilmedi |
| BTKY | 0xA1.2 | 0 | yazan selector yok; anlamı bilinmiyor |
| MUTE | 0x30.0 | 0 | WMBD 0xC7 |
| KBAT | 0x30.2 | 0 | WMBD 0xD9 — klavye aydınlatma zamanlayıcısı |
| KBLL | 0x31 | **0** | WMBD 0xF6; **klavye ışığı yanarken 0** → aydınlatmayı sürmüyor (KBLL ölü, renk yolu LampArray — `keyboard-rgb.md`) |
| LCDO | 0x10.7 | 0 | LCD overdrive |

`DSMD/QBMD/DDSS` (PECM 0x2D) tanımlı ama okunmadı; `DSMD`'yi OS `_REG` sırasında
sıfırlıyor (`dsdt.dsl:7724`) — "OS devraldı" bayrağı olabilir, kanıt yok.

## EC imajından çıkanlar — ve çıkmayanlar

`EG61H-EC-F00A.bin`: 8051 kodu, 0x28000 bayt, 0x00000'da `LJMP 0x2790`.
Yöntem: `MOV DPTR,#imm16` histogramı + hedefli disassembly.

**Bulundu**
- Fan eğrisi tabloları (0x058DA-0x05Bxx) — `~/Downloads/aero-ec/curve-region.txt`
  ile aynı bölge, yeni bilgi yok.
- Hata ayıklama metinleri yalnız USB-PD/UCSI ve uyandırma tarafında:
  `Wakeup by IKB` (dahili klavye), `Wakeup by CIR/WDT/TMR`, UCSI komut adları.

**Bulunamadı — ve yokluğu bulgu**
- **Hiçbir HID report descriptor'ı yok** (`05 01 09 06`, `05 0C 09 01`, `05 59`
  desenleri sıfır eşleşme) → dahili klavye EC'nin USB aygıtı DEĞİL, Fn matrisi
  ve Fn-layer tablosu EC imajında yok.
- SCI query kodlarının (0x10-0x60) ortak bir "push" fonksiyonu ya da tablosu
  yok; query gönderimi kod içine dağılmış.
- **PECM penceresinin EC tarafındaki XRAM adresi çözülemedi.** Aday 0xE800
  (host 0xFC7E0800, 0xFC7E0500=ECM2, 0xFC7E0250=USEC üçlüsü 0x…E000+ofset
  yorumunu destekliyordu) **elendi**: 0xE801/0xE802'ye onlarca okuma/yazma var,
  WEVS/WEVN'e yakışmıyor. Bu adres bulunmadan WEVN kod sözlüğü imajdan
  çıkarılamaz — sözlüğün yolu ölçüm.

## Köprünün durumu — ÖLÇÜLDÜ (16 Eyl 2026)

`system/arch/aerox16/fn-bridge.pl` (`fn-keys.nix` `readFile` ile gömer,
`aero-fn-bridge.service` olarak udev tetikli koşar, `wantedBy` yok) 0xFF02
taşıyan düğümü descriptor'dan kendi buluyor; `uinput` aygıtı
`AERO X16 Fn koprusu` adıyla görünüyor ve üç kodun üçü de tuşa çevrildi:

```
0x92 → KEY_MICMUTE           (Fn+F4)
0x84 → KEY_PROG1             (Fn+F7, üç basış üç kez)
0x81 → KEY_TOUCHPAD_TOGGLE   (Fn+F9)
  yok sayıldı (debounce): 0x81      ← her Fn+F9 basışında bir kez
```

**Saf tuş modunda görünür etki olmadı:** COSMIC bu üç tuşa hiçbir eylem
bağlamıyor. Bu yüzden `--act` modu tuşa ek olarak eylemi de yapar — mikrofon
`wpctl` ile (kullanıcı oturumuna `runuser` ile inerek), fan
`aero-fan-cycle.service` ile, touchpad `i2c_hid_acpi` bind/unbind ile. Ölçüldü
(aynı gün): mikrofon açılıp kapandı, fan modu
`balanced → quiet → gaming → turbo → balanced` döndü, touchpad kapandı ve Ctrl-C
çıkışında güvenlik ağı geri bağladı. GNOME `KEY_MICMUTE`/`KEY_TOUCHPAD_TOGGLE`'ı
kendisi işlediği için köprü gnome-shell koşarken eylemi atlar (`gnome.nix`).
COSMIC'te kısayol tanımlanırsa `--act` gereksizleşir.

Tuzak: **Fn+F9 tek basışta iki özdeş rapor gönderiyor**; köprüdeki 250 ms
debounce bunu yutuyor. Kaldırılırsa toggle iki kez tetiklenir ve hiçbir şey
olmaz.

### Neden servis root koşuyor (ve bir gün koşmayabilir)

Hidraw düğümleri **zaten kullanıcıya açık**: `keyboard-rgb` modülünün udev
kuralı `0414:8104` için `TAG+="uaccess"` koyuyor (build çıktısında görüldü,
16 Eyl 2026). Root'u gerektiren iki şey kaldı: `/dev/uinput` ve touchpad'in
`i2c_hid_acpi` bind/unbind'ı. İkisi çözülürse köprü kullanıcı servisine inebilir
ve `runuser` de gereksizleşir.

Elle kurtarma (touchpad kapalı kaldıysa):
`sudo sh -c 'echo i2c-ELAN0A05:00 > /sys/bus/i2c/drivers/i2c_hid_acpi/bind'`.

## Ölçüm protokolü — `scripts/fn-probe.pl`

Dört kanalı aynı anda dinler, satırları ortak saat ekseninde basar:

```bash
sudo perl scripts/fn-probe.pl --list     # kanalları göster, çık
sudo perl scripts/fn-probe.pl            # dinle; Ctrl-C bitirir
```

Kural: **bir kombinasyona bas → ~2 s bekle → sıradakine geç**, yoksa satırlar
basımlara eşlenemez.

## ÖLÇÜM — 16 Eyl 2026, on iki kombinasyonun tamamı

Sembol sütunu klavyenin üzerindeki baskıdır, kanal sütunu `fn-probe.pl`
çıktısıdır. Çıplak Fn basılı tutuldukça `hidraw5` `00 00 6F` (HID 0x7006F = F20)
tekrarlıyor — hwdb `reserved` kuralı bunu susturuyor.

| Fn+ | Klavyedeki sembol | Kanal ve ham veri | evdev | Durum |
|---|---|---|---|---|
| F1 | hoparlör sustur | consumer `03 E2 00` (usage 0x0E2) | KEY_MUTE | ✔ çalışıyor |
| F2 | ses kıs | consumer 0x0EA | KEY_VOLUMEDOWN | ✔ |
| F3 | ses arttır | consumer 0x0E9 | KEY_VOLUMEUP | ✔ |
| F4 | mikrofon aç/kapa | **0xFF02 `04 00 00 92`** | — | ✘ **ÖLÜ** |
| F5 | parlaklık azalt | consumer 0x070 | KEY_BRIGHTNESSDOWN | ✔ |
| F6 | parlaklık arttır | consumer 0x06F | KEY_BRIGHTNESSUP | ✔ |
| F7 | performans + fan modu | **0xFF02 `04 00 00 84`** | — | ✘ **ÖLÜ** |
| F8 | LCD + soket (ekran çıkışı) | NKRO klavye: **Super+P** | 125, 25 | ✘ kısayol bağlı değil |
| F9 | touchpad kilidi | **0xFF02 `04 00 00 81`** + NKRO **Super+Ctrl+F24** | 125, 29, 194 | ✘ ölü |
| F10 | uçak modu | Report ID 7 `07 01` | KEY_RFKILL | ✔ |
| F11 | ekran görüntüsü | NKRO **Super+Shift+S** | 125, 42, 31 | ✘ kısayol bağlı değil |
| F12 | AI sesli sohbet | NKRO **Super+H** | 125, 35 | ✘ kısayol bağlı değil |

("ÖLÜ" = köprüden önceki durum; F4/F7/F9 artık köprüyle çalışıyor.)

### Ölçümün üç hükmü

1. **EC yok:** on iki kombinasyonun hiçbiri `_Q45` → WMI olayı üretmedi
   (journal ölçüm boyunca sessiz). EC olay kanalı kapak gibi durum değişimleri
   için.
2. **Üç tuş satıcı sayfası 0xFF02'de** (F4 0x92, F7 0x84, F9 0x81); Linux bu
   raporu evdev'e çevirmiyor → `hidraw` → `uinput` köprüsü.
3. **Üç tuş Windows kısayolu gönderiyor** (F8 Super+P, F11 Super+Shift+S,
   F12 Super+H) — evdev'e normal ulaşıyor, masaüstünde kısayol tanımlanırsa
   çalışır. COSMIC'te kısayol tanımı imperatiftir (`~/.config/cosmic`'e Nix'ten
   yazmak yasak); ölçüm anında `…Shortcuts/v1/custom` dosyası YOKTU.

Fn+F7 klavyede "performans + fan modu" diye işaretli; 12 Eyl'den beri
tetikleyicisiz duran `aero-fan-cycle.service`'in (`wmi-ec.md`) tetikleyicisi oldu.

## 0xFF02'nin İKİNCİ alt-protokolü — "tür 1" kanalı (19 Eyl 2026)

Klavye 0xFF02 / Report ID 4'te iki ayrı biçim gönderiyor; **ikinci bayt** hangisi
olduğunu söylüyor (16 Eyl ölçümü tek biçim varsaymıştı):

| Biçim | Kod nerede | Kim gönderiyor |
|---|---|---|
| `04 00 00 <kod>` | 4. bayt | Fn+F4 (0x92), Fn+F7 (0x84), Fn+F9 (0x81) |
| `04 01 <kod> 00` | **3. bayt** | aydınlatma sınıfı — kodlar aşağıda |

`fn-bridge.pl` kodu koşulsuz `$b[3]`'ten okuduğu için tür 1 raporlarının hepsi
`0x00` diye loglanıyor ve kanal görülmüyordu. Düzeltildi; debounce anahtarı da
türü taşıyor (iki tablonun kod uzayları ayrı, ikisinde de 0x00 görülebiliyor).

### Canlı kanıt (çalışan servisin journal'ı)

```
Eyl 19 15:28:10.492  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 20 00)
Eyl 19 15:28:10.764  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 32 00)
Eyl 19 15:28:11.132  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 18 00)
Eyl 19 16:29:47.011  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 20 00)
Eyl 19 16:29:47.315  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 00 00)
Eyl 19 16:29:49.283  EŞLENMEMİŞ 0xFF02 kodu: 0x00  (04 01 18 00)
```

Basışlar kullanıcının aydınlatma tuşlarını denediği anlarla örtüştü. Görülen
kodlar: **`0x00`, `0x18`, `0x20`, `0x32`** (= 0, 24, 32, 50).

**Tür 1 raporları `AutonomousMode=0` iken DE geliyor.** 15:28 kayıtları ışık
bizim kontrolümüzdeyken (oturum açılışında `kbd-rgb set` koşmuştu) alındı.
Firmware tuşu görmeyi sürdürüyor, yalnız ışığa dokunamıyor — raporu yakalayıp
rengi kendimiz değiştirebiliriz. Stylix rengi ile çalışan Fn tuşu arasında
**takas yok** (`keyboard-rgb.md`, "Fn+Space ve AutonomousMode").

### ÖLÇÜM — 19 Eyl 2026, `scripts/isik-probe.pl`

| Fn+ | Kanal ve ham veri | Yorum |
|---|---|---|
| **Space** | tür 1 `04 01 18 00`, sonra `04 01 20 00` | ardışık iki basış **artan** kademe verdi |
| yukarı / aşağı / sol / sağ | 0xFF02'ye **düşmüyor** | PageUp / PageDown / Home / End üretiyorlar — aydınlatmayla ilgisi yok |
| **Esc** | tür 0 `04 00 01 95` | **Fn kilidi**; üçüncü bayt `0x01` (bilinen üçlüde `0x00`) muhtemelen yeni kilit durumu |
| Tab, Backspace | 0xFF02'ye düşmüyor | — |
| F5 (referans) | bu betikte görünmez | consumer kanalında (Report ID 3); betik yalnız ID 4'ü süzüyor. Tuş çalışıyor. |

**Kademe tablosu** (bu ölçüm + journal kayıtları):

| Kod | Kademe |
|---|---|
| `0x00` | kapalı |
| `0x18` | düşük |
| `0x20` | orta |
| `0x32` | yüksek |

Kod bir tuş kimliği değil, **seviyenin kendisi**: Fn+Space firmware'de bu dört
kademeli döngüyü yürütür ve her adımda yeni kademeyi bildirir. Ham değerler
(0/24/32/50) firmware'in iç ölçeği; `%MAP1`'deki yüzde eşlemesi (0/33/66/100)
bizim seçimimiz.

**Parlaklık için ayrı tuş YOK.** Fn+ok tuşları aydınlatmaya dokunmuyor; aç/kapa
ve parlaklık artışının tek yolu Fn+Space döngüsü.

## Sıradaki işler (öncelik sırasıyla)

1. ~~**0xFF02 köprüsü**~~ → **YAPILDI (16 Eyl 2026)**, bkz. "Köprünün durumu".
2. **F8/F11/F12 için kısayol**: evdev'e zaten ulaşıyor, köprü gerekmez. COSMIC
   Ayarlar → Klavye Kısayolları'ndan elle bağlanır (Super+P ekran düzeni,
   Super+Shift+S ekran görüntüsü, Super+H serbest). Nix'ten yazılamaz.
3. **WEVN sözlüğü** (düşük öncelik): Fn kanalı olmadığı ölçüldü, geriye yalnız
   durum olayları kalıyor. Elde iki kayıt var (`0xEF` kapak). "WEVN = WMBC
   selector" hipotezinin doğrulaması fan/şarj/dGPU durum değişimlerini izlemeyi
   gerektirir.
4. **Sürücüde tuş üretimi** (şimdilik gereksiz): `aero_eg61h_evt`'ye
   `sparse_keymap` ancak WEVN sözlüğü çıkarsa anlamlı.
5. **WINK yazma testi** (WMBD 0xCB): tek yazım → Super tuşunu dene → **geri yaz**.
   CMOS'a dokunmuyor, `wmi-ec.md`'deki yasak listede değil. Yan etki testi:
   WINK=1 iken Super+P gönderen Fn+F8 de ölmeli. FESC/BTKY'nin WMI yazıcısı yok;
   denemesi `acpi_call` ile doğrudan alana yazmayı gerektirir.
