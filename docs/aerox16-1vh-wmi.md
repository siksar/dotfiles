# AERO X16 1VH — EC/WMI Tam Kontrol Projesi

**Hedef:** Windows yeni SSD'ye kurulduğunda Gigabyte Control Center'dan (GCC)
referans verileri toplayıp, EC/BIOS'un sunduğu TÜM ayarları Linux'ta WMI
üzerinden deklaratif (NixOS modülü) olarak yönetmek. Özellikle: doğrulanmış
özel fan eğrileri.

**Durum:** Beklemede — Windows kurulumunu bekliyor (2026-07-04 itibariyle
sistemde Windows yok; ileride yeni SSD'ye kurulacak).

---

## Donanım / yazılım envanteri

| Bileşen | Değer |
|---|---|
| Model | GIGABYTE AERO X16 1VH (DMI product family: "GIGABYTE AERO", SKU: EG61VH) |
| BIOS | FB0A (American Megatrends, 2026-05-28, release 5.35) |
| EC firmware | 3.10 (DMI `ec_firmware_release`); çip büyük olasılıkla ITE IT55xx — Windows'ta HWiNFO ile kesinleşecek |
| EC erişimi | eSPI paylaşımlı bellek: PECM @ 0xFC7E0800 (+ ECM2/USEC); klasik port-EC neredeyse boş |
| EC sürücüsü | [tangalbert919/gigabyte-laptop-wmi](https://github.com/tangalbert919/gigabyte-laptop-wmi) → `aorus-laptop.ko` (`modules/hardware/gigabyte-wmi.nix`) |
| WMI GUID'leri | ABBC0F6F / ABBC0F72 / ABBC0F75 (WMBC/WMBD metodları) |
| Dahili klavye | USB-HID 0414:8104 |
| sysfs | `/sys/devices/platform/aorus_laptop/` |

## Şu an Linux'ta çalışanlar

- `fan_mode`: 0=normal, 1=sessiz, 2=oyun, 3=custom, 4=auto-max, 5=fixed
  → `gigabyte-power-profile` servisi AC'de 0, pilde 1 yapıyor (udev ACAD tetikli)
- `gpu_boost`: 0-3 (WMI `GPU_QBOOST` 0x51) → AC'de 2, pilde 0
- `charge_mode`/`charge_limit`: custom(1) + %80 (boot'ta servisle)
- hwmon: 4× fan RPM + 3× sıcaklık (`sensors`, btop, Caelestia dashboard)
- Fn tuşu düzeltmesi: çıplak Fn = F20 (HID 0x7006f) → hwdb `reserved`
  (xkb F20'yi XF86AudioMicMute'a eşlediğinden mic toggle kaosu yaratıyordu)

## Eksik / deneysel olanlar

- **Özel fan eğrisi**: 15 nokta (`fan_curve_index` + `fan_curve_data`,
  `data = speed*256 + temp`). EC'den okunan tüm slotlar 0/0 (hiç
  programlanmamış). Yazma formatı ARTIK DOĞRULANDI (DSDT XFNW 24-bit +
  resmî MOF SetFanIndexValue — bkz. aşağıdaki analiz bölümleri); yalnızca
  canlı test kaldı (deneme onayıyla).
- `fan_custom_speed`: %25-100 arası 5'in katları (custom modda)
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

### Sonuç (güncel)
Fan eğrisi WMI'dan yazılabilir (0x68/XFNW) — Windows/GCC verisi artık
"format keşfi" için değil **doğrulama ve güvenli referans değerler** için
gerekli: GCC'nin preset eğrilerdeki temp→% değerleri, 0x46/0x47 doğrudan
duty ve 0x4A-0x4C watt selector'lerini hangi değerlerle sürdüğü.
Alternatif B planı (hwmon oku → 0x46/0x47 duty yaz servisi) hâlâ geçerli.
Her iki yol da deneme onayı alınarak test edilecek.

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

## Uygulama planı

1. **(Windows beklemeden yapılabilir, deneme onayıyla)** Eğri yazma canlı
   testi: `fan_curve_index`/`fan_curve_data` yaz → WMBC 0x68 ile geri oku →
   `fan_mode` 3'e al → hwmon RPM'in sıcaklıkla eğriyi izlediğini doğrula.
   Güvenlik: test eğrisi hiçbir noktada stok "normal" modun altına inmesin;
   sorun olursa `fan_mode` 0'a dönüş anında kurtarır.
2. Çalışıyorsa: "sessiz-güvenli" özel eğri tasarla, NixOS modül opsiyonu yap
   (`hardware.aero-x16.fanCurve = [ {temp=50; speed=30;} ... ]` gibi)
3. `gigabyte-power-profile`'a custom eğri modunu entegre et (ör. AC'de custom)
4. Windows/GCC verisi gelince preset eğri değerlerini ve 0x4A-0x4C watt
   selector kullanımını referans al; EC çipini HWiNFO ile kesinleştir
5. Bulguları (XFNW 24-bit doğrulaması + MOF eşleşmesi) tangalbert919/
   gigabyte-laptop-wmi'ye issue/PR olarak raporla — driver'daki "likely
   payload" yorumu kaldırılabilir, mod adlandırmaları (0x70/0x71) düzelebilir
