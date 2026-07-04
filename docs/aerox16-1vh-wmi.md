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
| Model | GIGABYTE AERO X16 1VH (DMI product family: "GIGABYTE AERO") |
| BIOS | FB0A (American Megatrends) |
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
  "temp speed" çiftleri). EC'den okunan tüm slotlar 0/0 (hiç programlanmamış).
  Sürücüdeki yazma yolu DENEYSEL — `aorus-laptop.c` ~satır 614:
  `payload = data << 8 | index` ("likely payload: speed, temp, index" yorumu
  ile — format doğrulanmamış). Bilinen-doğru veri olmadan yazmak riskli.
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

## DSDT analizi — TAMAMLANDI (2026-07-04, read-only)

DSDT döküldü ve WMBD/WMBC metodları çözüldü (dsl dökümü scratchpad'de
üretildi; WMBD ~satır 9101, WMBC ~9525). Ana bulgular:

### 1. Fan eğrisi 0x68 SADECE OKUMA — sürücünün yazma yolu çalışmaz
EC alanları: `XFNR (8-bit, offset 0x5A)` = nokta index'i, `XFN1 (16-bit)` =
temp/speed çifti. WMBD 0x68 `XFNR = Arg2` yapıyor — 8-bit alana yazım Arg2'yi
BAYTA KIRPAR; sürücünün `payload = data<<8 | index` tahmininde data kısmı
çöpe gider. Yani 0x68 hem WMBD hem WMBC'de "index seç + oku"dur.
**WMBD'de eğri-noktası yazan HİÇBİR selector yok** → bu modelde özel eğri
tablosu WMI'dan yazılamıyor; GCC'nin "custom" modu büyük ihtimalle
TENF+FLVL/FDTY tabanlı (sabit duty), nokta tablosu değil.

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
- **0xC9 → FNKS (1-bit!)**: "Fn Key Setting" — çıplak Fn davranışını EC
  seviyesinde değiştirme adayı (hwdb fix'imize firmware alternatifi)
- 0xC4 LCDO (LCD overdrive), 0xD9 KBAT (klavye aydınlatma zamanlayıcı?),
  0x80 PL3E (güç limiti?), 0xF6 KBLL (kb backlight), 0x87/0x88/0xE7
  (koşullu mantık — MUX/pil olabilir, çözülmedi)
- WMBC ek okunabilirler: 0x6F, 0xA2, 0xE3, 0xEB, 0xEF (haritalanmadı)

### Sonuç
Windows/GCC verisi hâlâ değerli ama artık başka amaçla: eğri yazmak için
DEĞİL (donanım desteklemiyor), GCC'nin 0x46/0x47/0x4A-0x4C selector'lerini
hangi değerlerle kullandığını görmek için. "Yazılım fan eğrisi" istenirse
Linux'ta hwmon sıcaklığı okuyup 0x46/0x47 duty yazan küçük bir servisle
yapılabilir (deneme onayı alınarak).

## Uygulama planı (veri geldikten sonra)

1. GCC değerleriyle `fan_curve_data` yazma formatını doğrula
   (yaz → `fan_curve_data` geri oku → hwmon RPM'i sıcaklıkla izle)
2. Çalışıyorsa: "sessiz-güvenli" özel eğri tasarla, NixOS modül opsiyonu yap
   (`hardware.aero-x16.fanCurve = [ {temp=50; speed=30;} ... ]` gibi)
3. `gigabyte-power-profile`'a custom eğri modunu entegre et (ör. AC'de custom)
4. Bulguları tangalbert919/gigabyte-laptop-wmi'ye issue/PR olarak raporla
