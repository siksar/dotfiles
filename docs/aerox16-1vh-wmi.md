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

## Uygulama planı

1. ~~Eğri canlı testi~~ YAPILDI (2026-07-05): tüm override yolları ölü;
   yalnız preset modlar çalışıyor. Eğri projesi Windows yakalamasına ertelendi.
2. **gpu_boost düzeltmesi**: 0x51'e AC'de 2 yazmak no-op (DSDT'de case yok);
   pilde 0 sonrası boost'u geri açan yok → AC'de 1 yazılmalı. Faz D'de
   nvidia-smi ile doğrulanıp `gigabyte-power-profile`'a işlenecek.
3. **Faz D — dGPU watt testi (0x4A-0x4C, acpi_call)**: oyun kapalıyken,
   her yazma tek tek onaylı, nvidia-smi ile alan eşleşmesi; kalıcılaştırma yok.
4. **Faz E — FNKS (0xC9) testi**: WMBC ile oku → tersini yaz → libinput ile
   çıplak Fn gözle → geri al. hwdb fix'i yerinde kalıyor.
5. Windows kurulunca: GCC'nin fan kanalını yakala (RWEverything/WMIExplorer,
   ERCD komutlarına odaklan), preset eğri değerlerini ve 0x4A-0x4C/0xF1-0xF3
   kullanımını referans al; EC çipini HWiNFO ile kesinleştir.
6. Upstream raporu: `docs/upstream-gigabyte-wmi-report.md` (issue taslağı) —
   byte-swap RPM bug'ı, ölü fan yolları (Issue #35 ailesi), 0x51 tehlikesi
   (3 = dGPU eject!), MOF ad düzeltmeleri, model çalışıyor raporu.
7. acpi_call GEÇİCİ — Faz D/E sonrası kaldır/kalıcılaştır kararı kullanıcıda.
