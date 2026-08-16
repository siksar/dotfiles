# AERO X16 1VH — EC/WMI Tam Kontrol Projesi

**Hedef:** Windows yeni SSD'ye kurulduğunda Gigabyte Control Center'dan (GCC)
referans verileri toplayıp, EC/BIOS'un sunduğu TÜM ayarları Linux'ta WMI
üzerinden deklaratif (NixOS modülü) olarak yönetmek. Özellikle: doğrulanmış
özel fan eğrileri.

**Durum (2026-07-05):** Canlı test TAMAMLANDI — özel fan kontrolü (eğri/fixed/
doğrudan duty) bu firmware'de (FB0A / EC 3.10) WMI'dan **tamamen kapalı**;
yalnız preset modlar (0/1/2) çalışıyor. Gerçek özel-fan kanalı muhtemelen ERCD
komut arayüzü → keşfi Windows/GCC yakalamasına kaldı (yeni SSD'ye kurulacak).
Ayrıntı: "Canlı test sonuçları" bölümü.

---

## Donanım / yazılım envanteri

| Bileşen | Değer |
|---|---|
| Model | GIGABYTE AERO X16 1VH (DMI product family: "GIGABYTE AERO", SKU: EG61VH) |
| BIOS | FB0A (American Megatrends, 2026-05-28, release 5.35) |
| EC firmware | 3.10 (DMI `ec_firmware_release`); çip büyük olasılıkla ITE IT55xx — Windows'ta HWiNFO ile kesinleşecek |
| EC erişimi | eSPI paylaşımlı bellek: PECM @ 0xFC7E0800 (+ ECM2/USEC); klasik port-EC neredeyse boş |
| EC sürücüsü | [tangalbert919/gigabyte-laptop-wmi](https://github.com/tangalbert919/gigabyte-laptop-wmi) → `aorus-laptop.ko` (`system/arch/aerox16/wmi.nix`) |
| WMI GUID'leri | ABBC0F6F / ABBC0F72 / ABBC0F75 (WMBC/WMBD metodları) |
| Dahili klavye | USB-HID 0414:8104 |
| sysfs | `/sys/devices/platform/aorus_laptop/` |

## Şu an Linux'ta çalışanlar

- `fan_mode`: 0=normal, 1=sessiz, 2=oyun, 3=custom(ölü), 4=auto-max, 5=turbo
  → `gigabyte-power-profile` AC'de **1**, pilde 1 (udev ACAD + resume tetikli)
  → SUPER+M döngüsü: 4→1→2→5 (`fan-mode-cycle.service`)
  → **Modların davranışı 16 Ağu 2026'da ÖLÇÜLDÜ** — aşağıdaki "Fan modu ölçümü"
    bölümü. AC varsayılanı o ölçümden sonra 4'ten 1'e alındı.

  **Düzeltme (15 Ağu 2026):** bu satır önceden "4/5(ölü)" diyordu — YANLIŞ. 5 zaten
  Turbo olarak döngüde aktif kullanımdaydı, 4 ise canlı sistemde `fan_mode`'dan
  okunarak doğrulandı (aşağıdaki WMBD tablosu da tutarlı: 4 → `0x70`
  SetFanAdjustStatus, 5 → `0x6A` SetFixedFanStatus — ikisi de dolu case). Eski not
  büyük olasılıkla `fan_mode 1` misdetect zincirinden (bkz. "Sessiz mod ÖLÜ"
  bölümü) genellenmişti. Ayrıca AC varsayılanı olarak yazan "2 (oyun)" da koddan
  kopmuştu (arada 0'a çekilmişti).
- dGPU Dynamic Boost: acpi_call `WMBD 0x4C` → AC'de ACBT=80W (+
  `nvidia-powerd` ile GPU tavanı 50→75W+), pilde 0. (`gpu_boost`/0x51
  KULLANILMIYOR: 2=no-op, 3=dGPU eject, 1=LCBT(0) — işlevsiz)
- `charge_mode`/`charge_limit`: custom(1) + %60 (boot'ta servisle)
- hwmon: 4× fan RPM (yalnız 1-2 gerçek) + 3× sıcaklık + **2× PWM/duty (CPU+GPU,
  salt-okuma; sürücü 0.2.0)** — `sensors`, btop, Caelestia dashboard
- Fn tuşu düzeltmesi: çıplak Fn = F20 (HID 0x7006f) → hwdb `reserved`
  (xkb F20'yi XF86AudioMicMute'a eşlediğinden mic toggle kaosu yaratıyordu)

## Fan modu ölçümü (16 Ağu 2026) — modlar ne YAPIYOR

Bugüne kadar bu dosya modların *isimlerini* listeliyordu; hiçbirinin eğrisi
ölçülmemişti. Ölçüldü.

**Yöntem.** 4 thread × Zen5 (cpu 0,2,4,6), 60 sn sabit yük, her mod için ayrı koşu.
Modlar arası Tctl ≤ 52°C'ye kadar soğutma. Mod değiştirme `fan-mode-cycle.service`
üzerinden. Örnekleme 2 Hz; "kararlı" değerler yükün 50-60. saniyesinin ortalaması.
Kaynaklar: k10temp Tctl, `amdgpu` PPT (APU paketi), `aorus_laptop` fan1/fan2.

| Mod | Boşta fan | Kararlı Tctl | PPT | MHz | Yükte fan | Fan kalkışı |
|---|---|---|---|---|---|---|
| 4 auto-max | **0 RPM** | 98.1 °C | 53.9 W | 4849 | 4388/4556 | 7.8 sn @ 90.0°C |
| 1 sessiz | **0 RPM** | **95.0 °C** | **45.3 W** | 4742 | 2354/2715 | 6.8 sn @ 94.9°C |
| 2 oyun | 2156/2313 | 99.4 °C | 53.3 W | 4840 | 4893/5186 | zaten dönüyor |
| 5 turbo | 6594/6764 | 97.0 °C | 55.1 W | 4860 | 6362/6455 | zaten dönüyor |

### Bulgu 1 — fan sürekli sıcaklığı düşürmüyor, performansa çeviriyor

Mod 4 → 5'te hava %45 artıyor (4388 → 6362 RPM); sıcaklık karşılığı yalnız
**1.1 °C**. Kazanılan soğutma güce (53.9 → 55.1 W) ve saate (4849 → 4860 MHz)
gidiyor, sıcaklığa değil. Boost algoritması **Tjmax'i hedefliyor**: ne kadar
soğutursan o kadar boost yapıp aynı sıcaklığa oturuyor.

**Sonuç: "sürekli yükte 99°C" fanla çözülebilir bir problem DEĞİL.** Bu,
`MAINTAINERS`'taki "100°C by-design" notunun ölçülmüş hâli. Fan modu seçerken
sorulacak soru "hangisi daha serin" değil, "hangi gürültü/performans noktası".

### Bulgu 2 — mod 1 bir fan eğrisi değil, 95°C'lik kapalı çevrim denetleyici

Mod 1'de Tctl 8. saniyeden itibaren **tam 95.0 °C**'de çakılı kalıyor ve hiç
oynamıyor. Hedefi tutmak için gücü ve saati kırpıyor:

```
 8.3s  95.0°C  51.1W  4840MHz
13.0s  95.0°C  50.0W  4803MHz
52.0s  95.0°C  45.0W  4742MHz
```

Bedeli %2.1 saat hızı; karşılığı 4.4 °C ve fanın yarı devri. AC varsayılanı bu
yüzden 1'e alındı (`system/arch/aerox16/wmi.nix`).

### Bulgu 3 — boşta fan: 4 ve 1 durduruyor, 2 ve 5 durdurmuyor

Mod 4 ve 1 boşta fanı **tamamen durduruyor** (0 RPM). Mod 2 boşta 2156 RPM'de
dönüyor — sessiz bir masaüstünde duyulur ve karşılığı yok.

### Düzeltilen iki yanlış iddia

- *"yalnız preset modlar (0/1/2) çalışıyor"* (yukarıdaki 2026-07-05 durum notu) —
  4 ve 5 de çalışıyor ve birbirinden belirgin farklılar. Doğru olan kısım: **özel**
  fan kontrolü (mod 3 / eğri / fixed duty) ölü.
- *"fan modları 2-4 etkisiz kalabiliyor"* (aşağıdaki mod↔selector notu) — dördü de
  etkili; sıcaklık, güç, saat ve RPM'de ölçülebilir biçimde ayrışıyorlar.

### Ölçümün sınırları

Her mod **tek koşu**; başlangıç sıcaklıkları 37–49.5 °C arasında değişti (50-60. sn
penceresi bunu büyük ölçüde yıkıyor ama tamamen değil). Yük **yalnız CPU** — dGPU
boştaydı. **Oyun için bu tablodan sonuç çıkarma**: oyun CPU+dGPU'yu birlikte zorlar
ve paylaşımlı ACBT bütçesi devreye girer; o kolu `game-perf` zaten turbo'ya (5) alıyor.

## Eksik / deneysel olanlar

- **Özel fan eğrisi**: 15 nokta (`fan_curve_index` + `fan_curve_data`,
  `data = speed*256 + temp`). Format doğru (DSDT XFNW + MOF SetFanIndexValue)
  ama CANLI TESTTE ÖLÜ ÇIKTI: EC firmware XFNW yazımını tabloya işlemiyor
  (bkz. "Canlı test sonuçları"). Windows/GCC yakalaması bekleniyor.
- `fan_custom_speed` (FLVL): o da canlı testte etkisiz çıktı.
- `usb_charge_s3/s4_toggle`, `light_sensor`, `power_on_time`, `battery_cycle`
  gibi attribute'lar keşfedildi ama haritalanmadı/kullanılmadı.

## Windows kurulunca toplanacaklar (GCC / AERO uygulaması)

1. **Custom fan modu eğri editörü** — 15 noktanın sıcaklık→% değerleri
   (ekran görüntüsü, değerler okunur olsun)
2. **Preset eğriler** (Normal/Quiet/Gaming görselleştiriliyorsa)
3. **GPU boost kademeleri** — adları ve varsa Watt/TGP değerleri
4. Bonus: GCC'nin kurulum dizinindeki config/XML dosyaları (eğri verileri
   çoğu zaman düz metin XML'de durur) ve `Get-WmiObject` ile WMI sınıf dökümü
5. Bonus: Windows'ta bir WMI izleme aracıyla (ör. WMIExplorer) fan ayarı
   değiştirirken çağrılan metod+parametrelerin gözlenmesi
6. **EC çipi kimliği**: HWiNFO64 → Motherboard/Embedded Controller
   bölümünde çip modeli (ITE IT55xx beklentisi); alternatif RWEverything
   ile EC izleme (p37-ec projelerinin metodu)
7. GCC "custom" eğri kaydederken RWEverything/WMIExplorer ile 0x68
   (SetFanIndexValue) çağrılarını yakala → bizim sysfs yazmalarımızla
   birebir karşılaştır

## DSDT analizi — TAMAMLANDI (2026-07-04; aynı gün GitHub bulgularıyla DÜZELTİLDİ)

DSDT döküldü ve WMBD/WMBC metodları çözüldü (dsl dökümü scratchpad'de
üretildi; WMBD ~satır 9101, WMBC ~9525). Ana bulgular:

### 1. Fan eğrisi 0x68 YAZILABİLİR — ilk analizdeki "salt okuma" sonucu YANLIŞTI
İlk okumada yazma hedefi XFNR sanılmıştı; gerçekte **WMBD 0x68 → `XFNW`
(24-bit, PECM offset 0x1D)** yazıyor (dsdt.dsl:9177, alan tanımı :8019).
Okuma yolu ayrı: WMBC 0x68 → `XFNR (8-bit, 0x5A)` index seç + `XFN1
(16-bit, 0x5B)` oku. 24-bit yazma formatı = `speed<<16 | temp<<8 | index` —
resmî MOF'taki `SetFanIndexValue(Index, Temperature, Speed)` üçlüsünün
little-endian paketlenmişi. Sürücünün `payload = data<<8 | index` yolu
(data = speed*256 + temp, USAGE.md formülü) bu formatı BİREBİR üretiyor →
**sürücünün mevcut `fan_curve_index`/`fan_curve_data` sysfs düğümleri bu
modelde çalışmalı** (custom mod: `fan_mode` 3 / TENF=1 gerekli; test onay
bekliyor).

### 2. Gerçek fan düğmeleri (sürücüde eşlenmemiş!)
| Selector | EC alanı | İşlev |
|---|---|---|
| 0x46 | FDTY+FAN1 | CPU fan duty doğrudan yazma (%) |
| 0x47 | GDTY+FAN2 | GPU fan duty doğrudan yazma (%) |
| 0x50 | FDTY | CPU fan duty (tek alan) |
| 0x7D | TFAN | hedef fan? (haritalanmadı) |
| 0x66 | FLVL | custom fan seviyesi (sürücüde fan_custom_speed) |
| 0x67 | TENF | custom mod aç/kapa |

### 3. dGPU güç limitleri (NVIDIA NPCF) — ince ayar mümkün!
| Selector | Etki | Aralık |
|---|---|---|
| 0x4A | `NPCF.AMAT = Arg2*8` + Notify | 15-25 → 120-200 (W?) |
| 0x4B | `PEGP.NLIM=1; LTGP=Arg2` + Notify | 75-87 (TGP W?) |
| 0x4C | `NPCF.ACBT = Arg2*8` | 0-10 → 0-80 (boost W?) |

`gpu_boost` (0x51) kaba kademe; bunlar watt-seviyesinde kontrol veriyor.

### 4. Diğer ilginç selector'ler
- **0xC9 → FNKS (1-bit, PECM 0x07.0)**: "Fn Key Setting" — çıplak Fn
  davranışını EC seviyesinde değiştirme adayı (hwdb fix'imize firmware
  alternatifi)
- 0xC4 LCDO (LCD overdrive), 0xD9 KBAT (klavye aydınlatma zamanlayıcı?),
  0x80 PL3E (güç limiti?), 0xF6 KBLL (kb backlight = MOF
  SetKeyBoardBackLight), 0x87/0x88/0xE7 (koşullu mantık — MUX/pil
  olabilir, çözülmedi)
- WMBC ek okunabilirler MOF ile çözüldü: 0x6F=GetFanPWMStatus,
  0xE3=getGpuTemp2, 0xEF=GetLid1Status (0xA2, 0xEB hâlâ bilinmiyor)
- 0x61=BHEA oku (battery health), 0x63=WXCM(0xD2-0xD6, Arg2 5-baytlık
  buffer), 0x64/0x65=BCPS/BCPC (şarj politikası/durdurma = MOF
  SetChargePolicy/SetChargeStop)

### Sonuç (2026-07-05 düzeltmesi)
DSDT analizi doğruydu (0x68 → XFNW yazılabilir REGISTER) ama canlı test
gösterdi ki EC firmware bu register'ı fan tablosuna İŞLEMİYOR — 0x46/0x47
doğrudan duty ve 0x70 dahil tüm override yolları da ölü ("Canlı test
sonuçları" bölümü). Windows/GCC verisi yeniden "kanal keşfi" için gerekli
hâle geldi: GCC büyük olasılıkla ERCD komut arayüzünü kullanıyor.

---

## İnternet/GitHub araştırması — TAMAMLANDI (2026-07-04)

### Resmî WMI MOF haritası bulundu (alfc reposu)
[s-h-a-d-o-w/alfc](https://github.com/s-h-a-d-o-w/alfc) (arşivli; Aorus
15G/Aero 15 fan aracı) `GB_WMIACPI_Get/Set` sınıflarının MOF dökümünü
içeriyor (`frontend/src/data/mofGet.ts` / `mofSet.ts`). WmiMethodId
(ondalık) → bizim selector (hex) birebir eşleşiyor ve DSDT'deki neredeyse
tüm bilinmeyenleri çözdü:

| Hex | MOF adı (Set) | Not |
|---|---|---|
| 0x46/0x47 | Get/SetCPU-GPUFanDuty | DSDT FDTY+FAN1 / GDTY+FAN2 ✔ |
| 0x51 | SetNvPowerConfig | sürücüdeki gpu_boost ✔ |
| 0x52-0x56 | SetNvD1..D5 | Nv güç kademeleri |
| 0x57 | SetNvThermalTarget | sürücü bunu "silent mode" olarak kullanıyor! |
| 0x60 | SetDeepFan (5 nokta eğri) | bizim DSDT'de YOK |
| 0x64/0x65 | SetChargePolicy/Stop | BCPS/BCPC ✔ |
| 0x66/0x67 | SetCurrentFanStep / SetStepFanStatus | FLVL / TENF ✔ |
| 0x68 | **SetFanIndexValue(Index,Temp,Speed)** | 15 nokta eğri yazma ✔ |
| 0x6A/0x6B | SetFixedFanStatus/Speed | ADJF / FAN1 ✔ |
| 0x70/0x71 | SetFanAdjustStatus / SetAutoFanStatus | sürücü 0x70="auto", 0x71="gaming" diyor — adlar MOF'la uyuşmuyor |
| 0x7D | SetFanSpeed | DSDT TFAN ✔ |
| 0xE1-0xE5 (Get) | getCpuTemp, getGpuTemp1/2, getRpm1/2 | hwmon kaynakları |

### EC erişim mimarisi
Fan/güç alanlarının tamamı klasik port-EC'de (0x62/0x66) DEĞİL,
**eSPI paylaşımlı bellek pencerelerinde**: `PECM` @ 0xFC7E0800 (ana alan
haritası: FAN1/FAN2 duty @0x1B-0x1C, XFNW @0x1D, RPM1/RPM2 @0x13-0x16,
FNKS @0x07.0, GFS2-GFSE tablosu @~0x4D), `ECM2` @ 0xFC7E0500, `USEC` @
0xFC7E0250. Klasik `ERAM` bölgesi neredeyse boş (yalnız 0x5F/0x60) →
**p37-ec / nbfc-linux tarzı port-EC register haritaları bu makinede
GEÇERSİZ** (onlar Intel dönemi 0xB0/0xB3 register'larını kullanır).

### İlgili projeler (referans)
- [tangalbert919/gigabyte-laptop-wmi](https://github.com/tangalbert919/gigabyte-laptop-wmi) —
  kullandığımız sürücü. Issue #15: custom eğri v0.1.0'dan beri destekli
  (USAGE.md formülü: `data = speed*256 + temp`). Issue #35 (Aero 16 XE5,
  o da "FB0A" BIOS): fan modları 2-4 etkisiz kalabiliyor — mod↔selector
  eşleşmesi model bağımlı, bizde de doğrulanmalı.
- [s-h-a-d-o-w/alfc](https://github.com/s-h-a-d-o-w/alfc) — MOF haritası +
  Linux'ta `acpi_call` ile doğrudan `WMBC/WMBD` çağırma deseni
  (`\_SB.PCI0.AMW0.WMBD 0 <id> <argümanlar little-endian tek integer>`).
- [rcassani/p37-ec-aorus15g](https://github.com/rcassani/p37-ec-aorus15g),
  [christiansteinert/p37-ec-aero-14](https://github.com/christiansteinert/p37-ec-aero-14),
  [mjguynn/a15kb](https://github.com/mjguynn/a15kb) — eski nesil port-EC
  yaklaşımı; register'ları bize uymaz ama metodoloji (Windows'ta
  RWEverything ile EC izleme) Windows aşamasında birebir kullanılabilir.
- [nbfc-linux](https://github.com/nbfc-linux/nbfc-linux) — "Gigabyte
  Aero16.json" konfigi port-EC tabanlı; bu modelde uygulanamaz.

### EC çipi kimliği — henüz KESİNLEŞMEDİ
Yerel kanıt yok: DMI yalnız `ec_firmware_release: 3.10` veriyor, ACPI
tablolarında üretici adı geçmiyor, teardown bulunamadı. Gigabyte
AERO/AORUS ailesi tarihsel olarak **ITE (IT5570E ailesi)** kullanır ve
eSPI paylaşımlı-bellek + GB_WMIACPI deseni bununla uyumlu → güçlü tahmin
ITE, ama doğrulama Windows'ta yapılacak (aşağıya eklendi).

## TAM WMI selector envanteri — Faz 0 (2026-07-04, DSDT dispatch birebir okundu)

WMBD (dsdt.dsl:9101) ve WMBC (dsdt.dsl:9525) switch'lerinin eksiksiz dökümü.
MOF adları alfc dökümünden (önceki araştırma); "—" = MOF'ta yok/bilinmiyor.

### WMBD (Set) — yazılabilirler

| Hex | Yaptığı (DSDT) | MOF adı | Sürücü sysfs | Not |
|---|---|---|---|---|
| 0x46 | FDTY+FAN1 = Arg2 | SetCPUFanDuty | — | CPU fan duty % doğrudan |
| 0x47 | GDTY+FAN2 = Arg2 | SetGPUFanDuty | — | GPU fan duty % doğrudan |
| 0x4A | NPCF.AMAT = Arg2×8 (15-25) | — | — | dGPU watt (120-200); Get YOK |
| 0x4B | PEGP.NLIM=1; LTGP=Arg2 (75-87) | — | — | dGPU TGP W; Get YOK |
| 0x4C | NPCF.ACBT = Arg2×8 (0-10) | — | — | dGPU dyn-boost W (0-80); Get YOK |
| 0x50 | FDTY = Arg2 | — | — | CPU duty (FAN1'siz varyant) |
| 0x51 | 0→ACBT=0; 1→ACBT=LCBT; **2→HİÇBİR ŞEY**; 3→dGPU Eject Request(!); 4→dGPU power-on | SetNvPowerConfig | gpu_boost | **BUG bizde: servis AC'de 2 yazıyor = no-op; pil 0'dan sonra boost'u kimse geri açmıyor. Doğrusu AC'de 1.** 3'ten UZAK DUR |
| 0x57 | GFAN=0; CRAF=Arg2 | SetNvThermalTarget | fan_mode 1 (silent) | CRAF 1-bit @0x2C.0 |
| 0x63 | WXCM 0xD2-0xD6 ← 5 bayt | — | — | CMOS NVRAM'a yazar (EC değil!) |
| 0x64 | BCPS = Arg2 | SetChargePolicy | charge_mode | |
| 0x65 | BCPC = Arg2 | SetChargeStop | charge_limit | |
| 0x66 | FLVL = Arg2 | SetCurrentFanStep | fan_custom_speed | FLVL @0x4B = eğri hız tablosunun 0. gözü |
| 0x67 | TENF = Arg2 | SetStepFanStatus | fan_mode 3 | custom eğri aç/kapa, 1-bit @0x2C.2 |
| 0x68 | XFNW = Arg2 (24-bit) | SetFanIndexValue | fan_curve_index+data | `speed<<16\|temp<<8\|index` |
| 0x6A | ADJF = Arg2 | SetFixedFanStatus | fan_mode 5 | 1-bit @0x2C.3 |
| 0x6B | FAN1 = Arg2 | SetFixedFanSpeed | — | |
| 0x70 | TFAN=0; GFAN=1; FAN1=FAN2=Arg2 | SetFanAdjustStatus | fan_mode 4 | sürücü "auto-max" diyor |
| 0x71 | GFAN=0; FANB=Arg2 | SetAutoFanStatus | fan_mode 2 | sürücü "gaming" diyor; FANB 1-bit @0x2C.1 |
| 0x7D | TFAN = Arg2 | SetFanSpeed | — | TFAN 1-BİT bayrak @0x0B.7 (hız değil!) |
| 0x80 | PL3E = Arg2 | — | — | 1-bit @0x0B.0 — PL3 enable bayrağı |
| 0x87 | WXCM(0xDA)+PLED (ters mantık) | — | — | power LED + CMOS kalıcılık |
| 0x88 | WXCM(0xD9)+BLED (ters mantık) | — | — | battery LED + CMOS kalıcılık |
| 0xA1 | stub (1 döner) | — | — | |
| 0xA3 | WXCM 0xD1 | — | — | CMOS |
| 0xC4 | LCDO = Arg2 | — | — | LCD overdrive, 1-bit @0x10.7 |
| 0xC7 | MUTE = Arg2 | — | — | @0x30.0 |
| 0xC9 | FNKS = Arg2 | — | — | Fn tuş ayarı, 1-bit @0x07.0 |
| 0xCA | PSON = Arg2 | — | — | @0x0B.5 |
| 0xCB | WINK = Arg2 (+DBG8=0xEA) | — | — | @0xA1.1 |
| 0xD9 | KBAT = Arg2 | — | — | @0x30.2 |
| 0xE6 | WXCM 0xD0 | — | — | CMOS |
| 0xE7 | 0→dGPU dyn-boost KAPAT (DBAC/DBDC=1, AMAT=0, PPAB=0); 1→AÇ (AMAT=LMAT, PPAB=1) | — | — | NPCF Notify 0xC0 |
| 0xED | **GCC performans profili 0-3** (aşağıda tablo); 4-5 boş | — | — | CPU+dGPU watt paketi tek çağrıda |
| 0xF1 | ECPT(0x30, Arg2÷1000) | — | — | **CPU güç limiti #1, mW cinsinden** (muhtemel SPL) |
| 0xF2 | ECPT(0x32, Arg2÷1000) | — | — | **CPU güç limiti #2** (muhtemel SPPT) |
| 0xF3 | ECPT(0x34, Arg2÷1000) | — | — | **CPU güç limiti #3** (muhtemel FPPT) |
| 0xF6 | KBLL = Arg2 | SetKeyBoardBackLight | — | @0x31 |
| 0xFA | boş case | — | — | |

### WMBC (Get) — okunabilirler

0x46/0x50→FDTY, 0x47→GDTY, 0x57→CRAF, 0x61→BHEA, 0x63→RXCM 0xD2-D6 (5B buffer),
0x64→BCPS, 0x65→BCPC, 0x67→TENF, **0x68→XFNR=Arg2; Sleep(100ms); XFN1 döner**
(eğri noktası geri-okuma; EC 100 ms gecikmeyle dolduruyor), 0x6A→ADJF,
0x6B/0x6F/0x70→FAN1, 0x71→FANB, 0x7D→TFAN, 0x80→PL3E, 0x87/0x88→PLED/BLED (ters),
0xA1→M029(4), 0xA2→(ACST==4 ? 1:0) (şarj tamamlandı?), 0xA3→RXCM 0xD1,
0xC4→LCDO, 0xC7→MUTE, 0xC9→**FNKS (okunabilir ✔ — Faz E geri dönüşü güvenli)**,
0xCA→PSON, 0xD9→KBAT, 0xE1→CTMP (CPU °C), 0xE2 **ve** 0xE3→SKTC (ikisi aynı alan;
MOF'un getGpuTemp2 adı yanıltıcı), 0xE4→RPM1, 0xE5→RPM2, 0xE6→RXCM(0xD0)&0x7F,
0xE7→NPCF.DBAC, 0xEB→stub 1, 0xEF→~LIDF, 0xF6→KBLL.
Özel: `Arg1==3` → Notify(AMW0, 0xD2) (SMGR olay kanalı).
**0x4A/0x4B/0x4C'nin Get karşılığı YOK** → dGPU watt testinde geri-okuma
nvidia-smi üzerinden yapılacak.

### GCC performans profilleri (WMBD 0xED, Arg2=0-3)

ECPT(ofs, W): EC ERCD komutu 0x45 ile 32-bit mW değeri yazar (0x30/0x32/0x34 →
muhtemel SPL/SPPT/FPPT). ECPL(): ERCD 0x45/0x4D → aktif profil seviyesini okur.

| Profil | CPU AC (0x30/0x32/0x34 W) | CPU DC (W) | dGPU ATPP | ACBT | AMAT |
|---|---|---|---|---|---|
| 0 | 20 / 65 / 65 | 15 / 30 / 30 | 160 | 0 | 120 |
| 1 | 25 / 65 / 80 | 19→20 / 54 / 54 | 200 | 80 | 120 |
| 2 | 19→30 / 80 / 80 | 19→20 / 54 / 54 | ECPL'e göre 240/200/160/120 | 160 | 120 |
| 3 | 25 / 80 / 80 | 19→20 / 54 / 54 | 200 | 160 | 120 |

("19→20" = DSDT aynı ofsete art arda iki yazım yapıyor — firmware tuhaflığı.)

### PECM tam alan haritası (@0xFC7E0800)

| Ofs | Alan(lar) |
|---|---|
| 0x00 | ACST (AC durumu; 4=şarj dolu?) |
| 0x01-0x02 | WEVS, WEVN (WMI olay) |
| 0x03 | GCMP(7)+GCMM(1) |
| 0x04 | ADAP |
| 0x05 | BCPC (şarj limiti) |
| 0x07 | bit0 FNKS, bit5 BLED, bit7 PLED |
| 0x08 | USBC |
| 0x0A | DNLV |
| 0x0B | bit0 PL3E, bit1 MAXC, bit2 WNON, bit3 P2ON, bit4 CDON, bit5 PSON, bit6 S3UC, bit7 TFAN |
| 0x0C | bit1 GFAN, bit4 CCDM, bit5 REBT |
| 0x0D | bit0 GC6F, bit1 Q27F |
| 0x0F | bit6 AWAK |
| 0x10 | bit0-3 BCPS, bit4 HDIN, bit5 PPAB, bit6 SCEN, bit7 LCDO |
| 0x12 | FLVT |
| 0x13-0x16 | RPM1, RPM2 (16'şar bit) |
| 0x17 | BHEA (pil sağlığı) |
| 0x18-0x1A | LUXM/LUXL/LUXH (ışık sensörü) |
| 0x1B-0x1C | FAN1, FAN2 (duty) |
| 0x1D-0x1F | XFNW (24-bit eğri yazma penceresi) |
| 0x20 | bit2 OSTE, bit4 PLTP, bit6 C1FM, bit7 G1FM |
| 0x21-0x22 | OSTM, OSTH (saat) |
| 0x23 | bit4 EDPW |
| 0x24-0x26 | PWMB, FDTY, GDTY |
| 0x29 | GPUT (GPU °C) |
| 0x2B | STML |
| 0x2C | bit0 CRAF, bit1 FANB, bit2 TENF, bit3 ADJF (fan modu bayrakları) |
| 0x2D | bit0 DSMD, bit1 QBMD, bit2 DDSS |
| 0x30 | bit0 MUTE, bit2 KBAT |
| 0x31 | KBLL (kb aydınlatma) |
| **0x3C-0x4A** | **GTS0-GTSE: eğrinin 15 SICAKLIK noktası** |
| **0x4B** | **FLVL (eğri hız tablosunun 0. gözü / current step)** |
| **0x4C-0x59** | **GFS1-GFSE: eğrinin 1-14. HIZ noktaları** |
| 0x5A | XFNR (okuma index'i) |
| 0x5B-0x5C | XFN1 (okuma verisi, 16-bit `speed<<8\|temp`) |
| 0x8C | TCLT |
| 0x90 | PPPT |
| 0x99-0xA0 | BATN |
| 0xA1 | bit0 FESC, bit1 WINK, bit2 BTKY |
| 0xF3, 0xF5 | CYC2, CYC1 (pil döngüsü) |

→ Eğri tablosu paylaşımlı bellekte ÇIPLAK duruyor (GTS/FLVL/GFS): XFNW/XFNR
sadece ön yüz. Teşhis gerekirse `/dev/mem` veya acpi_call ile doğrudan
gözlemlenebilir (normalde gerek yok).

### "CPU boost / PBO EC'de var mı?" — CEVAP

- **Çarpan/voltaj/PBO/Curve Optimizer: YOK.** Bunlar SMU işi (ryzen_smu /
  amd-pstate / ACPI platform_profile), EC-WMI arayüzünde karşılığı yok.
- **CPU güç limitleri: VAR, watt hassasiyetinde.** 0xF1/0xF2/0xF3 (mW argüman,
  muhtemel SPL/SPPT/FPPT eşlemesi) + 0xED hazır profilleri (üstteki tablo).
  Doğrulama yöntemi (ileride, deneme onayıyla): 0xF1-F3 yaz → RAPL/ryzen_smu
  ile limitlerin değiştiğini gözle.
- dGPU tarafı: 0x4A/0x4B/0x4C watt + 0xE7 dyn-boost aç/kapa + 0xED paketi.

## Canlı test sonuçları — Faz A (2026-07-05, acpi_call dahil)

Tüm WMI fan-override yolları canlı denendi; **hiçbiri fiziksel PWM'i
değiştirmiyor**. EC firmware fanları yalnız kendi iç mantığından sürüyor.

| Yol | Deney | Sonuç |
|---|---|---|
| 0x68 eğri (XFNW) | 15 nokta yazıldı (sürücü sysfs; hata yok), TENF=1 iken de tekrarlandı | ❌ WMBC 0x68 geri-okuma hep 0 — EC tabloya İŞLEMİYOR; %100 bump'a RPM tepkisi yok |
| 0x67 TENF | mod 3; debug_method ile doğrulandı | Bit 1 oluyor ama davranış değişmiyor |
| 0x66 FLVL + 0x6A ADJF (mod 5) | %60 verildi | ❌ RPM tepkisiz |
| 0x70 FAN1/FAN2+GFAN (mod 4) | arg 60 | Register 60 tutuyor (WMBC 0x70=60) ama FDTY/GDTY %16'da kaldı ❌ |
| 0x46 doğrudan FDTY (acpi_call WMBD) | arg 50 @ ~70°C yük | Register ~20 sn 50 tuttu, EC 20'ye geri ezdi; RPM sabit ❌ |
| 0x7D TFAN=1 + 0x46 | bayrak+duty | Bayrak yazıldı, etkisiz ❌ |
| **Preset modlar** | yük altında 0→1→2→0 | ✅ Mod 2 (0x71): 4 sn'de 2170→2730/3030 RPM; mod 1≈mod 0 (71°C'de) |

Ek bulgular:
- **hwmon RPM byte-swap bug'ı (sürücü):** fanN_input ham 39435 (0x9A0B) →
  gerçek 0x0B9A=2970 RPM. Doğru okuma: `((v&0xFF)<<8)|(v>>8)`. fan3/4 hep 0
  (donanımda yalnız RPM1/RPM2 tach var).
- **debug_method = serbest WMBC okuma kapısı:** `echo <id> > debug_method;
  cat debug_method` → "id, değer". Arg2 hep 0 (0x68'de yalnız slot 0 okunur).
- **CRAF (0x57) 1'e yapışıyor:** sürücünün 0x57=0 yazması EC'de 1 kalıyor —
  EC'nin kendi durum göstergesi olabilir; fan davranışını etkilemiyor gibi.
- FDTY/GDTY EC tarafından ~20 sn periyotla (veya durum değişince) yenilenen
  telemetri; PWM komut register'ı DEĞİL.
- Stok eğri gözlemi (mod 0): ~45-48°C altı 0 RPM; 51-53°C ≈ 2100;
  57-60°C ≈ 2700-3300; 70°C oyun yükü ≈ 2100-2360 (iniş histerezisli).
- **Sonuç/hipotez:** GCC'nin özel eğrisi ERCD komut kanalından geçiyor
  olmalı (ECPT'nin fan karşılığı; komut uzayı bilinmiyor — körlemesine
  denemek riskli). Windows'ta RWEverything/WMIExplorer yakalaması şart.
- Test için eklenen **acpi_call GEÇİCİ** (gigabyte-wmi.nix'te işaretli) —
  Faz D/E bitince kaldırılıp kaldırılmayacağı sorulacak.

## Preset mod eğrileri — ölçülmüş karakterizasyon (2026-07-05)

Kullanıcı gözlemi ("oyunda mod değişince davranış değişiyor") doğrulandı;
soğuma taraması + sabit yük noktalarıyla üç modun gerçek eğrisi çıkarıldı
(değerler FDTY/GDTY duty% — EC'nin kendi PWM çıkışları; RPM ≈ duty×~110):

| CPU °C | Mod 0 normal | Mod 1 sessiz | Mod 2 oyun |
|---|---|---|---|
| <48 | 0/0 (fan-stop) | 0/0 (fan-stop) | 0/0 |
| 48-49 | 16/15 | 16/16 | 0/0 (**fan-stop ≤53-54'e kadar!**) |
| 50-59 | 19-20/20 | **16/16** (58°C'de 18/17) | 54-55°C: 16/16 |
| ~83 | 21/23 | 21/23 | **28/32** |
| 95 (tavan) | 21-24/23-27 | 21-23/23-27 | **32-33/35** |

Okumalar:
- **Sessiz vs normal fark yalnız ~50-60°C bandında** (%16 vs %19-20 ≈
  1880/1900 vs 2160-2330 RPM — duyulur); ≥~80°C'de birleşiyorlar.
  Pilde mod 1 tercihi doğruymuş.
- **Oyun modu iki uçta da farklı:** ≤53°C fan-stop (normalden GEÇ susmuyor,
  erken susuyor → hafif kullanımda EN sessiz mod!) ve ≥~70°C'de +7-12 puan
  agresif. 55-65°C bandında da normalden sessiz/eşit. AC profili için güçlü
  aday.
- **Hiçbir mod %35 duty üstüne çıkmıyor**; EC her modda CPU'yu 95°C SMU
  tavanında bırakıyor (2 çekirdek yük bile tavana dayanıyor). Fanların
  gerçek kapasitesi (%100 duty) hiç kullanılmıyor — GCC'nin custom
  eğrisinin değeri de burada olacak.
- EC duty geçişleri yavaş/histerezisli (~30-60 sn oturma; skin sensörü
  SKTC etkili olabilir — SKTC okuması ara ara 0 dönüyor, güvenilmez).

### Mod geçişi NASIL çalışıyor? (mekanizma, 2026-07-05)

WMI mod selector'leri fan değeri yazmıyor; PECM 0x2C'deki İSTEK bitlerini
çeviriyor. Ölçülen doğruluk tablosu (WMBC geri-okuma):

| Mod | CRAF(0x57) | TENF(0x67) | ADJF(0x6A) | FANB(0x71) |
|---|---|---|---|---|
| 0/1 | 1* | 0 | 0 | 0 |
| 2 | 1* | 0 | 0 | **1** |
| 3 | 1* | **1** | 0 | 0 |
| 5 | 1* | **1** | **1** | 0 |

- EC firmware bitleri poll edip KENDİ ROM tablolarından birini seçiyor:
  FANB→oyun tablosu, (0x57 yazma olayı)→sessiz tablosu, hiçbiri→normal.
- TENF/ADJF bitleri yazılıyor ve kalıcı ama bu firmware build'inde tüketici
  kodu yok → custom/fixed ölü. Değer taşıyan register'lar (XFNW, FLVL,
  FAN1/2, FDTY/GDTY) da aynı sebeple etkisiz.
- (*) CRAF her modda 1: EC'nin sahiplendiği durum biti; host'un 0 yazması
  kalıcı olmuyor. Sessiz↔normal farkı ölçüldüğüne göre 0x57 yazımı
  kenar-tetikli komut gibi işleniyor (bit seviyesi değil).

## Faz D+E sonuçları — dGPU güç zinciri ÇÖZÜLDÜ + FNKS sürprizi (2026-07-05)

### dGPU: +25W Dynamic Boost kilidi açıldı 🎯
- Taban: RTX 5060 tavanı **50 W'ta sıkışık** (Min 5 / Max 85); `nvidia-powerd`
  yok; NPCF.ACBT (boost bütçesi) = **0** çünkü GCC'nin boot init'i (0xED)
  Linux'ta hiç koşmuyor.
- **Çalışan zincir:** `WMBD 0x4C 10` → NPCF.ACBT=0x50 (80 W) → `nvidia-powerd`
  başlat → **Current Power Limit 50 → 75 W** (dinamik, yükle 85'e kadar).
  Kalıcılaştırma: acpi_call + boot/AC-geçiş yazması + `hardware.nvidia.
  dynamicBoost.enable`.
- **BIOS yazım hatası keşfi:** `PEGP.GPS` metodu `\_SB.PC00.AMW0.LTGP` arıyor
  (doğrusu PCI0!) → GPS/_DSM her dGPU uyanışında AE_NOT_FOUND ile çöküyor
  (dmesg'de NVRM PSHAREPARAMS hatası). Bu yüzden: **0x4B (TGP) tamamen ölü**,
  0x4A (AMAT) yazılsa da GPS üzerinden tüketilemiyor. NVPCF yolu (ACBT/DBAC)
  sağlam — powerd o yoldan çalışıyor. Olası ileri proje: initrd DSDT override
  ile PC00→PCI0 düzeltmesi (GPS onarımı; NVRM log kirliliği de biter).
- `gpu_boost` (0x51) gerçeği: arg1 = `ACBT=LCBT` ama Linux'ta LCBT=0 →
  gpu_boost 1 de İŞE YARAMAZ; servisteki AC=2 zaten no-op. Doğru araç 0x4C.
- NPCF durumu (acpi_call ile okunabilir): ATPP=0x168(360), AMAT=0x78(120),
  DBAC/DBDC=0. 0x4A-0x4C'nin Get'i yok; `\_SB.NPCF.<alan>` doğrudan okunuyor.

### FNKS (0xC9): "Fn ayarı" değil — DAHİLİ KLAVYE ANA ŞALTERİ
FNKS=0 → dahili klavye USB'de kalıyor ama TÜM raporlar kesiliyor ('a' dahil;
hidraw ham yakalama ile kanıtlı). FNKS=1 → anında geri. Çıplak Fn/F20
davranışını DEĞİŞTİRMİYOR (hwdb fix'i yerinde kalıyor). Kullanım fikri:
harici klavye modu / temizlik kilidi. WMBC 0xC9'dan okunabilir, kalıcı test
edilmedi (muhtemelen reboot'ta 1'e döner).

### Yan gözlem
Çıplak Fn basımında hidraw2'de consumer-page olayları da görüldü (mute/vol
kodları) — Fn'in ikincil rapor kanalı olabilir, derinleşilmedi.

## Uygulama planı

TAMAMLANDI (2026-07-05): eğri testi (ölü), preset karakterizasyonu, mod
mekanizması, Faz D (dGPU boost zinciri çözüldü + KALICI yapıldı: AC'de
fan_mode 2 + ACBT 80W + nvidia-powerd), Faz E (FNKS=klavye ana şalteri),
upstream taslağı (`Documentation/upstream/gigabyte-wmi-report.md`), acpi_call kalıcı.

### Gelecek işler (kullanıcı onaylı, ayrı oturumlar)
1. ~~**DSDT override projesi**~~ → **YAPILDI (2026-07-12)**: SSDT9 binary
   patch + initrd table upgrade (iasl recompile'a hiç gerek kalmadı — riski
   sıfırlandı). Bkz. "SSDT9 PC00→PCI0 düzeltmesi" bölümü (dosya sonu).
2. **FNKS klavye kilidi aracı**: dahili klavyeyi kapat/aç komutu
   (WMBD 0xC9 0/1) — harici klavye modu / temizlik kilidi.
3. **0xF1-F3 CPU watt deneyleri**: SPL/SPPT/FPPT'yi EC'den ayarla (mW
   hassasiyet), RAPL/ryzen_smu ile doğrula; sessiz/serin profillere malzeme.
4. **Fn+F9 touchpad toggle**: Windows'ta çalışıyordu, Linux'ta işlevsiz —
   tuş olayını yakala (hidraw2 consumer kanalı şüpheli) ve Hyprland'de
   touchpad enable/disable'a bağla.
5. Windows kurulunca: GCC'nin fan kanalını yakala (RWEverything/WMIExplorer,
   ERCD komutlarına odaklan); preset eğri ve 0xED/0xF1-F3 kullanım
   değerlerini referans al; EC çipini HWiNFO ile kesinleştir.
6. Upstream issue'yu gönder (taslak hazır).

## Deneysel 0xED / 0xF1–F3 logu (oyun projesi Faz E — iskelet, 2026-07-05)

Protokol: `Documentation/gaming.md` "Faz E" bölümü. Kural: tek yazım → ölç → logla →
revert. Ortam: AC + fan_mode 2 + sabit yük. Geri-okuma: 0xED → NPCF alanları
(ACBT/AMAT); 0xF1–F3 → RAPL davranışı (Get yok).
**YASAK:** 0x51 (3=dGPU eject) · CMOS'a yazan 0x63/0x87/0x88/0xA3/0xE6
(reboot ile sıfırlanmaz).
Taban (2026-07-06, stress-ng 16T, AC): RAPL sustained **21W** (SPL≈20 — GCC
init'i yok, profil 0 varsayılanı doğrulandı) · fan duty 18/17 @64°C · ACBT 80W
(bizim servis) → dGPU boşta tavan 60W · fan mod 2 · platform_profile=performance
(TLP; PMF kaydırıcısı zaten maksimumda — SPL'yi o yükseltmiyor).

| Tarih | Seçici | Yazılan | NPCF/ACBT yan etki | RAPL Δ | GPU Δ | Frametime | Hüküm | Revert |
|---|---|---|---|---|---|---|---|---|
| 07-06 | 0xED | 1 | görünür değişim yok (ACBT zaten 80) | 21→22W (gürültü) | tavan 60W sabit | — | nötr; bizim manuel kurulum ≈ profil 1 | üzerine 0xED 2 |
| 07-06 | 0xED | 2 | **ACBT 80→160** (boşta tavan 60→70W) | 22W (SPL DEĞİŞMEDİ — ECPT→SMU köprüsü yok?) | **KCD: 38W → 62-83W sustained** (86-87°C'de ~70W ort); **fan duty 32-35% → 46/49%** (4400/4700 RPM) — profil fan eğrisini de yükseltiyor! | GPU clock 2200-2600 sabit, util %100 | **BÜYÜK KAZANÇ — Windows farkının kaynağı buydu** | KALICI: game-perf.service start=profil 2 (AC'de) / stop=profil 0 + ACBT restore (2026-07-06) |
| — | 0xED | 3 | | | | | | reboot |
| — | 0xF1 (SPL) | 25000 | | | | | | reboot |
| — | 0xF2 (SPPT) | 65000 | | | | | | reboot |
| — | 0xF3 (FPPT) | 80000 | | | | | | reboot |

## Faz F — sürücü bulgu doğrulama + upstream rapor kesinleşti (2026-07-11)

Pinlenen sürücü kaynağı (`912b4e9`, `aorus-laptop.c`) satır satır okundu + Part 1
salt-okuma ölçümü yapıldı (`Documentation/aerox16/test-plan.md`). İki iddia netleşti — ikisi de
eski taslaktakinden FARKLI çıktı:

### 1. RPM "byte-swap bug"ı — sebep TERS: sürücü fazladan swap'lıyor
Ham WMBC `0xE4 -> 2970` (0x0B9A), `0xE5 -> 3333` (0x0D05) = **zaten doğru sıra**. Ama
hwmon `fan1_input=39435` (0x9A0B = swab16(2970)), `fan2_input=1293` (0x050D = swab16(3333)).
Yani EC değeri doğru veriyor, sürücünün `convert_fan_rpm` (`rol16 8`, `aorus-laptop.c:178-182`)
çağrısı BOZUYOR. Bu çağrı `"GIGABYTE GAMING"` dışındaki tüm ailelere uygulanıyor
(`:249-252`); bizim aile `"GIGABYTE AERO"` → yanlışlıkla swap yiyor. **Düzeltme: swap
EKLEMEK değil, bu nesil (AMD/eSPI) için KALDIRMAK** — `GIGABYTE AERO`'yu no-swap dalına
al. (Önceki notun "doğru okuma swab" ifadesi gözlem olarak doğruydu ama sebebi yanlış
atfediyordu.)

### 2. Sessiz mod (`fan_mode 1`) sürücüde ÖLÜ — misdetect zinciri kanıtlandı
dmesg: **"Older model detected, using old ID"**. Mekanizma (uninitialized DEĞİL,
deterministik): probe `get_devstate(0xFA)` çağırıyor; X16 WMBC'de `Case(0xFA)` yok →
**0 döndürüyor** (ölçüldü: `0xFA->0`, `0xFC->0`, karşı-örnek `0x57->1`). Sürücünün
`if (output < 0)` kontrolü (`:779-790`) 0'ı "eski cihaz" sanıyor → `fan_modes[1]=0xFA`.
Sonra `echo 1 > fan_mode` = WMBD boş `Case(0xFA){}` (`dsdt.dsl:9105`) = **hiçbir şey**.
Doğru selector `0x57` (okunuyor, →1). Düzeltme önerisi: `GIGABYTE AERO` ailesi için
`fan_silent_method = FAN_SILENT_MODE (0x57)` zorla, ya da probe yalnız kesin-negatif
dönüşü "eski" saysın. (Not: bu, defterin preset karakterizasyonundaki "sessiz≠normal"
farkının sürücü üzerinden GELMEDİĞİNİ doğruluyor — o fark ancak ham `0x57` veya histerezis
kaynaklıydı; sürücünün `fan_mode 1`'i no-op.)

### 3. Yan doğrulamalar
- `fan3/fan4_input=0` (yalnız 2 tach), `temp3_input=0` (`ec_read(0x62)` port-EC bu eSPI'de
  boş, `:234`). Sıcaklıklar (`temp1=95`, `temp2=67`) swap edilmiyor, doğru.
- "Dual fan speed control required" hiç basılmadı → `ec_read(0xB0/0xB1)` (`:846-852`) boş.
  (**0.2.0'da değişti**: yoklama `ec_read` yerine `CPU_FAN_DUTY 0x46`/`FDTY` okumasına
  döndü ve artık BASILIYOR — ama FDTY fan dururken 0 olduğu için bayrak modül yüklenme
  anına bağlı. Bkz. "Sürücü 0.2.0'a yükseltme".)

### Çıktılar
- Upstream rapor **kesinleştirildi**: `Documentation/upstream/gigabyte-wmi-report.md` (issue #22
  yorumu; §1 ters-swap, §2 silent misdetect, §3 custom-fan ölü, §4 gpu_boost=3 eject).
- Manuel test planı: `Documentation/aerox16/test-plan.md` (Part 1 salt-okuma = yukarıdaki
  ölçüm; Part 2 korumalı yazma testleri, gpu_boost 3 yasak kutusu dahil).

### Uygulanan local fix — sessiz mod misdetect'i (2026-07-11)
> **Güncelleme (2026-07-29):** bu `.patch` dosyası sürücü 0.2.0'a yükseltilirken
> düştü; aynı düzeltme artık `gigabyte-wmi.nix` içinde `postPatch` +
> `substituteInPlace --replace-fail` olarak duruyor. Gerekçe aşağıdaki
> "Sürücü 0.2.0'a yükseltme" bölümünde.

Seçenek B (heuristik düzeltmesi, feature-detect) local patch olarak uygulandı:
`aorus-laptop-silent-0x57.patch` (repoda tutulmuyor) — probe artık `0xFA` yerine yeni
sessiz selector `0x57`'yi doğrudan yokluyor (`ret==0` ise yeni model). Wire:
`gigabyte-wmi.nix` içine `patches = [ ... ]`. `nixos-rebuild build` + `switch` yapıldı
(exit 0); yamalı modül `current-system`'de (srcversion `BE0D63F8…` → `1B107436…`).
**Reboot BEKLİYOR** — canlı çekirdekte hâlâ eski modül.
- Post-reboot doğrulama: `dmesg | grep "model detected"` → **"Newer model detected"**
  olmalı; `fan_mode 1` artık WMBD `0x57`'ye gider (boş `0xFA` değil).
- Uyarı: fix ID'yi düzeltir; `0x57`'nin bu firmware'de duyulur sessizlik yaratıp
  yaratmadığı hâlâ doğrulanmadı (thermal test null, AC + yük gerekli). Riski yok
  (donanıma yazma yok; `0x57` iyi huylu, `fan_mode 0` ile geri alınır).

## Fixed mod DÜZELTMESİ — DADA30000 haklı çıktı (2026-07-11, E1-E6 matrisi)

Issue #22'de başka bir X16 1VH sahibi (DADA30000) §3'e itiraz etti ("mod 5 = max,
custom speed etkisiz"). Temiz-durum deney matrisiyle yeniden ölçüldü (idle 34-45°C,
fanlar 0 RPM, pil; yamalı modül canlı — srcversion 1B10..., "Newer model detected"):

| Deney | Sonuç |
|---|---|
| E1: cs=50 ÖNCE yaz → mod 5 | Duty 0→**100** → ~6900 RPM (max). FAN1 değeri OKUNMUYOR |
| E7: TAM TARAMA cs=10..100 (onar, her değerde temiz 0→5 girişi) | HEPSİ aynı: ~6500-6900 RPM, FDTY 84-86. Değer↔RPM korelasyonu SIFIR |
| E8: E7 tekrarı, her değerde 20 sn / 2 sn'de 1 örnek (10 örnek × 10 değer) | Desen HER cs için birebir aynı: t=2s'de ~5900, t=4-6s'de tepe ~6900-7300 (ilk hızlanma sıçraması), t=20s'ye kadar ~6250-6520'ye oturuyor. cs=10 ile cs=100 arasında fark YOK — sayı değil, "mod 5'e giriş" tetikliyor. Tam log: `/tmp/.../scratchpad/fanlog/sweep2.txt` |
| E2: mod 5 içinde cs=25 | Max devam (mod içi değişim de etkisiz) |
| E3: mod 5 → 0 çıkışı | Fanlar 0, bitler temiz (çıkış sağlam) |
| E4: TEMİZ mod 3 | Hiçbir şey — TENF tek başına etkisiz (eğri zaten ölü) |
| E5: 3→5 geçişi | ADJF=1 → max ✔ |
| E6: TEMİZ mod 4 (cs=50) | **Fanlar 0!** (max değil, kapatıyor — yük altında TEHLİKELİ) |

Çıkarımlar:
- **Rapor §3'ün "tracks the value" iddiası GERİ ÇEKİLDİ.** Yanıltan mekanizma:
  FDTY/GDTY telemetrisi yavaş süzülen bir değer — max rampası sonrası ~20 sn'de
  100→94→88→87 iniyor; §3'teki 229 (→6800) ve 90 (→6400) okumaları bu inişin farklı
  anlarına denk gelip "değeri izliyor" yanılsaması yaratmış.
- Kullanıcının "3/4/5 hepsi max" gözleminin sebebi sürücünün KİRLİ GEÇİŞLERİ:
  mod 5'teyken `echo 3` → `"Custom mode is already enabled"` erken dönüşü
  (aorus-laptop.c:357): sysfs 3 gösterir ama ADJF=1 kalır → "mod 3" max üfler;
  3→4 geçişi de ADJF'yi temizlemez → "mod 4" max. Custom-ailesi modlar arasında
  daima 0 (veya 1/2) üzerinden geçilmeli.
- Net tablo (FB0A / EC 3.10): çalışan WMI fan kontrolleri = presetler (0x71 kesin
  duyulur, 0x57 nominal) + "mod 5 = max üfleme" (değersiz). Watt/duty/eğri bazlı
  kontrol tamamen ERCD arkasında → Windows/GCC yakalaması tek yol (değişmedi).
- Konfig etkisi: Süper+M döngüsündeki "Turbo" (mod 5) etiketi fiilen DOĞRU (max
  demek); cs yazmak anlamsız. **Mod 4 hiçbir otomasyonda kullanılmamalı** (fan
  kapatma davranışı). Döngü 5→0 çıkışı temiz (E3).
## EC iç RAM araştırması — ERCD komut kanalı KAPALI ÇIKTI (2026-07-11)

Kullanıcı sorusu: "neden custom fan speed ayarlanamıyor / neden turboya
kilitleniyor". Kök neden araştırması: WMI'nin yazdığı her şey (ADJF, FAN1,
XFNW, FLVL) yalnızca **eSPI paylaşımlı bellek AYNASI** (PECM @ 0xFC7E0800).
EC'nin gerçek fan karar döngüsü bu aynayı okumuyor (E1-E8'de zaten kanıtlı).
Daha derin bir yol var mı diye DSDT'de EC'nin **iç RAM'ine** erişen ayrı bir
komut kanalı bulundu: `ERCD` mailbox metodu (`\_SB.PCI0.SBRG.EC0.ERCD`,
dsdt.dsl:8485) — `ERRD(addr)` (opcode 0xB0, salt-okuma) ve `ERWT(addr,val)`
(opcode 0xB1, yazma) sarmalayıcılarıyla. Bu, WMI'nin hiç dokunmadığı,
donanıma daha yakın bir katman.

### Referans harita denendi — TUTMADI
nbfc `Gigabyte Aero16.json` + a15kb (Aorus 15, ITE EC) ikisi de aynı ITE iç
RAM reçetesini veriyor: `0x0D.7`=custom-on, `0x06.4`=fixed-submode,
`0x08.6`=eco-kapat, `0xB0`/`0xB1`=fan1/fan2 duty (0-229). Bu adresler bizim
makinede **sıcaklık aynası** çıktı: `0xB0/0xB1/0xB4` idle/oyun/turbo'da
51→51→48-49 okundu — yani turbo fanların soğutma etkisiyle DÜŞÜYOR, duty
değil. 2019-nesli Intel-EC haritası bu 2025 AMD/eSPI çipe taşınmıyor
(genel port-EC uyarısı zaten dokümandaydı; şimdi ERCD kanalı için de geçerli
olduğu kanıtlandı).

### Tam 256 bayt diff (idle/oyun/turbo) — 7 değişen bayt, hiçbiri "duty kontrolü" değil
`0x00-0xFF` tam dökümü üç durumda alınıp karşılıklı diff'lendi. Değişen
tek adresler: `0x13,0x14,0x15,0x16,0x25,0x26,0x2C`. `0x25`/`0x26` zaten
bildiğimiz FDTY/GDTY duty-yüzdesiyle (21→84, 24→85) neredeyse birebir
örtüşüyor → bunlar **EC'nin kendi hesapladığı çıktının bir başka aynası**,
host'un yazacağı bir girdi değil.

### İzole yazma testleri — SONUÇ TUTARSIZ (kontrol edilebilir DEĞİL)
`0x2C`/`0x14`/`0x16` hedef alındı (en "durum bayrağı"ymış gibi duran adaylar):
- **1. deneme (bileşik, art arda):** `0x2C=0x0C` yazımı idle RPM'i (2380/2654)
  anında turbo'ya (6500-7300) fırlattı, **10+ sn boyunca kendiliğinden
  düzelmedi** (FDTY'nin ~20 sn'de kendini toparlamasından farklı davranış).
  `fan_mode` sysfs yazması (0→1) da baytları sıfırlamadı; RPM ancak mod 1
  (sessiz)'in kendi override'ıyla susturuldu. Baytı elle `0x00`'a geri
  yazmak + mod 0 → **temiz 18 sn idle** ile tam kurtarma doğrulandı.
- **2. deneme (temiz, tek-değişkenli, minimal değer):** AYNI üç bayta
  ayrı ayrı `değer=1` yazmak **turbo TETİKLEMEDİ** (0x2C=1 hatta RPM'i
  düşürdü; 0x14/0x16=1 ihmal edilebilir etki). Temizlik sonrası `0x16`
  benim yazdığım 0'da KALMADI, kendiliğinden 7'ye kaydı — **EC bu baytın
  üstüne kendi döngüsünde hâlâ yazıyor**.

**Yorum:** Bu baytlar host'un dial edeceği bir "duty ayarla" register'ı
DEĞİL — EC'nin kendi hesapladığı telemetri/durum bayrakları. Üstüne yazmak
bazen etkisiz, bazen (muhtemelen EC'nin kendi güncelleme döngüsüyle yazma
anının çakışmasından) geçici ve öngörülemez bir "maksimum soğutmaya kaç"
tepkisi tetikliyor — güvenlik açısından İYİ huylu yön (EC şüpheli durumda
AZ değil ÇOK soğutmayı seçiyor, termal risk yaratmıyor) ama **kontrol
kanalı olarak KULLANILAMAZ** (deterministik değil).

### Sonuç — ERCD/iç RAM yolu KAPALI, Faz 3 (entegrasyon) İPTAL
Generic peek/poke komutu (opcode 0xB0/0xB1) GCC'nin kullandığı gerçek fan
setpoint arayüzü DEĞİL. DSDT'de tek "semantik, adrese değil anlama göre
yazan" komut CPU güç limitleri içindi (0x45/ECPT, bkz. 0xF1-F3). Fan için
böyle özel bir opcode DSDT'de görünmüyor — GCC muhtemelen ya farklı/
keşfedilmemiş bir ERCD opcode'u ya da ERCD'nin tamamen dışında bir yol
(SMBus'a bağlı ayrı bir fan kontrolcüsü çipi, ESMC/SBAT ailesi — kapsam
dışı bırakıldı) kullanıyor. **NixOS'a fan-set aracı EKLENMEDİ** — bu kanal
güvenilmez/riskli. Gerçek yol hâlâ yalnız Windows/GCC trafik yakalaması.

Test sırasında sistem her an güvendeydi (sıcaklık 44-48°C bandında,
termal risk sıfır); tek yan etki geçici gereksiz fan gürültüsüydü, mod 1
(sessiz)'e geçişle anında ve güvenilir şekilde susturuldu.

## Tam ACPI taraması — "BIOS'a özel mesajlar" hipotezi test edildi (2026-07-11)

Kullanıcı itirazı: turbo kilidi/duty'nin yok sayılması EC'nin BIOS'a özel
mesajlar yolladığı bambaşka bir yoldan olabilir, bunlar da araştırılmalı.
Haklı bir itiraz — önceki tur yalnız DSDT'ye bakmıştı; **33 SSDT hiç
incelenmemişti**. Hepsi çıkarılıp (`iasl`/`acpixtract`, salt-okuma)
decompile edildi ve fan/thermal/GPU-power açısından tarandı.

### Bulgular
1. **`ThermalZone TZ01` var (SSDT22, "THERMAL0")** ama yalnız **pasif**
   soğutma tanımlı (`_PSL` → 24 CPU çekirdeği throttle listesi). `_AC0`-
   `_AC9` (aktif/fan soğutma) YOK. Windows'un native ACPI thermal
   driver'ı bile bu laptopta fanı kontrol etmiyor — bu hipotez de elendi.
2. **`ERCD` mailbox gerçekten çok-amaçlı bir dispatcher** — SSDT4
   (USB-C/UCSI tablosu) aynı kanalı **opcode 0x59** ile kullanıyor
   (bildiğimiz 0xB0 RAM-oku/0xB1 RAM-yaz/0x45 CPU-watt'a ek üçüncü
   opcode). Ama fan'a özel bir opcode hiçbir ACPI/SSDT kodunda
   çağrılmıyor — varsa yalnız Windows sürücüsü doğrudan bilir.
3. **NVIDIA'nın İKİ resmi arayüzü de tam okundu:**
   - Eski `PEGP.GPS` (`\_SB.PCI0.GPP9.PEGP.GPS`, SSDT9): `GPSP` buffer'ında
     `SFAN` (offset 0x10, muhtemelen "fan RPM'i GPU sürücüsüne bildir")
     alanı var — ama **hiçbir ASL kodu SFAN'a yazmıyor**, sürekli 0.
     Ayrıca bu metodun `PSH0=2` dalı bizim zaten bildiğimiz PC00/PCI0
     yazım hatasını (`TGPU = \_SB.PC00.AMW0.LTGP`) içeriyor — 0x4B/TGP
     ölümünün ikinci kanıtı.
   - Modern `NPCF._DSM` → `NPCF()` metodu (Dynamic Boost, UUID
     `36b49710-2483-11e7-9598-0800200c9a66`): 6 alt-fonksiyon (0-5) tam
     okundu — TGPA/TGPD/MAGA/MIGA/CUSL/CUCT hepsi CPU/GPU watt bütçesi;
     **fan'la hiçbir ilgisi yok**, SFAN'dan bahsetmiyor bile.
4. **4. WMI GUID çözüldü:** Canlı sistemde `ABBC0F6C/6F/72/75` kayıtlı
   (doc'ta yalnız 3'ü izleniyordu). `_WDG` tablosu byte-byte decode
   edildi: `6C`→ObjectID "AC"→zaten bilinen `WQAC` (sabit 1 döndüren
   taslak), `6F`→"BC"→`WMBC`, `75`→"BD"→`WMBD`, **`72`→Flags=Event
   (Method/Data DEĞİL)**→bilinen `Notify(AMW0,0xD2)` dock/donanım-
   değişikliği kanalı. Gizli 5. sınıf yok — 4'ü de zaten haritalıydı.

### Sonuç
34 ACPI tablosunun (DSDT + 33 SSDT) TAMAMI artık taranmış durumda. BIOS'un
gerçekten çok-kanallı bir mesaj mimarisi var (ERCD çok-opcode'lu, iki ayrı
NVIDIA _DSM arayüzü, WMI event kanalı) — kullanıcının sezgisi bu noktada
doğruydu ve önceki turun taşımadığı gerçek yapıyı ortaya çıkardı. Ama fan
eğrisi/duty için kullanılan mesaj **ACPI'nin hiçbir köşesinde görünmüyor**.
İki olasılık kalıyor: (a) GCC'nin Windows sürücüsü ERCD'ye ACPI-dışı,
doğrudan bir opcode ile gidiyor (bizim göremediğimiz), (b) EC'ye tamamen
ACPI-dışı bir yoldan (ham SMBus/port I/O) erişiyor. İkisi de yalnız
Windows tarafında trafik yakalamayla (RWEverything/WMIExplorer, plandaki
mevcut adım) çözülebilir — NixOS/Linux tarafında ACPI-görünür başka
keşfedilecek yol kalmadı.

## SSDT9 PC00→PCI0 düzeltmesi — initrd ACPI table upgrade (2026-07-12)

Yukarıdaki "Gelecek işler #1" uygulandı. Modül: `system/arch/aerox16/acpi.nix`.

### Sorun (özet)
SSDT9 (`OptRf2`/`Opt2Tabl`, OemRev 0x1000, 13612 B) içindeki NVIDIA legacy
GPS metodu (`\_SB.PCI0.GPP9.PEGP.GPS`, PSHAREPARAMS/0x2A) `\_SB.PC00.AMW0.LTGP`
okuyor — PC00 Intel şablon artığı, doğrusu PCI0. Tam 2 geçiş (bayt ofsetleri
**1305** = `External` deklarasyonu, **8030** = `TGPU = ...LTGP` okuması, PSH0=2
dalı). GPS LTGP'yi yalnız OKUR. dmesg imzası (bu boot'ta 32 kayıt vardı):
`ACPI Error: Aborting method \_SB.PCI0.GPP9.PEGP._DSM ... (AE_NOT_FOUND)` +
`NVRM: GPU0 pfmreqhndlrCallACPI: Unable to retrieve PFM_REQ_HNDLR_PSHAREPARAMS
... rc = 59`. Sonuç: NVRM log spam + WMBD 0x4B (TGP set, 75–87 W) işlevsiz.

### Faz A — configfs shim ile reboot'suz kanıt (2026-07-12, BAŞARILI)
`CONFIG_ACPI_CONFIGFS=m` ile küçük ek SSDT (`ZIXAR`/`Pc00Shim`: hayalet
`\_SB.PC00.AMW0` + `Name(LTGP, Zero)`; iasl 6141 için `_ADR` gerekti, `_HID`
bilerek yok) canlıya yüklendi. Üç kollu kanıt:
- `\_SB.PC00.AMW0.LTGP` → `0x0` (shim öncesi bu yol AE_NOT_FOUND'du)
- negatif kontrol `\_SB.PC00.AMW0.XXXX` → `AE_NOT_FOUND` (düzenek sağlam)
- **GPS uçtan uca**: doğrudan `GPS 0 0x200 0x2A {0x02,0,0,0}` çağrısı →
  GPSP buffer döndü: `RETN=0x0102, VRV1=0x00010000, TGPU=0` — abort YOK.
  (GPS guard'ı yalnız `Arg1==0x0200`; PSH0 = Arg3'ün ilk 4 biti.)
Not: configfs tablosu reboot'a kadar sökülemez; taint 'A' + hayalet düğüm
reboot'la gider. Shim kalıcı çözüm DEĞİL (ayrı `LTGP` kopyası — WMBD'nin
yazdığı gerçek LTGP'yi göstermez); kalıcı çözüm tablonun kendisini düzeltmek.

### Kalıcı fix — binary patch + initrd upgrade
- **iasl recompile YOK**: 'PC00' AML'de 4-baytlık NameSeg → yerinde
  `'PC00'→'PCI0'` (×2) + checksum. Patcher: `system/arch/aerox16/acpi/patch-ssdt9.py`
  (boy/imza/OemId/OemTableId/geçiş-sayısı/OemRev guard'ları — biri tutmazsa
  build FAIL). Pristine dump: `system/arch/aerox16/acpi/ssdt9-pristine.dat`
  (sha256 `03b2207e...cb01dd`, modülde sabit; 2026-07-11 dökümü = bugünkü
  firmware, cmp ile doğrulandı).
- **Kernel eşleşme kuralı** (drivers/acpi/tables.c, kaynaktan doğrulandı):
  imza+OemId+OemTableId eşleşmeli **VE yeni OemRev KESİN büyük** olmalı
  (`existing >= new → skip`). Eşit kalsaydı override olmaz, tablo scan'de
  **duplicate** SSDT olarak yüklenirdi (AE_ALREADY_EXISTS fırtınası) →
  OemRev 0x1000→**0x1001**. Checksum 0xC4→**0x91**; kernel initrd tablosunun
  checksum'ını ayrıca doğrular (bozuksa tabloyu düşürür → status quo, güvenli).
- **initrd**: sıkıştırmasız newc cpio (`kernel/firmware/acpi/ssdt9-pc00fix.aml`,
  bsdtar — nixpkgs microcode-amd deseni) `boot.initrd.prepend` ile eklenir;
  amd-ucode `mkOrder 1` ile önde kalır (doğrulandı: initrd'de microcode ofset
  110 < acpi 307310). `Opt2Tabl` 33 SSDT içinde benzersiz → eşleşme şaşmaz.
- Çalışma zamanı ayak izi SIFIR (yalnız initrd içeriği) → 4.28W idle tabanı
  yapısal olarak korunur.

### Reboot sonrası doğrulama (Faz C — İLK BOOT'TA KOŞ)
1. `sudo dmesg | grep -i 'table upgrade'` → `override [SSDT-OptRf2-Opt2Tabl]`
   görünmeli. **`install [SSDT-...]` görünürse** rev eşleşmesi başarısız =
   duplicate yüklendi → önceki Limine generation'a dön. `Bad table checksum`
   da kabul edilemez. Microcode erken yükleme satırı hâlâ durmalı.
2. İçerik: `sudo grep -la Opt2Tabl /sys/firmware/acpi/tables/SSDT*` → o dosyayı
   `/nix/store/llxgbia85wxld0v0qizsmjfpz0c7a4jc-acpi-ssdt9-pc00fix/ssdt9-pc00fix.aml`
   ile `cmp` (veya `xxd -l 28`: ofset 9 = 0x91, ofset 24 = `01 10 00 00`).
3. Spam: dGPU (0000:64:00.0) `runtime_status` suspended iken 3× `nvidia-smi`
   ile uyandır → `journalctl -kb --grep 'PSHAREPARAMS|AE_NOT_FOUND'` boş.
   (Not: TLP AC profili `control=on` yapıyor; D3cold döngüsü için pile geç
   veya `echo auto > .../power/control` + dGPU istemcilerini kapat.)
4. 0x4B fonksiyonel test: `nvidia-powerd` durdur → `WMBD 0 0x4B 80` →
   `nvidia-smi -q -d POWER` limit hareketi → `0x4B 87` ile bitir (0x4B
   `NLIM=1`'i reboot'a kadar açık bırakır) → powerd'yi geri başlat.
5. Idle: yapısal sıfır etki; istenirse tek `power_now` spot ölçümü.

Rollback: override yalnız generation'ın initrd'sinde yaşar — önceki Limine
generation'ı boot etmek anında geri alır. Kalıcı kaldırma = configuration.nix'ten
tek import satırı.

### BIOS güncelleme politikası (staleness)
BIOS güncellemesinden sonra İLK iş `dmesg | grep -i 'table upgrade'`:
- `override` satırı VARSA: mekanizma hâlâ eşleşiyor; ama BIOS SSDT9 içeriğini
  kimlikleri koruyarak değiştirdiyse bizim 0x1001 tablomuz yeni firmware
  içeriğini **maskeler** — ve sysfs artık BİZİM tabloyu gösterdiğinden saf
  yeniden dump kendini kandırır! → import'u kapat, temiz boot'ta yeniden dump
  al, diff'le.
- `install` satırı / `AE_ALREADY_EXISTS` gürültüsü VARSA: kimlikler değişmiş,
  tablomuz duplicate yüklenmiş (gürültülü ama tehlikesiz) → import'u kapat.
Her iki durumda da sha256 guard + patcher guard'ları, sabitler bilinçli
yenilenmeden build'i zaten durdurur.

### Kazanç ve sonraki adım
NVRM log hijyeni + 0x4B TGP kanalı (75–87 W, `NLIM=1` + `Notify(PEGP,0xC0)` →
sürücü GPS/PSHAREPARAMS'tan okur). Oyun projesi için ACBT'ye (0x4C) ek ince
sustained-TGP kolu; game-perf entegrasyonu ayrı iş (ölçümle).

## Sürücü 0.2.0'a yükseltme (2026-07-29) — UYGULANDI + DOĞRULANDI

Upstream `0.2.0` (tag `8bd8bef`, 2026-07-05) çıktı; pin `912b4e9` (2026-06-08)
→ arada 25 commit. `master` (`fc2f217`, 2026-07-19) 0.2.0'dan yalnız 2 paketleme
commit'i ileride, fonksiyonel fark yok → tag pinlendi.

### Bizim 4 bulgumuzun durumu: HİÇBİRİ düzelmedi
Beklenen sonuç — issue #22 yorumumuz 2026-07-11, tag ondan 6 gün eski. Kaynaktan
teyit edildi:
- Sessiz mod probe'u kelimesi kelimesine aynı (`if (output < 0)`).
- `convert_fan_rpm` hâlâ `"GIGABYTE GAMING"` dışındaki **tüm** ailelere uygulanıyor.
- `gpu_boost=3` (dGPU eject) ve custom-fan ölülüğü: dokunulmamış. Issue #22 açık.

### Bizi ilgilendiren yenilikler
- **PWM düğümleri (salt-okuma) sysfs + hwmon'da**: `FAN_PWM 0x50` (=`FDTY`) ve
  `GPU_FAN_DUTY 0x47` (=`GDTY`). Defterdeki preset karakterizasyonunda
  `acpi_call` ile okuduğumuz duty telemetrisi artık düz hwmon okuması.
- Probe eğrinin 15 noktasını okuyor (`FAN_INDEX_VALUE 0x68` döngüsü). Bizde
  geri-okuma hep 0 (EC tabloya işlemiyor, E1-E8) → içerik değersiz, ama WMBC
  0x68'in içindeki `Sleep(100ms)` × 15 = **modül yüklenmesi ~1.5 sn uzuyor**.
- `light_sensor` yeni 4-baytlık `0xFC` metodu. Bizde `0xFC->0` ölçüldü (Faz F)
  → probe eski metoda düşecek, bağlanmayı engellememeli.
- Çift fan mantığı `CPU_FAN_DUTY 0x46` okumasıyla feature-detect ediliyor; bizde
  `FDTY` fan dururken 0, dönerken ≠0 → bu bayrak boot anına göre değişebilir.
  Fan hızı yazma zaten ölü olduğu için sonucu yok.
- DMI tablosuna `"AERO"` ve `"GIGABYTE GAMING"` eklendi; bizim `"GIGABYTE AERO"`
  zaten vardı → eşleşme değişmedi.

### Kırıcı değişiklik (bizi etkilemiyor)
`fan_custom_speed` artık 25-100/5'in katı değil, ham **0-255**. O düğümü
kullanmıyoruz (E7/E8'de değer↔RPM korelasyonu sıfır çıkmıştı).

### `patches` → `postPatch` geçişi (neden)
0.2.0'da probe'un ilk satırı `u8 result, result2;` → `u8 result;` oldu; eski
`aorus-laptop-silent-0x57.patch`'in bağlam bloğu bu satırı içeriyordu. GNU
patch varsayılan **fuzz=2** ile böyle bir hunk'ı yine de yapıştırabilir —
yani sessizce "başarılı" olur. `substituteInPlace --replace-fail` ise hedef
metin kaybolduğu an build'i açık hatayla düşürür; upstream refactor'lerine
karşı doğru failure mode bu. Yamalar (`gigabyte-wmi.nix`, `postPatch`):
1. `FAN_SILENT_OLD` → `FAN_SILENT_MODE` + `if (output < 0)` → `if (ret == 0)`
   (Faz F §2'nin aynısı).
2. `convert_fan_rpm` gövdesi no-op (`return fan_rpm;`) — tek çağrı yeri var ve
   bu derleme yalnız bu makine için. Upstream'e gidecek biçim DMI dalına
   `"GIGABYTE AERO"` eklemek (Faz F §1); local'de bilerek sadeleştirildi.

### Doğrulama sonuçları (2026-07-29 reboot sonrası)
| Kontrol | Sonuç |
|---|---|
| Build | ✅ Her iki `--replace-fail` hedefi kaynakta bulundu (bulunmasa build düşerdi) |
| Modül canlı | ✅ `srcversion` `1B107436…` → **`922D3D6F…`**; `fan_pwm` düğümü belirdi |
| Probe bağlandı | ✅ Tüm sysfs düğümleri yerinde; `charge_limit=60`, `fan_mode=0` |
| Yama 1 (sessiz mod) | ✅ dmesg: `aorus_laptop: Newer model detected, using new silent fan mode ID` |
| Yama 2 (RPM swap) | ✅ `fan1_input=5555`, `fan2_input=5769` (boot rampası). Swap sürseydi aynı fan **45845** (0xB315) yazardı — imkânsız değer. Fanlar durunca ikisi de 0 |
| Yeni PWM kanalları | ✅ `pwm1`/`pwm2`/`fan_pwm` okunuyor; fan-stop'ta 0 (mod 0, <48 °C — preset tablosuyla tutarlı) |
| Işık sensörü | ✅ `Using old light sensor method` — `0xFC->0` ölçümümüzün (Faz F) beklediği dal |
| Servisler | ✅ `gigabyte-power-profile` + `gigabyte-charge-limit` `status=0/SUCCESS` |

**Henüz test edilmedi:** Süper+M döngüsü (0→1→2→5) ve sessiz modun *duyulur*
etkisi — ikincisi zaten Faz F'ten beri açık (AC + yük gerektiriyor; yama
selector'ü düzeltir, o selector'ün bu firmware'de ses farkı yaratıp
yaratmadığını değil).

**Yan bulgu:** "Dual fan speed control required" **artık basılıyor** (Faz F'te
hiç basılmamıştı). 0.2.0 bu yoklamayı `ec_read(0xB0/0xB1)`'den — bu eSPI'de boş
bölge — `CPU_FAN_DUTY 0x46`/`FDTY` okumasına çevirmiş. FDTY fan dururken 0
olduğundan bayrak **modül yüklenme anındaki fan durumuna bağlı**: boot'ta fanlar
dönüyorsa set, durgunsa değil. Fan hızı yazma bu firmware'de zaten ölü (E1-E8)
→ pratik sonucu yok, ama sürücü davranışı artık deterministik değil.

### Kabuk notu (bu doğrulamada bir tur kaybettirdi)
Kullanıcının fish'inde `grep` → **ripgrep** alias'lı. `grep -i 'a\|b'` rg'de
alternation DEĞİL, literal boru işareti arar → **sessiz yanlış negatif**
(dmesg'de mesaj vardı, komut boş döndü). `-E` de rg'de `--encoding`. Bu
defterdeki komutları kopyalarken `rg -i 'a|b'` kullan.

Rollback: `rev`/`hash`'i `912b4e9` +
`sha256-AoPKhoPk0/lJ+f+YJZPFpJEZjeY/2CY8WnZ0VmfrJ8A=` yapıp `postPatch`'i eski
`patches = [ ./aorus-laptop-silent-0x57.patch ];` satırına döndürmek yeterli
(dosya git geçmişinde duruyor).

## Sürücü master'a yükseltme (2026-08-16) — YEREL YAMALAR SİLİNDİ

**Her iki yamamız da upstream'e girdi.** Pin `8bd8bef` (0.2.0 tag, 5 Tem) →
`8abb6655` (master, 8 Ağu). Tag yok: 0.2.0 düzeltmelerden önce, sonraki tag
henüz kesilmemiş.

### Diff'in tamamı (0.2.0 → master), üç değişiklik

| Commit | Ne | Bizim karşılığımız |
|---|---|---|
| `fdfa76a0` | `convert_fan_rpm` swap'ı DMI dalına `"GIGABYTE AERO"` eklenerek atlanıyor | Faz F §1 — raporumuzun önerdiği biçimin **birebir aynısı** |
| `c0b0bd14` | Probe, DMI ailesi eşleşince 0xFA yoklamasını hiç yapmadan `FAN_SILENT_MODE` (0x57) seçiyor (`goto obtain_fan_mode`) | Faz F §2 — **farklı yol, aynı sonuç** (biz `get_devstate` çağrısını değiştirmiştik, upstream kısa devre yapıyor) |
| — | `pr_*` string'lerine `\n` eklenmesi | kozmetik |

Başka fonksiyonel değişiklik yok — diff `diff -u` ile satır satır okundu, "muhtemelen
bir şey bozulmamıştır" varsayımı yapılmadı.

### Neden bu makinede tutuyor
Upstream'in iki düzeltmesi de `dmi_get_system_info(DMI_PRODUCT_FAMILY)` üzerinde
**tam string eşleşmesine** bağlı. Ölçüldü:

```
product_family: [GIGABYTE AERO]        ← iki dal da eşleşiyor
product_name:   [GIGABYTE AERO X16 1VH]
```

### Doğrulama (2026-08-16)
| Kontrol | Sonuç |
|---|---|
| `nixos-rebuild build` | ✅ 7 türev; `aorus-laptop-0.2.0-unstable-2026-08-08` derlendi |
| Derlenen `.ko` doğru kodu içeriyor mu | ✅ `strings` → `"Skipping silent fan mode ID check…"` **var**; yüklü eski modülde **yok** |
| `srcversion` | `4B2AB85A3316A028911ED17` (önceki `922D3D6F…`) |

**BEKLEYEN: REBOOT.** `modprobe -r aorus_laptop && modprobe aorus_laptop` bu
repoda **YETMEZ** — 16 Ağu'da denendi ve eski modül geri yüklendi. Sebep: NixOS'ta
`modprobe`'un arama yolu `/run/booted-system/kernel-modules/…` altına bakar; switch
yeni nesli aktive eder ama `booted-system` reboot'a kadar eski nesli gösterir.
Kanıt (switch sonrası, reboot öncesi):

```
/run/current-system → nh06kgrh…            (yeni nesil aktif)
/sys/module/aorus_laptop/srcversion → 922D3D6F…   (ESKİ modül)
dmesg: "Newer model detected, using new silent fan mode ID"   ← eski kodun mesajı
```

Yeni modülün imzası `srcversion = 4B2AB85A3316A028911ED17` ve dmesg'de
`"Skipping silent fan mode ID check, this only applies to old models"` satırı olacak.
**Ağaç-dışı modül güncellemesini doğrulamak için tek yol reboot.**

Reboot sonrası bakılacaklar: yukarıdaki iki imza + `fan1_input` makul RPM mi
(swap sürseydi ~40000 civarı imkânsız değer yazardı). DİKKAT: `fan1_input=0`
tek başına arıza DEĞİL — EC fan-stop uygularken normal değer. Yük altında
ölçerek doğrula; 16 Ağu ölçümü: boşta ~1900 RPM, 10 sn tam yükte 3000 RPM.

### `postPatch` neden tamamen silindi
İki `substituteInPlace --replace-fail` hedefi de master'da artık yok — bırakılsaydı
build **açık hatayla düşerdi**. Bu, 2026-07-29'da `patches` yerine
`--replace-fail` seçilmesinin tam olarak amaçlanan davranışı: upstream refactor'ü
sessizce yutmak yerine gürültüyle haber vermek. Tasarım işe yaradı.

**Rollback:** `rev`/`hash`'i `8bd8bef8b20f3790b57a8df9b6d36df5b094ec32` +
`sha256-WtQPFbYsrx5I10N3q4UyNiMfqIgVZBYvl/nqx32/Cb8=` yapıp yukarıdaki iki
`substituteInPlace` bloğunu geri koymak yeterli (git geçmişinde: commit 9ba2794 öncesi).

## Ortam ışığı sensörü (ALS) — AÇIK İŞ, 16 Ağu 2026

**Donanım VAR.** Gigabyte bu modelde "AI Eyecare" diye pazarlıyor: ortam ışığını
ölçüp parlaklığı ayarlıyor, kullanıcıya "sensör bölgesini kapatma" uyarısı yapılıyor.
Kullanıcı Windows'ta kullanmış. Linux'ta **hiçbir kanaldan dışarı çıkmıyor.**

### Ölçülen dört kanal

| Kanal | Bulgu |
|---|---|
| `aorus_laptop/light_sensor` | Düğüm var, salt-okunur, WMI `0xF7` (eski metod). **Işıkta da kapalıyken de sabit `0`** — kullanıcı fenerle test etti. Bu kanal ÖLÜ. Probe `0xFC` (yeni metod) da 0 döndürdüğü için eskiye düşüyor (`aorus_laptop: Using old light sensor method`) |
| AMD SFH | PCI cihazı **var**: `65:00.7 [1022:164a]`, `pcie_mp2_amd` bağlı, `amd_sfh` yüklü (`amd_pmf` kullanıyor). Ama **hiç sensör enumere etmemiş** — IIO cihazı yok. `amd-pmf AMDI0107:00: No Smart PC policy present` |
| EC paylaşım penceresi | DSDT'de **`LUXM/LUXL/LUXH` alanları VAR**: `OperationRegion (PECM, SystemMemory, 0xFC7E0800, 0x1000)` içinde `Offset(0x13)`+RPM1(16)+RPM2(16)+BHEA(8) → **`LUXM=0x18, LUXL=0x19, LUXH=0x1A`**, sonraki `Offset(0x1B)` aritmetiği doğruluyor. Mutlak adres **`0xFC7E0818/19/1A`**. Hiçbir ACPI metodu bu alanları OKUMUYOR (yalnız tanımlılar) |
| ACPI ALS / IIO | `ACPI0008` yok, `/sys/bus/iio/devices/` boş, DSDT'de `_ALI`/`_ALR`/`ambient`/`illuminance` sıfır eşleşme |

Not: klasik EC arayüzü (`OperationRegion (ERAM, EmbeddedControl, Zero, 0xFF)`) yalnız
`0x5F`/`0x60` tanımlıyor — LUX orada değil, yani `ec_sys` ile okuma garanti değil.

### Bekleyen deney: `scripts/als-probe.py` — YAZILDI, ÇALIŞTIRILMADI

`/dev/mem` üzerinden `0xFC7E0818`'i okur. `CONFIG_STRICT_DEVMEM=y` RAM'i korur ama
MMIO'ya izin verir; `CONFIG_IO_STRICT_DEVMEM=y` ise bir sürücü talep etmişse kilitler
— erişilip erişilemeyeceği denenmeden bilinmiyor.

**Script kendini doğrular:** aynı pencereden `RPM1/RPM2`'yi de okuyup `hwmon`'daki
gerçek `fanN_input` ile karşılaştırır. Tutmazsa "eşleme yanlış, LUX'a güvenme" der —
yanlış adresten çöp okuyup "sensör bulundu" yanılgısına düşmemek için.

Çalıştırma: `sudo python3 scripts/als-probe.py` — bir kez normal ışıkta, bir kez
sensöre fener tutarak.

| Sonuç | Yorum | Sonraki adım |
|---|---|---|
| RPM tutuyor + LUX fenerle değişiyor | kanal canlı | okuyucu + histerezisli parlaklık eşlemesi (udev+oneshot deseni değil; bu gerçek bir örnekleyici ister → idle bütçesi tasarımın merkezinde olmalı) |
| RPM tutuyor, LUX hep 0 | adres doğru, EC yazmıyor | `amd_sfh` neden sensör bulmuyor — muhtemelen sürücü bu modeli tanımıyor, upstream işi |
| `/dev/mem` reddedildi | `IO_STRICT_DEVMEM` kilitledi | küçük bir `ioremap` çekirdek modülü (`aorus-laptop` deseninin aynısı) |

**Hipotez:** Windows'taki "AI Eyecare" muhtemelen AMD PMF'in Smart PC politikası
üzerinden çalışıyor; o politika OEM'den gelen bir ikili ve Linux'ta yok. Doğruysa
sensör SFH'de duruyor ve onu kimse sorgulamıyor — o zaman doğru çözüm EC'yi
kurcalamak değil, `amd_sfh` tarafını kazmak.
