# AERO X16 1VH — EC/WMI Tam Kontrol Projesi

**Hedef:** EC/BIOS'un sunduğu tüm ayarları Linux'ta WMI üzerinden deklaratif
(NixOS modülü) yönetmek; referans veriler Windows'a GCC (Gigabyte Control Center)
kurulunca toplanacak.

**Durum (16 Ağu 2026, kesin):** Özel fan kontrolü (eğri/fixed/doğrudan duty) bu
firmware'de (FB0A / EC 3.10) **kapalı** — eğri tablosu EC belleğinde doğrudan
gözlendi, bkz. "Özel fan eğrisi — DOSYA KAPANDI". Preset modların hepsi çalışıyor
(ölçüm: "Fan modu ölçümü"). ERCD de 11 Tem 2026'da ölçülüp kapalı çıktı. Gerçek
özel-fan kanalı Linux'tan görünmüyor → yalnız Windows/GCC yakalaması kaldı.

---

## Donanım / yazılım envanteri

| Bileşen | Değer |
|---|---|
| Model | GIGABYTE AERO X16 1VH (DMI product family: "GIGABYTE AERO", SKU: EG61VH) |
| BIOS | FB0A (American Megatrends, 2026-05-28, release 5.35) |
| EC firmware | 3.10 (DMI `ec_firmware_release`); çip büyük olasılıkla ITE IT55xx — Windows'ta HWiNFO ile kesinleşecek |
| EC erişimi | eSPI paylaşımlı bellek: PECM @ 0xFC7E0800 (+ ECM2/USEC); klasik port-EC neredeyse boş |
| EC sürücüsü | kendi sürücümüz `aero_eg61h` (`~/aero-eg61h`, flake input; `system/arch/aerox16/wmi.nix`). 7 Eyl 2026'ya kadar [tangalbert919/gigabyte-laptop-wmi](https://github.com/tangalbert919/gigabyte-laptop-wmi) → `aorus-laptop.ko` |
| WMI GUID'leri | ABBC0F6C / 6F / 72 / 75 (ayrıntı: "Tam ACPI taraması" §4) |
| Dahili klavye | USB-HID 0414:8104 |
| sysfs | `/sys/bus/wmi/devices/ABBC0F75-8EA1-11D1-00A0-C90629100000-2/` (`fan_mode`, `fan_mode_choices`) + standart platform-profile ve power_supply ABI |

## Şu an Linux'ta çalışanlar

- `fan_mode`: **isimli** — `quiet · balanced · responsive · gaming · turbo`
  (7 Eyl 2026, `aero_eg61h`). Eski `aorus_laptop` numaraları 0/1/2/4/5 GEÇERSİZ;
  aşağıdaki 16 Ağu ölçüm tablosu hâlâ o numaralarla yazılı (bkz. "Sürücü değişimi"
  0x2C/ADJF tablosu).
  → `aero-power-profile` AC'de **responsive**, pilde **balanced** (12 Eyl 2026;
    udev ACAD + resume tetikli; öncesinde ikisi de balanced).
  → `aero-fan-cycle.service` döngüsü: balanced→quiet→gaming→turbo. 12 Eyl 2026'da
    ölçüldü: **hiçbir kısayola bağlı değil** (eski SUPER+M bağı Hyprland'la düştü).
    Kısayol masaüstü ayarlarından ELLE eklenmeli (`~/.config/cosmic`'e Nix'ten
    yazılmaz). Komut: `systemctl start aero-fan-cycle.service`
  → Eğriler firmware imajından çıkarıldı, `aero-sysfs/src/curves.rs`'te sabit veri;
    AERO Kontrol'ün "Fan curves" paneli bunları çiziyor. `responsive` ile `balanced`
    AYNI duty merdivenini kullanıyor (18…43%), fark eşiklerin ~14 °C erkene kayması.
    Fan 0, ilk yedi basamak (kaynak 0x05B92 vs 0x05CBE):

    ```
    responsive  40→18%  46→20%  51→21%  56→23%  60→26%  64→29%  67→33%
    balanced    54→18%  60→20%  66→21%  69→23%  72→26%  75→29%  78→33%
    ```

  (15 Ağu 2026 düzeltmesi: eski "4/5 ölü" notu yanlıştı — 4 → `0x70`, 5 → `0x6A`,
  ikisi de dolu case ve canlıda çalışıyordu; muhtemelen `fan_mode 1` misdetect'inden
  genellenmişti.)
- dGPU Dynamic Boost: acpi_call `WMBD 0x4C` → AC'de ACBT=80W (+ `nvidia-powerd` ile
  GPU tavanı 50→75W+), pilde 0. (`gpu_boost`/0x51 KULLANILMIYOR: 2=no-op, 3=dGPU
  eject, 1=LCBT(0) — işlevsiz)
- `charge_mode`/`charge_limit`: BCPS=4 (WMBD 0x64) + **%100** (3 Eki 2026; önceki %80,
  ondan önce %60). Standart ABI: `/sys/class/power_supply/BAT1/charge_control_end_threshold`.
  Sürücü yazımı geri okuyup doğruluyor (uyuşmazlıkta -EIO), uyanışta yeniden
  uyguluyor. DİKKAT: EC limiti AŞAĞI uygulamıyor — pil limitin üstündeyse boşalana
  kadar bekler.
- hwmon: 4× fan RPM (yalnız 1-2 gerçek) + 3× sıcaklık + 2× PWM/duty (CPU+GPU,
  salt-okuma).
- Fn tuşu: çıplak Fn = F20 (HID 0x7006f) → hwdb `reserved` (xkb F20'yi
  XF86AudioMicMute'a eşlediğinden mic toggle kaosu yaratıyordu).

## Sürücü değişimi — aorus-laptop → aero_eg61h (7 Eyl 2026)

`aorus-laptop` bırakıldı, yerine `aero_eg61h` (sürücü, servisler, polkit kuralı
`~/aero-eg61h`'deki NixOS modülünden).

**Üç ölçülmüş hata:**

1. `pwm1`/`pwm2` yazılabilir sunuyordu, fan umursamıyordu (üç bağımsız kanıt).
2. `temp2`/`temp3` ikisi de sabit sıfır (SKTC ölü kanal; tam yükte CPU 91 °C iken bile 0).
3. `fan_mode` YANLIŞ BİLDİRİYOR ve YANLIŞ YAZIYORDU (aşağıda).

### fan_mode — PECM+0x2C / ADJF doğruluk tablosu (ölçüldü 7 Eyl 2026)

acpi_call ile bit bit: `aorus_laptop` PECM+0x2C'nin b0/b1/b2'sini birbirini dışlayan
grup olarak yönetiyor ama b3'ü (ADJF) desene SAYMIYOR; `fan_mode = 4` bir mod değil,
"ADJF'yi kapat" işlemi. Sonuç ADJF'nin o anki durumuna bağlı; dördünün de doğru
çalıştığı bir durum YOK:

| yazılan | ADJF=1 iken | ADJF=0 iken |
|---|---|---|
| 1 "sessiz" | `0x09` = mod4 ✗ | `0x01` = quiet ✓ |
| 2 "gaming" | `0x0a` = TANINMIYOR ✗ | `0x02` = gaming ✓ |
| 5 "turbo" | `0x0c` = turbo ✓ | `0x04` = TANINMIYOR ✗ |
| 4 "dengeli" | `0x04` = TANINMIYOR ✗ | `0x04` = TANINMIYOR ✗ |

İki somut kayıp:

- **(a)** makine aylarca servis `fan_mode = 1` ("sessiz") yazarken aslında mod 4'te
  (`0x09`, yeni sürücüde `balanced`) koşuyordu;
- **(b)** Süper+M döngüsü ilk adımda ("4") ADJF'yi sıfırlıyordu; sonra hem döngünün
  "Turbo"su hem `game-perf`'in `fan_mode = 5`'i TANINMAYAN desene düşüyordu — oyun
  turbosu sessizce çalışmıyordu.

Yeni sürücü hedef deseni dört seçiciyle (0x57 CRAF, 0x71 FANB, 0x67 TENF, 0x6A ADJF)
TAM yazıp dört seçiciyle GERİ OKUYOR; uyuşmazlıkta `-EIO`. Beş tanınan desen: `0x00`
responsive, `0x01` quiet, `0x02` gaming, `0x09` balanced, `0x0C` turbo
(`~/aero-eg61h/kernel/aero-eg61h.h`, `aero-fan.c`).

## Fan modu ölçümü (16 Ağu 2026) — modlar ne YAPIYOR

> ⚠️ **BU TABLO ŞÜPHELİ (7 Eyl 2026).** `aorus_laptop` numaralandırmasıyla alındı; o
> numaralar PECM+0x2C desenlerine eşlenmiyor (bkz. "Sürücü değişimi"). Dördü belirgin
> farklı davrandığına göre dört AYRI desendi, ama hangisinin hangisi olduğu belirsiz.
> Yeni isimlerle YENİDEN ÖLÇÜLMELİ. Bulgu 1 ve 2'nin mekanizma hükmü etkilenmiyor.

**Yöntem.** 4 thread × Zen5 (cpu 0,2,4,6), 60 sn sabit yük, her mod ayrı koşu.
Modlar arası Tctl ≤ 52°C'ye kadar soğutma. Örnekleme 2 Hz; "kararlı" = yükün 50-60.
saniyesi ortalaması. Kaynaklar: k10temp Tctl, `amdgpu` PPT (APU paketi),
`aorus_laptop` fan1/fan2.

| Mod | Boşta fan | Kararlı Tctl | PPT | MHz | Yükte fan | Fan kalkışı |
|---|---|---|---|---|---|---|
| 4 auto-max | **0 RPM** | 98.1 °C | 53.9 W | 4849 | 4388/4556 | 7.8 sn @ 90.0°C |
| 1 sessiz | **0 RPM** | **95.0 °C** | **45.3 W** | 4742 | 2354/2715 | 6.8 sn @ 94.9°C |
| 2 oyun | 2156/2313 | 99.4 °C | 53.3 W | 4840 | 4893/5186 | zaten dönüyor |
| 5 turbo | 6594/6764 | 97.0 °C | 55.1 W | 4860 | 6362/6455 | zaten dönüyor |

### Bulgu 1 — fan sürekli sıcaklığı düşürmüyor, performansa çeviriyor

Mod 4 → 5'te hava %45 artıyor (4388 → 6362 RPM); sıcaklık karşılığı yalnız **1.1 °C**.
Kazanç güce (53.9 → 55.1 W) ve saate (4849 → 4860 MHz) gidiyor: boost Tjmax'i
hedefliyor. **"Sürekli yükte 99°C" fanla çözülebilir bir problem DEĞİL** (`MAINTAINERS`
"100°C by-design" notunun ölçülmüş hâli). Mod seçimi = gürültü/performans noktası.

### Bulgu 2 — mod 1 bir fan eğrisi değil, 95°C'lik kapalı çevrim denetleyici

Mod 1'de Tctl 8. saniyeden itibaren **tam 95.0 °C**'de çakılı; hedefi tutmak için gücü
ve saati kırpıyor:

```
 8.3s  95.0°C  51.1W  4840MHz
13.0s  95.0°C  50.0W  4803MHz
52.0s  95.0°C  45.0W  4742MHz
```

Bedeli %2.1 saat; karşılığı 4.4 °C ve fanın yarı devri.

### Bulgu 3 — boşta fan: 4 ve 1 durduruyor, 2 ve 5 durdurmuyor

Mod 4 ve 1 boşta 0 RPM. Mod 2 boşta 2156 RPM — sessiz masaüstünde duyulur, karşılığı yok.

### Düzeltilen iki yanlış iddia

- *"yalnız preset modlar (0/1/2) çalışıyor"* — 4 ve 5 de çalışıyor; ölü olan **özel**
  fan kontrolü (mod 3 / eğri / fixed duty).
- *"fan modları 2-4 etkisiz kalabiliyor"* (issue #35) — dördü de sıcaklık, güç, saat ve
  RPM'de ölçülebilir biçimde ayrışıyor.

### Ölçümün sınırları

Her mod **tek koşu**; başlangıç sıcaklıkları 37–49.5 °C (50-60. sn penceresi bunu büyük
ölçüde yıkıyor, tamamen değil). Yük **yalnız CPU**, dGPU boştaydı — **oyun için bu
tablodan sonuç çıkarma** (CPU+dGPU paylaşımlı ACBT bütçesi devreye girer).

## Özel fan eğrisi — DOSYA KAPANDI (16 Ağu 2026)

Defterde DSDT analizi §1 ("düğümler çalışmalı") ile Faz A ("eğri ölü") çelişiyordu.
Ölçümle kapatıldı: **Faz A haklı**, ama gerekçesi daha kesin. Faz A hükmü WMBC 0x68
geri-okumasının 0 dönmesine dayanıyordu — zayıf, çünkü okuma yolu (XFNR/XFN1) yazma
yolundan (XFNW) ayrı. Eğri tablosunun kendisi PECM'de çıplak duruyor (GTS0-GTSE
@0x3C-0x4A sıcaklıklar, FLVL @0x4B hız[0], GFS1-GFSE @0x4C-0x59 hız[1-14]) ve
`acpi_call` ile okunabiliyor.

### Ölçüm 1 — tablonun kendisi (acpi_call, PECM alanları)

| Adım | Gözlem |
|---|---|
| **Taban (hiçbir şey yazmadan)** | GTS0-GTSE **hepsi 0**, FLVL+GFS1-GFSE **hepsi 0** |
| Ham `WMBD 0x68` ile 15 nokta yazıldı | Her dönüş = yazılan payload'ın **birebir kendisi** (i=0 → `0x3C1400`); DSDT `Return(XFNW)` → register yazılıyor |
| Yazma sonrası tablo | GTS/GFS **hâlâ tamamen 0** |
| `WMBC 0x68` ön yüzü (15 index) | hepsi 0 (Faz A ile aynı) |
| Sürücü sysfs yolu (`fan_curve_index`+`data`, 15 nokta) | tablo yine **tamamen 0** → sürücü suçlu değil |
| `fan_mode 3` (TENF=1), 60 sn | fan **0 RPM**, FDTY/GDTY **0** boyunca |

**Taban satırı kilit bulgu:** tabloda *fabrika eğrisi bile yok* — **bu firmware eğri
tablosunu hiç kullanmıyor.** Preset eğrileri EC kendi ROM'undan sürüyor; GTS/FLVL/GFS
blokları (SSDT9'daki `PC00` gibi) bağlanmamış şablon artığı.

### Ölçüm 2 — "boş mu, yoksa okuyamıyor muyum?" (pozitif kontrol)

1. **Blok içinden yaz/oku.** `FLVL` (@0x4B) `GTSE` (@0x4A) ile `GFS1` (@0x4C) arasında.
   `WMBD 0x66` ile 111 → PECM 111, 222 → 222, 0 → 0. Blok canlı; 0 okumaları gerçek.
2. **`XFNR` (@0x5A) bizim izimizi taşıyor:** ölçüm sonunda 14 = son `WMBC 0x68`
   index'i.
3. **`/dev/mem` ile ACPI'den bağımsız yol.** PECM dökümünde `0x3C-0x59` sıfır; buna
   karşılık `0x8C`=0x5f(95), `0x90`=0x57(87), `0x1D`=0x0f, `0x2C`=0x01 — pencere doğru
   hizalı. (`/dev/mem` MMIO okuması bu çekirdekte **çalışıyor**; `IO_STRICT_DEVMEM`
   bu pencereyi kilitlemiyor.)

### Hüküm

- **§1'in register iddiası DOĞRU:** `WMBD 0x68` → XFNW yazılabilir, değeri tutuyor;
  format (`speed<<16|temp<<8|index`) doğru.
- **§1'in çıkarımı YANLIŞ:** EC XFNW'yi tabloya aktarmıyor, tabloyu zaten okumuyor.
- **Özel fan eğrisi bu makinede yok.** `fan_curve_index` / `fan_curve_data` /
  `fan_custom_speed` yazmayı kabul eder, hata vermez, **hiçbir şey yapmaz.**
  Otomasyonda kullanma.

### İki tuzak

- **`cat fan_curve_data` EC'yi OKUMAZ** (aorus-laptop): sürücünün RAM cache'ini basar
  (`aorus-laptop.c:630-636`; probe'da bir kez dolar, yazma cache'i yazılan değerle
  günceller). "Yazdım, geri okudum, tuttu" hiçbir şey kanıtlamaz. Gerçek geri-okuma:
  WMBC 0x68 (ön yüz) veya PECM alanları.
- **`WMBC` her selector'ü tanımaz.** `WMBC 0x66` 0 döndü, PECM `FLVL` 111/222
  gösterirken: DSDT WMBC switch'inde **`Case(0x66)` yok**, default 0 döner. WMBC'den 0
  almadan önce case'in DSDT'de var olduğunu doğrula.

### Yan bulgu — "CRAF 1'e yapışıyor" notu artık geçersiz

`fan_mode 1 → 3` geçişinde **CRAF 1 → 0** oldu. Eski gözlem sürücünün bozuk `0xFA`
selector'ünü kullandığı döneme aitti (Faz F §2); düzeltmeden sonra gerçek `0x57`
yazılıyor ve tutuyor.

### Yöntem notu

Pilde ve boşta (Tctl ~34 °C) ölçüldü; sonucu etkilemez (eğri tablosu ve XFNW AC/BAT'tan
bağımsız, tabanda da boş). Fan adımı yanlış negatif değil: yazılan eğri 20 °C'den
başlıyordu, 34 °C'de ~%31 hız talebine denk — eğri işleseydi fan dönmeliydi. Mod 3
60 sn boyunca korundu.

## Eksik / deneysel olanlar

- **Özel fan eğrisi: YOK** (16 Ağu 2026, yukarıda). Yeniden açmanın tek yolu Windows/GCC
  yakalaması.
- `fan_custom_speed` (FLVL): etkisiz. Register sağlam (WMBD 0x66 ile 111/222/0 PECM
  `FLVL`'de birebir geri okundu) — "yazılanı kimse tüketmiyor".
- `usb_charge_s3/s4_toggle`, `light_sensor`, `power_on_time`, `battery_cycle`
  attribute'ları keşfedildi ama haritalanmadı/kullanılmadı.

## Windows kurulunca toplanacaklar (GCC / AERO uygulaması)

1. **Custom fan modu eğri editörü** — 15 noktanın sıcaklık→% değerleri (ekran görüntüsü)
2. **Preset eğriler** (Normal/Quiet/Gaming görselleştiriliyorsa)
3. **GPU boost kademeleri** — adları ve varsa Watt/TGP değerleri
4. GCC kurulum dizinindeki config/XML dosyaları + `Get-WmiObject` ile WMI sınıf dökümü
5. Fan ayarı değiştirirken WMI izleme aracıyla (ör. WMIExplorer) çağrılan metod+parametreler
6. **EC çipi kimliği**: HWiNFO64 → Embedded Controller (ITE IT55xx beklentisi);
   alternatif RWEverything ile EC izleme (p37-ec projelerinin metodu)
7. GCC "custom" eğri kaydederken 0x68 (SetFanIndexValue) çağrılarını yakala → bizim
   yazmalarla karşılaştır; ERCD komutlarına odaklan

## DSDT analizi — TAMAMLANDI (2026-07-04; aynı gün GitHub bulgularıyla DÜZELTİLDİ)

WMBD ~dsdt.dsl:9101, WMBC ~9525.

### 1. Fan eğrisi 0x68: REGİSTER yazılabilir, ama TABLO ölü

**WMBD 0x68 → `XFNW` (24-bit, PECM offset 0x1D)** yazıyor (dsdt.dsl:9177, alan :8019).
Okuma yolu ayrı: WMBC 0x68 → `XFNR (8-bit, 0x5A)` index seç + `XFN1 (16-bit, 0x5B)`
oku. Yazma formatı `speed<<16 | temp<<8 | index` = MOF `SetFanIndexValue(Index,
Temperature, Speed)`'in little-endian paketi; aorus-laptop'un `payload = data<<8 |
index` yolu (data = speed*256 + temp, USAGE.md) bunu birebir üretiyordu. 16 Ağu
2026'da doğrulandı.

> **Düzeltme (16 Ağu 2026):** bölümün eski sonucu *"`fan_curve_*` düğümleri bu modelde
> ÇALIŞMALI"* YANLIŞTI — yazma formatının doğru olması EC'nin XFNW'yi tabloya aktardığı
> anlamına gelmiyor (bkz. "Özel fan eğrisi — DOSYA KAPANDI"). Ertesi gün Faz A olumsuz
> çıktığı hâlde bu cümle altı hafta yerinde kaldı.

### 2. Gerçek fan düğmeleri (sürücüde eşlenmemiş)
| Selector | EC alanı | İşlev |
|---|---|---|
| 0x46 | FDTY+FAN1 | CPU fan duty doğrudan yazma (%) |
| 0x47 | GDTY+FAN2 | GPU fan duty doğrudan yazma (%) |
| 0x50 | FDTY | CPU fan duty (tek alan) |
| 0x7D | TFAN | hedef fan? (haritalanmadı) |
| 0x66 | FLVL | custom fan seviyesi (sürücüde fan_custom_speed) |
| 0x67 | TENF | custom mod aç/kapa |

(Canlı testte hepsi ölü çıktı — "Canlı test sonuçları".)

### 3. dGPU güç limitleri (NVIDIA NPCF)
| Selector | Etki | Aralık |
|---|---|---|
| 0x4A | `NPCF.AMAT = Arg2*8` + Notify | 15-25 → 120-200 (W?) |
| 0x4B | `PEGP.NLIM=1; LTGP=Arg2` + Notify | 75-87 (TGP W?) |
| 0x4C | `NPCF.ACBT = Arg2*8` | 0-10 → 0-80 (boost W?) |

`gpu_boost` (0x51) kaba kademe; bunlar watt seviyesinde.

### 4. Diğer ilginç selector'ler
- **0xC9 → FNKS (1-bit, PECM 0x07.0)** — sonradan dahili klavye ana şalteri çıktı (Faz E).
- 0xC4 LCDO (LCD overdrive), 0xD9 KBAT (klavye aydınlatma zamanlayıcı?), 0x80 PL3E
  (güç limiti?), 0xF6 KBLL (kb backlight = MOF SetKeyBoardBackLight), 0x87/0x88/0xE7
  (koşullu mantık — MUX/pil olabilir, çözülmedi)
- WMBC: 0x6F=GetFanPWMStatus, 0xE3=getGpuTemp2, 0xEF=GetLid1Status (0xA2, 0xEB bilinmiyor)
- 0x61=BHEA oku (pil sağlığı), 0x63=WXCM(0xD2-0xD6, Arg2 5-baytlık buffer),
  0x64/0x65=BCPS/BCPC (MOF SetChargePolicy/SetChargeStop)

### Sonuç (2026-07-05 düzeltmesi)
0x68 → XFNW yazılabilir ama EC işlemiyor; 0x46/0x47 doğrudan duty ve 0x70 dahil tüm
override yolları da ölü ("Canlı test sonuçları").

---

## İnternet/GitHub araştırması — TAMAMLANDI (2026-07-04)

### Resmî WMI MOF haritası (alfc reposu)
[s-h-a-d-o-w/alfc](https://github.com/s-h-a-d-o-w/alfc) (arşivli; Aorus 15G/Aero 15)
`GB_WMIACPI_Get/Set` MOF dökümünü içeriyor (`frontend/src/data/mofGet.ts` /
`mofSet.ts`). WmiMethodId (ondalık) → bizim selector (hex) birebir eşleşiyor:

| Hex | MOF adı (Set) | Not |
|---|---|---|
| 0x46/0x47 | Get/SetCPU-GPUFanDuty | DSDT FDTY+FAN1 / GDTY+FAN2 ✔ |
| 0x51 | SetNvPowerConfig | sürücüdeki gpu_boost ✔ |
| 0x52-0x56 | SetNvD1..D5 | Nv güç kademeleri |
| 0x57 | SetNvThermalTarget | aorus-laptop bunu "silent mode" olarak kullanıyordu |
| 0x60 | SetDeepFan (5 nokta eğri) | bizim DSDT'de YOK |
| 0x64/0x65 | SetChargePolicy/Stop | BCPS/BCPC ✔ |
| 0x66/0x67 | SetCurrentFanStep / SetStepFanStatus | FLVL / TENF ✔ |
| 0x68 | **SetFanIndexValue(Index,Temp,Speed)** | 15 nokta eğri yazma ✔ |
| 0x6A/0x6B | SetFixedFanStatus/Speed | ADJF / FAN1 ✔ |
| 0x70/0x71 | SetFanAdjustStatus / SetAutoFanStatus | aorus-laptop 0x70="auto", 0x71="gaming" diyordu — MOF'la uyuşmuyor |
| 0x7D | SetFanSpeed | DSDT TFAN ✔ |
| 0xE1-0xE5 (Get) | getCpuTemp, getGpuTemp1/2, getRpm1/2 | hwmon kaynakları |

### EC erişim mimarisi
Fan/güç alanları klasik port-EC'de (0x62/0x66) DEĞİL, **eSPI paylaşımlı bellekte**:
`PECM` @ 0xFC7E0800, `ECM2` @ 0xFC7E0500, `USEC` @ 0xFC7E0250. Klasik `ERAM` neredeyse
boş (yalnız 0x5F/0x60) → **p37-ec / nbfc-linux port-EC haritaları (Intel dönemi
0xB0/0xB3) bu makinede GEÇERSİZ.**

### İlgili projeler (referans)
- [tangalbert919/gigabyte-laptop-wmi](https://github.com/tangalbert919/gigabyte-laptop-wmi) —
  7 Eyl 2026'ya kadarki sürücü. Issue #15: custom eğri v0.1.0'dan beri (USAGE.md:
  `data = speed*256 + temp`). Issue #35 (Aero 16 XE5, "FB0A" BIOS): "fan modları 2-4
  etkisiz" — bizde çürütüldü.
- [s-h-a-d-o-w/alfc](https://github.com/s-h-a-d-o-w/alfc) — MOF haritası + `acpi_call`
  çağırma deseni (`\_SB.PCI0.AMW0.WMBD 0 <id> <argümanlar little-endian tek integer>`).
- [rcassani/p37-ec-aorus15g](https://github.com/rcassani/p37-ec-aorus15g),
  [christiansteinert/p37-ec-aero-14](https://github.com/christiansteinert/p37-ec-aero-14),
  [mjguynn/a15kb](https://github.com/mjguynn/a15kb) — eski nesil port-EC; register'ları
  uymaz, metodoloji (Windows'ta RWEverything ile EC izleme) kullanılabilir.
- [nbfc-linux](https://github.com/nbfc-linux/nbfc-linux) — "Gigabyte Aero16.json"
  port-EC tabanlı; bu modelde uygulanamaz.

### EC çipi kimliği — henüz KESİNLEŞMEDİ
DMI yalnız `ec_firmware_release: 3.10`; ACPI tablolarında üretici adı yok, teardown
yok. AERO/AORUS ailesi tarihsel olarak ITE (IT5570E ailesi) ve eSPI + GB_WMIACPI deseni
uyumlu → güçlü tahmin ITE; doğrulama Windows'ta.

## TAM WMI selector envanteri — Faz 0 (2026-07-04, DSDT dispatch birebir okundu)

WMBD (dsdt.dsl:9101) ve WMBC (dsdt.dsl:9525) switch'lerinin eksiksiz dökümü. MOF adları
alfc'den; "—" = MOF'ta yok/bilinmiyor. "Sürücü sysfs" sütunu eski `aorus-laptop`
numaralarıdır.

### WMBD (Set) — yazılabilirler

| Hex | Yaptığı (DSDT) | MOF adı | Sürücü sysfs | Not |
|---|---|---|---|---|
| 0x46 | FDTY+FAN1 = Arg2 | SetCPUFanDuty | — | CPU fan duty % doğrudan |
| 0x47 | GDTY+FAN2 = Arg2 | SetGPUFanDuty | — | GPU fan duty % doğrudan |
| 0x4A | NPCF.AMAT = Arg2×8 (15-25) | — | — | dGPU watt (120-200); Get YOK |
| 0x4B | PEGP.NLIM=1; LTGP=Arg2 (75-87) | — | — | dGPU TGP W; Get YOK |
| 0x4C | NPCF.ACBT = Arg2×8 (0-10) | — | — | dGPU dyn-boost W (0-80); Get YOK |
| 0x50 | FDTY = Arg2 | — | — | CPU duty (FAN1'siz varyant) |
| 0x51 | 0→ACBT=0; 1→ACBT=LCBT; **2→HİÇBİR ŞEY**; 3→dGPU Eject Request(!); 4→dGPU power-on | SetNvPowerConfig | gpu_boost | Linux'ta LCBT=0 → 1 de işlevsiz; doğru araç 0x4C. **3'ten UZAK DUR** |
| 0x57 | GFAN=0; CRAF=Arg2 | SetNvThermalTarget | fan_mode 1 (silent) | CRAF 1-bit @0x2C.0 |
| 0x63 | WXCM 0xD2-0xD6 ← 5 bayt | — | — | CMOS NVRAM'a yazar (EC değil!) |
| 0x64 | BCPS = Arg2 | SetChargePolicy | charge_mode | |
| 0x65 | BCPC = Arg2 | SetChargeStop | charge_limit | |
| 0x66 | FLVL = Arg2 | SetCurrentFanStep | fan_custom_speed | FLVL @0x4B = eğri hız tablosunun 0. gözü |
| 0x67 | TENF = Arg2 | SetStepFanStatus | fan_mode 3 | custom eğri aç/kapa, 1-bit @0x2C.2 |
| 0x68 | XFNW = Arg2 (24-bit) | SetFanIndexValue | fan_curve_index+data | `speed<<16\|temp<<8\|index` |
| 0x6A | ADJF = Arg2 | SetFixedFanStatus | fan_mode 5 | 1-bit @0x2C.3 |
| 0x6B | FAN1 = Arg2 | SetFixedFanSpeed | — | |
| 0x70 | TFAN=0; GFAN=1; FAN1=FAN2=Arg2 | SetFanAdjustStatus | fan_mode 4 | sürücü "auto-max" diyordu |
| 0x71 | GFAN=0; FANB=Arg2 | SetAutoFanStatus | fan_mode 2 | sürücü "gaming" diyordu; FANB 1-bit @0x2C.1 |
| 0x7D | TFAN = Arg2 | SetFanSpeed | — | TFAN 1-BİT bayrak @0x0B.7 (hız değil!) |
| 0x80 | PL3E = Arg2 | — | — | 1-bit @0x0B.0 — PL3 enable bayrağı |
| 0x87 | WXCM(0xDA)+PLED (ters mantık) | — | — | power LED + CMOS kalıcılık |
| 0x88 | WXCM(0xD9)+BLED (ters mantık) | — | — | battery LED + CMOS kalıcılık |
| 0xA1 | stub (1 döner) | — | — | |
| 0xA3 | WXCM 0xD1 | — | — | CMOS |
| 0xC4 | LCDO = Arg2 | — | — | LCD overdrive, 1-bit @0x10.7 |
| 0xC7 | MUTE = Arg2 | — | — | @0x30.0 |
| 0xC9 | FNKS = Arg2 | — | — | 1-bit @0x07.0 (Faz E: klavye ana şalteri) |
| 0xCA | PSON = Arg2 | — | — | @0x0B.5 |
| 0xCB | WINK = Arg2 (+DBG8=0xEA) | — | — | @0xA1.1 |
| 0xD9 | KBAT = Arg2 | — | — | @0x30.2 |
| 0xE6 | WXCM 0xD0 | — | — | CMOS |
| 0xE7 | 0→dGPU dyn-boost KAPAT (DBAC/DBDC=1, AMAT=0, PPAB=0); 1→AÇ (AMAT=LMAT, PPAB=1) | — | — | NPCF Notify 0xC0 |
| 0xED | **GCC performans profili 0-3** (aşağıda); 4-5 boş | — | — | CPU+dGPU watt paketi tek çağrıda |
| 0xF1 | ECPT(0x30, Arg2÷1000) | — | — | **CPU güç limiti #1, mW** (muhtemel SPL) |
| 0xF2 | ECPT(0x32, Arg2÷1000) | — | — | **CPU güç limiti #2** (muhtemel SPPT) |
| 0xF3 | ECPT(0x34, Arg2÷1000) | — | — | **CPU güç limiti #3** (muhtemel FPPT) |
| 0xF6 | KBLL = Arg2 | SetKeyBoardBackLight | — | @0x31 |
| 0xFA | boş case | — | — | |

### WMBC (Get) — okunabilirler

0x46/0x50→FDTY, 0x47→GDTY, 0x57→CRAF, 0x61→BHEA, 0x63→RXCM 0xD2-D6 (5B buffer),
0x64→BCPS, 0x65→BCPC, 0x67→TENF, **0x68→XFNR=Arg2; Sleep(100ms); XFN1 döner**
(eğri noktası geri-okuma), 0x6A→ADJF, 0x6B/0x6F/0x70→FAN1, 0x71→FANB, 0x7D→TFAN,
0x80→PL3E, 0x87/0x88→PLED/BLED (ters), 0xA1→M029(4), 0xA2→(ACST==4 ? 1:0) (şarj
tamamlandı?), 0xA3→RXCM 0xD1, 0xC4→LCDO, 0xC7→MUTE, 0xC9→**FNKS (okunabilir)**,
0xCA→PSON, 0xD9→KBAT, 0xE1→CTMP (CPU °C), 0xE2 **ve** 0xE3→SKTC (aynı alan; MOF'un
getGpuTemp2 adı yanıltıcı), 0xE4→RPM1, 0xE5→RPM2, 0xE6→RXCM(0xD0)&0x7F,
0xE7→NPCF.DBAC, 0xEB→stub 1, 0xEF→~LIDF, 0xF6→KBLL.
Özel: `Arg1==3` → Notify(AMW0, 0xD2) (SMGR olay kanalı).
**0x4A/0x4B/0x4C'nin Get karşılığı YOK** → geri-okuma `\_SB.NPCF.<alan>` / nvidia-smi.
`0x66` için case YOK (default 0 — bkz. "İki tuzak").

### GCC performans profilleri (WMBD 0xED, Arg2=0-3)

ECPT(ofs, W): EC ERCD komutu 0x45 ile 32-bit mW yazar (0x30/0x32/0x34 → muhtemel
SPL/SPPT/FPPT). ECPL(): ERCD 0x45/0x4D → aktif profil seviyesini okur.

| Profil | CPU AC (0x30/0x32/0x34 W) | CPU DC (W) | dGPU ATPP | ACBT | AMAT |
|---|---|---|---|---|---|
| 0 | 20 / 65 / 65 | 15 / 30 / 30 | 160 | 0 | 120 |
| 1 | 25 / 65 / 80 | 19→20 / 54 / 54 | 200 | 80 | 120 |
| 2 | 19→30 / 80 / 80 | 19→20 / 54 / 54 | ECPL'e göre 240/200/160/120 | 160 | 120 |
| 3 | 25 / 80 / 80 | 19→20 / 54 / 54 | 200 | 160 | 120 |

("19→20" = DSDT aynı ofsete art arda iki yazım yapıyor.)

### PECM tam alan haritası (@0xFC7E0800)

> **Bu pencerenin İKİ adı var** (16 Ağu 2026): `OperationRegion (ECMM, SystemMemory,
> 0xFC7E0800, 0x1000)` (dsdt.dsl:7728) aynı adresi ikinci bir field kümesiyle kaplıyor.
> Bir alan `PECM`'de yoksa `ECMM`'e bak — `SUPL/SPPT/FPPT` (0x8D-0x8F) böyle atlanmıştı.

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
| 0x8C | TCLT (termal setpoint — bkz. "TCLT" bölümü) |
| **0x8D-0x8F** | **SUPL, SPPT, FPPT — `ECMM` overlay'inden (CPU güç limitleri)** |
| 0x90 | PPPT |
| 0x99-0xA0 | BATN |
| 0xA1 | bit0 FESC, bit1 WINK, bit2 BTKY |
| 0xF3, 0xF5 | CYC2, CYC1 (pil döngüsü) |

Eğri tablosu (GTS/FLVL/GFS) paylaşımlı bellekte çıplak; XFNW/XFNR yalnız ön yüz.

### "CPU boost / PBO EC'de var mı?" — CEVAP

- **Çarpan/voltaj/PBO/Curve Optimizer: YOK** (SMU işi; EC-WMI'da karşılığı yok).
- **CPU güç limitleri: VAR, watt hassasiyetinde** — 0xF1/0xF2/0xF3 (mW) + 0xED
  profilleri. (`wmi.nix` notu, 31 Tem: 0xF1-F3 EC tarafından geri yazılıyor.)
- dGPU: 0x4A/0x4B/0x4C watt + 0xE7 dyn-boost aç/kapa + 0xED paketi.

## Canlı test sonuçları — Faz A (2026-07-05, acpi_call dahil)

Tüm WMI fan-override yolları canlı denendi; **hiçbiri fiziksel PWM'i değiştirmiyor**.
EC fanları yalnız kendi iç mantığından sürüyor.

| Yol | Deney | Sonuç |
|---|---|---|
| 0x68 eğri (XFNW) | 15 nokta yazıldı (sysfs; hata yok), TENF=1 iken de | ❌ WMBC 0x68 hep 0; %100 bump'a RPM tepkisi yok (kesin kanıt 16 Ağu: "Özel fan eğrisi — DOSYA KAPANDI") |
| 0x67 TENF | mod 3; debug_method ile doğrulandı | Bit 1 oluyor, davranış değişmiyor |
| 0x66 FLVL + 0x6A ADJF (mod 5) | %60 verildi | ❌ RPM tepkisiz |
| 0x70 FAN1/FAN2+GFAN (mod 4) | arg 60 | Register 60 tutuyor (WMBC 0x70=60) ama FDTY/GDTY %16'da ❌ |
| 0x46 doğrudan FDTY (acpi_call WMBD) | arg 50 @ ~70°C yük | ~20 sn 50 tuttu, EC 20'ye geri ezdi; RPM sabit ❌ |
| 0x7D TFAN=1 + 0x46 | bayrak+duty | Bayrak yazıldı, etkisiz ❌ |
| **Preset modlar** | yük altında 0→1→2→0 | ✅ Mod 2 (0x71): 4 sn'de 2170→2730/3030 RPM; mod 1≈mod 0 (71°C'de) |

Ek bulgular:
- RPM byte-swap: hwmon ham 39435 (0x9A0B) ↔ gerçek 0x0B9A=2970 RPM — sebebi sürücüydü
  (Faz F §1). fan3/4 hep 0 (yalnız RPM1/RPM2 tach var).
- **debug_method = serbest WMBC okuma kapısı** (aorus-laptop): `echo <id> > debug_method;
  cat debug_method` → "id, değer". Arg2 hep 0 (0x68'de yalnız slot 0 okunur).
- ~~CRAF (0x57) 1'e yapışıyor~~ — GEÇERSİZ (16 Ağu): o dönem sürücü 0x57 yerine boş
  `0xFA` case'ini çağırıyordu (Faz F §2).
- FDTY/GDTY EC'nin ~20 sn periyotla (veya durum değişince) yenilediği telemetri; PWM
  komut register'ı DEĞİL.
- Stok eğri (mod 0): ~45-48°C altı 0 RPM; 51-53°C ≈ 2100; 57-60°C ≈ 2700-3300; 70°C oyun
  yükü ≈ 2100-2360 (iniş histerezisli).
- Hipotez: GCC'nin özel eğrisi ERCD üzerinden (sonradan ERCD de kapalı çıktı, aşağıda).

## Preset mod eğrileri — ölçülmüş karakterizasyon (2026-07-05)

Soğuma taraması + sabit yük noktalarıyla üç modun gerçek eğrisi (aorus numaraları;
değerler FDTY/GDTY duty% — EC'nin kendi PWM çıkışları; RPM ≈ duty×~110):

| CPU °C | Mod 0 normal | Mod 1 sessiz | Mod 2 oyun |
|---|---|---|---|
| <48 | 0/0 (fan-stop) | 0/0 (fan-stop) | 0/0 |
| 48-49 | 16/15 | 16/16 | 0/0 (**fan-stop ≤53-54'e kadar!**) |
| 50-59 | 19-20/20 | **16/16** (58°C'de 18/17) | 54-55°C: 16/16 |
| ~83 | 21/23 | 21/23 | **28/32** |
| 95 (tavan) | 21-24/23-27 | 21-23/23-27 | **32-33/35** |

- **Sessiz vs normal fark yalnız ~50-60°C bandında** (%16 vs %19-20 ≈ 1880/1900 vs
  2160-2330 RPM — duyulur); ≥~80°C'de birleşiyorlar. (Faz F: bu fark sürücüden
  gelmiyordu — sürücünün `fan_mode 1`'i o dönem no-op'tu.)
- **Oyun modu iki uçta farklı:** ≤53°C fan-stop (hafif kullanımda EN sessiz) ve ≥~70°C'de
  +7-12 puan agresif; 55-65°C'de normalden sessiz/eşit.
- **Hiçbir mod %35 duty üstüne çıkmıyor**; EC her modda CPU'yu 95°C SMU tavanında
  bırakıyor (2 çekirdek yük bile). Fanların %100 kapasitesi hiç kullanılmıyor.
- EC duty geçişleri yavaş/histerezisli (~30-60 sn); SKTC okuması ara ara 0, güvenilmez.

### Mod geçişi NASIL çalışıyor? (mekanizma, 2026-07-05)

WMI mod selector'leri fan değeri yazmıyor; PECM 0x2C'deki İSTEK bitlerini çeviriyor
(WMBC geri-okuma):

| Mod | CRAF(0x57) | TENF(0x67) | ADJF(0x6A) | FANB(0x71) |
|---|---|---|---|---|
| 0/1 | 1* | 0 | 0 | 0 |
| 2 | 1* | 0 | 0 | **1** |
| 3 | 1* | **1** | 0 | 0 |
| 5 | 1* | **1** | **1** | 0 |

- EC bitleri poll edip KENDİ ROM tablolarından birini seçiyor: FANB→oyun,
  (0x57 yazma olayı)→sessiz, hiçbiri→normal.
- TENF/ADJF yazılıyor ve kalıcı ama tüketici kodu yok → custom ölü. Değer taşıyan
  register'lar (XFNW, FLVL, FAN1/2, FDTY/GDTY) da etkisiz (16 Ağu'da doğrulandı).
  (ADJF=1 "mod 5 = max üfleme" olarak çalışıyor — bkz. "Fixed mod DÜZELTMESİ".)
- (*) "CRAF her modda 1" gözlemi GEÇERSİZ — sürücü 0x57'ye hiç yazmıyordu (yukarı bkz.).

## Faz D+E sonuçları — dGPU güç zinciri ÇÖZÜLDÜ + FNKS sürprizi (2026-07-05)

### dGPU: +25W Dynamic Boost kilidi açıldı
- Taban: RTX 5060 tavanı **50 W'ta sıkışık** (Min 5 / Max 85); NPCF.ACBT = **0** çünkü
  GCC'nin boot init'i (0xED) Linux'ta koşmuyor.
- **Çalışan zincir:** `WMBD 0x4C 10` → NPCF.ACBT=0x50 (80 W) → `nvidia-powerd` →
  **Current Power Limit 50 → 75 W** (dinamik, yükle 85'e kadar). Kalıcı: acpi_call +
  boot/AC-geçiş yazması + `hardware.nvidia.dynamicBoost.enable`.
- **BIOS yazım hatası:** `PEGP.GPS` `\_SB.PC00.AMW0.LTGP` arıyor (doğrusu PCI0) → her
  dGPU uyanışında AE_NOT_FOUND (NVRM PSHAREPARAMS hatası). 0x4B (TGP) ölü, 0x4A (AMAT)
  GPS üzerinden tüketilemiyor; NVPCF yolu (ACBT/DBAC) sağlam. → "SSDT9 PC00→PCI0
  düzeltmesi" ile çözüldü.
- `gpu_boost` (0x51): arg1 = `ACBT=LCBT` ama Linux'ta LCBT=0 → işe yaramaz. Doğru araç 0x4C.
- NPCF durumu (acpi_call): ATPP=0x168(360), AMAT=0x78(120), DBAC/DBDC=0.

### nvidia-powerd ve NVIDIA sürüm avcılığı (18–31 Tem 2026)

- **18 Tem 2026:** 610.43.02 pininden `nvidiaPackages.latest`'e geçildi — pinli
  sürümde Dynamic Boost kurulamıyor, GPU 30 W'ta kilitli görünüyordu (enforced 30 W <
  50 W varsayılan; profil/PPD/TLP ölçümle elendi; NVIDIA open-gpu-kernel-modules
  #392/#966).
- **SONUÇ (31 Tem 2026): sürüm avcılığı gereksizmiş.** nvidia-powerd sağlıklı (D-Bus
  bağlı, çökmüyor); tek yinelenen log "SBIOS disable Dynamic Boost DC controller" (DC =
  pil; muhtemelen zararsız). Kazanç sürümden değil WMI yan-kanalından: ACBT (0x4C) →
  nvidia-powerd → GPU tavanı KCD'de 38 W → 62-83 W (ham kayıt: 0xED logu). #392 (AMD
  CPU'da DB, genel sınırlama) ilgisiz.
- 595 dalı (beta/production) daha eski, bilinen oyun-donma sorunları (Tsushima,
  s2idle) — son çare. Geri pinlemek: `mkDriver { version + hash }`.

### FNKS (0xC9): "Fn ayarı" değil — DAHİLİ KLAVYE ANA ŞALTERİ
FNKS=0 → dahili klavye USB'de kalıyor ama TÜM raporlar kesiliyor ('a' dahil; hidraw ham
yakalama ile kanıtlı). FNKS=1 → anında geri. Çıplak Fn/F20 davranışını DEĞİŞTİRMİYOR.
WMBC 0xC9'dan okunabilir; kalıcılık test edilmedi (muhtemelen reboot'ta 1). Diğer Fn
bulguları: `Documentation/aerox16/fn-keys.md` (16 Eyl 2026'dan beri).

## Uygulama planı

TAMAMLANDI (2026-07-05): eğri testi (ölü), preset karakterizasyonu, mod mekanizması,
Faz D (dGPU boost zinciri kalıcı), Faz E (FNKS), upstream taslağı
(`Documentation/upstream/gigabyte-wmi-report.md`), acpi_call kalıcı. SSDT9 düzeltmesi
2026-07-12'de yapıldı.

### Gelecek işler
1. **FNKS klavye kilidi aracı**: WMBD 0xC9 0/1 — harici klavye modu / temizlik kilidi.
2. **0xF1-F3 CPU watt deneyleri** (SPL/SPPT/FPPT, RAPL/ryzen_smu ile doğrula) —
   `wmi.nix` notu (31 Tem): EC bunları geri yazıyor.
3. Windows kurulunca: GCC'nin fan kanalını yakala (ERCD komutlarına odaklan); preset
   eğri ve 0xED/0xF1-F3 kullanım değerlerini referans al; EC çipini HWiNFO ile kesinleştir.
4. Upstream issue (taslak hazır).

## Deneysel 0xED / 0xF1–F3 logu (oyun projesi Faz E — iskelet, 2026-07-05)

Protokol: `Documentation/gaming.md` "Faz E". Kural: tek yazım → ölç → logla → revert.
Ortam: AC + fan_mode 2 + sabit yük. Geri-okuma: 0xED → NPCF alanları (ACBT/AMAT);
0xF1–F3 → RAPL (Get yok).
**YASAK:** 0x51 (3=dGPU eject) · CMOS'a yazan 0x63/0x87/0x88/0xA3/0xE6 (reboot ile
sıfırlanmaz).

Taban (2026-07-06, stress-ng 16T, AC): RAPL sustained **21W** (SPL≈20 — GCC init'i yok,
profil 0 varsayılanı doğrulandı) · fan duty 18/17 @64°C · ACBT 80W → dGPU boşta tavan
60W · fan mod 2 · platform_profile=performance (o dönem TLP; PMF kaydırıcısı zaten
maksimumda — SPL'yi o yükseltmiyor).

| Tarih | Seçici | Yazılan | NPCF/ACBT yan etki | RAPL Δ | GPU Δ | Frametime | Hüküm | Revert |
|---|---|---|---|---|---|---|---|---|
| 07-06 | 0xED | 1 | görünür değişim yok (ACBT zaten 80) | 21→22W (gürültü) | tavan 60W sabit | — | nötr; manuel kurulum ≈ profil 1 | üzerine 0xED 2 |
| 07-06 | 0xED | 2 | **ACBT 80→160** (boşta tavan 60→70W) | 22W (SPL DEĞİŞMEDİ — ECPT→SMU köprüsü yok?) | **KCD: 38W → 62-83W sustained** (86-87°C'de ~70W ort); **fan duty 32-35% → 46/49%** (4400/4700 RPM) — profil fan eğrisini de yükseltiyor | GPU clock 2200-2600 sabit, util %100 | **BÜYÜK KAZANÇ — Windows farkının kaynağı** | KALICI: game-perf.service start=profil 2 (AC'de) / stop=profil 0 + ACBT restore (2026-07-06) |
| — | 0xED | 3 | | | | | | reboot |
| — | 0xF1 (SPL) | 25000 | | | | | | reboot |
| — | 0xF2 (SPPT) | 65000 | | | | | | reboot |
| — | 0xF3 (FPPT) | 80000 | | | | | | reboot |

## Faz F — sürücü bulgu doğrulama + upstream rapor kesinleşti (2026-07-11)

aorus-laptop kaynağı (`912b4e9`) satır satır okundu + Part 1 salt-okuma ölçümü
(`Documentation/aerox16/test-plan.md`). İki iddia eski taslaktakinden FARKLI çıktı.

### 1. RPM "byte-swap bug"ı — sebep TERS: sürücü fazladan swap'lıyor
Ham WMBC `0xE4 -> 2970` (0x0B9A), `0xE5 -> 3333` (0x0D05) = **zaten doğru sıra**; hwmon
`fan1_input=39435` (swab16(2970)), `fan2_input=1293` (swab16(3333)). EC doğru, sürücünün
`convert_fan_rpm`'i (`rol16 8`, `:178-182`) bozuyor — `"GIGABYTE GAMING"` dışındaki
tüm ailelere uygulanıyor (`:249-252`). Düzeltme: `GIGABYTE AERO`'yu no-swap dalına al.

### 2. Sessiz mod (`fan_mode 1`) sürücüde ÖLÜ — misdetect zinciri kanıtlandı
dmesg: **"Older model detected, using old ID"**. Deterministik: probe `get_devstate(0xFA)`
çağırıyor; X16 WMBC'de `Case(0xFA)` yok → **0** (ölçüldü: `0xFA->0`, `0xFC->0`, karşı-örnek
`0x57->1`). `if (output < 0)` (`:779-790`) 0'ı "eski cihaz" sanıyor → `fan_modes[1]=0xFA`
→ `echo 1 > fan_mode` = boş `Case(0xFA){}` (`dsdt.dsl:9105`). Doğru selector `0x57`.

### 3. Yan doğrulamalar
- `fan3/fan4_input=0` (yalnız 2 tach), `temp3_input=0` (`ec_read(0x62)` port-EC bu eSPI'de
  boş, `:234`). `temp1=95`, `temp2=67` swap edilmiyor, doğru.
- "Dual fan speed control required" basılmadı → `ec_read(0xB0/0xB1)` (`:846-852`) boş.
  (0.2.0'da değişti — bkz. "Sürücü 0.2.0'a yükseltme".)

### Çıktılar
- Upstream rapor: `Documentation/upstream/gigabyte-wmi-report.md` (issue #22 yorumu; §1
  ters-swap, §2 silent misdetect, §3 custom-fan ölü, §4 gpu_boost=3 eject).
- Manuel test planı: `Documentation/aerox16/test-plan.md`.

### Uygulanan local fix — sessiz mod misdetect'i (2026-07-11)
Probe `0xFA` yerine `0x57`'yi yoklayan yerel yama (`aorus-laptop-silent-0x57.patch`;
29 Tem'de `postPatch`'e, 16 Ağu'da upstream'e geçti). Reboot sonrası dmesg **"Newer model
detected"** ve srcversion `BE0D63F8…` → `1B107436…`. `0x57`'nin duyulur sessizlik yaratıp
yaratmadığı doğrulanmadı (AC + yük gerekli).

## Fixed mod DÜZELTMESİ — DADA30000 haklı çıktı (2026-07-11, E1-E6 matrisi)

Issue #22'de başka bir X16 1VH sahibi (DADA30000) §3'e itiraz etti ("mod 5 = max, custom
speed etkisiz"). Temiz-durum matrisi (idle 34-45°C, fanlar 0 RPM, pil; yamalı modül
canlı — srcversion 1B10..., "Newer model detected"; aorus numaraları):

| Deney | Sonuç |
|---|---|
| E1: cs=50 ÖNCE yaz → mod 5 | Duty 0→**100** → ~6900 RPM (max). FAN1 değeri OKUNMUYOR |
| E7: TAM TARAMA cs=10..100 (her değerde temiz 0→5 girişi) | HEPSİ aynı: ~6500-6900 RPM, FDTY 84-86. Değer↔RPM korelasyonu SIFIR |
| E8: E7 tekrarı, her değerde 20 sn / 2 sn'de 1 örnek | Desen HER cs için aynı: t=2s ~5900, t=4-6s tepe ~6900-7300, t=20s'ye kadar ~6250-6520'ye oturuyor. Tetikleyen sayı değil, "mod 5'e giriş" |
| E2: mod 5 içinde cs=25 | Max devam |
| E3: mod 5 → 0 çıkışı | Fanlar 0, bitler temiz |
| E4: TEMİZ mod 3 | Hiçbir şey — TENF tek başına etkisiz |
| E5: 3→5 geçişi | ADJF=1 → max ✔ |
| E6: TEMİZ mod 4 (cs=50) | **Fanlar 0!** (yük altında TEHLİKELİ) |

- **Rapor §3'ün "tracks the value" iddiası GERİ ÇEKİLDİ.** FDTY/GDTY telemetrisi max
  rampası sonrası ~20 sn'de 100→94→88→87 süzülüyor; §3'teki 229 (→6800) ve 90 (→6400)
  okumaları bu inişin farklı anlarıydı.
- "3/4/5 hepsi max" gözleminin sebebi sürücünün KİRLİ GEÇİŞLERİ: mod 5'teyken `echo 3` →
  `"Custom mode is already enabled"` erken dönüşü (aorus-laptop.c:357), ADJF=1 kalır;
  3→4 de ADJF'yi temizlemez.
- Net tablo (FB0A / EC 3.10): çalışan WMI fan kontrolleri = presetler (0x71 kesin duyulur,
  0x57 nominal) + "mod 5 = max üfleme". Watt/duty/eğri kontrolü yok.
- **Mod 4 (aorus numarası) hiçbir otomasyonda kullanılmamalı** (fan kapatma).

## EC iç RAM araştırması — ERCD komut kanalı KAPALI ÇIKTI (2026-07-11)

WMI'nin yazdığı her şey (ADJF, FAN1, XFNW, FLVL) yalnız eSPI paylaşımlı bellek aynası;
EC'nin fan karar döngüsü bunu okumuyor. DSDT'de EC iç RAM'ine giden ayrı kanal:
`ERCD` mailbox (`\_SB.PCI0.SBRG.EC0.ERCD`, dsdt.dsl:8485) — `ERRD(addr)` (opcode 0xB0,
okuma), `ERWT(addr,val)` (opcode 0xB1, yazma).

### Referans harita denendi — TUTMADI
nbfc `Gigabyte Aero16.json` + a15kb (ITE iç RAM reçetesi: `0x0D.7`=custom-on,
`0x06.4`=fixed-submode, `0x08.6`=eco-kapat, `0xB0`/`0xB1`=fan1/fan2 duty 0-229). Bizde bu
adresler **sıcaklık aynası**: `0xB0/0xB1/0xB4` idle/oyun/turbo'da 51→51→48-49. Intel-EC
haritası bu AMD/eSPI çipe taşınmıyor.

### Tam 256 bayt diff (idle/oyun/turbo) — 7 değişen bayt, hiçbiri "duty kontrolü" değil
Değişen adresler: `0x13,0x14,0x15,0x16,0x25,0x26,0x2C`. `0x25`/`0x26` FDTY/GDTY ile
(21→84, 24→85) neredeyse birebir örtüşüyor → EC çıktısının aynası, girdi değil.

### İzole yazma testleri — SONUÇ TUTARSIZ (kontrol edilebilir DEĞİL)
`0x2C`/`0x14`/`0x16` hedeflendi:
- **1. deneme (bileşik):** `0x2C=0x0C` idle RPM'i (2380/2654) turbo'ya (6500-7300)
  fırlattı, 10+ sn kendiliğinden düzelmedi; `fan_mode` 0→1 yazması baytları sıfırlamadı.
  Baytı `0x00`'a geri yazmak + mod 0 → temiz 18 sn idle ile tam kurtarma.
- **2. deneme (tek-değişkenli, değer=1):** turbo TETİKLEMEDİ (0x2C=1 RPM'i düşürdü;
  0x14/0x16 ihmal edilebilir). Temizlik sonrası `0x16` 0'da kalmadı, 7'ye kaydı — EC bu
  baytı kendi döngüsünde yazıyor.

Bu baytlar EC'nin telemetri/durum bayrakları; üstüne yazmak bazen etkisiz, bazen geçici
"maksimum soğutma" tepkisi (iyi huylu yön, termal risk yok) — **kontrol kanalı olarak
KULLANILAMAZ**. Test boyunca sıcaklık 44-48°C.

### Sonuç — ERCD/iç RAM yolu KAPALI, Faz 3 (entegrasyon) İPTAL
Generic peek/poke (0xB0/0xB1) GCC'nin fan arayüzü DEĞİL. DSDT'deki tek semantik ERCD
komutu CPU güç limitleri için (0x45/ECPT). GCC ya keşfedilmemiş bir ERCD opcode'u ya da
ERCD dışı bir yol (SMBus'taki ayrı fan kontrolcüsü, ESMC/SBAT — kapsam dışı) kullanıyor.
**NixOS'a fan-set aracı EKLENMEDİ.**

## Tam ACPI taraması — "BIOS'a özel mesajlar" hipotezi test edildi (2026-07-11)

DSDT + 33 SSDT (`iasl`/`acpixtract`) fan/thermal/GPU-power açısından tarandı.

### Bulgular
1. **`ThermalZone TZ01` (SSDT22, "THERMAL0")** yalnız pasif soğutma (`_PSL` → 24 çekirdek
   throttle listesi); `_AC0`-`_AC9` YOK — ACPI thermal yolu fanı kontrol etmiyor.
2. **`ERCD` çok-amaçlı dispatcher:** SSDT4 (USB-C/UCSI) **opcode 0x59** kullanıyor
   (0xB0/0xB1/0x45'e ek). Fan'a özel opcode hiçbir ACPI kodunda çağrılmıyor.
3. **NVIDIA'nın iki arayüzü:**
   - `PEGP.GPS` (`\_SB.PCI0.GPP9.PEGP.GPS`, SSDT9): `GPSP` buffer'ında `SFAN` (offset
     0x10) var ama hiçbir ASL kodu yazmıyor, sürekli 0. `PSH0=2` dalı PC00/PCI0 hatasını
     (`TGPU = \_SB.PC00.AMW0.LTGP`) içeriyor.
   - `NPCF._DSM` → `NPCF()` (Dynamic Boost, UUID `36b49710-2483-11e7-9598-0800200c9a66`):
     6 alt-fonksiyon (0-5), TGPA/TGPD/MAGA/MIGA/CUSL/CUCT — hepsi CPU/GPU watt; fan'la
     ilgisi yok.
4. **4. WMI GUID:** canlıda `ABBC0F6C/6F/72/75`. `_WDG` decode: `6C`→"AC"→`WQAC` (sabit 1
   döndüren taslak), `6F`→"BC"→`WMBC`, `75`→"BD"→`WMBD`, **`72`→Flags=Event**→
   `Notify(AMW0,0xD2)` kanalı. Gizli 5. sınıf yok.

### Sonuç
34 ACPI tablosunun tamamı tarandı. Fan eğrisi/duty mesajı ACPI'nin hiçbir yerinde yok:
GCC ya ERCD'ye ACPI-dışı bir opcode ile ya da ham SMBus/port I/O ile gidiyor. İkisi de
yalnız Windows trafik yakalamasıyla çözülür; Linux tarafında ACPI-görünür yol kalmadı.

## SSDT9 PC00→PCI0 düzeltmesi — initrd ACPI table upgrade (2026-07-12)

Modül: `system/arch/aerox16/acpi.nix`.

### Sorun (özet)
SSDT9 (`OptRf2`/`Opt2Tabl`, OemRev 0x1000, 13612 B) içindeki NVIDIA legacy GPS metodu
(`\_SB.PCI0.GPP9.PEGP.GPS`, PSHAREPARAMS/0x2A) `\_SB.PC00.AMW0.LTGP` okuyor — PC00 Intel
şablon artığı. Tam 2 geçiş (bayt ofsetleri **1305** = `External`, **8030** = `TGPU =
...LTGP`, PSH0=2 dalı). GPS LTGP'yi yalnız OKUR. dmesg imzası (o boot'ta 32 kayıt):
`ACPI Error: Aborting method \_SB.PCI0.GPP9.PEGP._DSM ... (AE_NOT_FOUND)` +
`NVRM: GPU0 pfmreqhndlrCallACPI: Unable to retrieve PFM_REQ_HNDLR_PSHAREPARAMS ... rc = 59`.
Sonuç: NVRM log spam + WMBD 0x4B (TGP, 75–87 W) işlevsiz.

### Faz A — configfs shim ile reboot'suz kanıt (2026-07-12, BAŞARILI)
`CONFIG_ACPI_CONFIGFS=m` ile küçük ek SSDT (`ZIXAR`/`Pc00Shim`: hayalet `\_SB.PC00.AMW0` +
`Name(LTGP, Zero)`; iasl 6141 için `_ADR` gerekti, `_HID` bilerek yok):
- `\_SB.PC00.AMW0.LTGP` → `0x0` (öncesi AE_NOT_FOUND)
- negatif kontrol `\_SB.PC00.AMW0.XXXX` → `AE_NOT_FOUND`
- **GPS uçtan uca**: `GPS 0 0x200 0x2A {0x02,0,0,0}` → `RETN=0x0102, VRV1=0x00010000,
  TGPU=0` — abort YOK. (GPS guard'ı yalnız `Arg1==0x0200`; PSH0 = Arg3'ün ilk 4 biti.)

configfs tablosu reboot'a kadar sökülemez (taint 'A'). Shim kalıcı çözüm değil (ayrı
`LTGP` kopyası, WMBD'nin yazdığı gerçek LTGP'yi göstermez).

### Kalıcı fix — binary patch + initrd upgrade
- **iasl recompile YOK**: 'PC00' AML'de 4-baytlık NameSeg → yerinde `'PC00'→'PCI0'` (×2) +
  checksum. Patcher: `system/arch/aerox16/acpi/patch-ssdt9.py` (boy/imza/OemId/OemTableId/
  geçiş-sayısı/OemRev guard'ları — biri tutmazsa build FAIL). Pristine dump:
  `system/arch/aerox16/acpi/ssdt9-pristine.dat` (sha256 `03b2207e...cb01dd`, modülde sabit;
  2026-07-11 dökümü = güncel firmware, cmp ile doğrulandı).
- **Kernel eşleşme kuralı** (drivers/acpi/tables.c): imza+OemId+OemTableId eşleşmeli
  **VE yeni OemRev KESİN büyük** (`existing >= new → skip`); eşit kalsa **duplicate**
  SSDT yüklenirdi (AE_ALREADY_EXISTS fırtınası) → OemRev 0x1000→**0x1001**. Checksum
  0xC4→**0x91**; bozuk checksum'lı initrd tablosu düşürülür (güvenli).
- **initrd**: sıkıştırmasız newc cpio (`kernel/firmware/acpi/ssdt9-pc00fix.aml`, bsdtar —
  nixpkgs microcode-amd deseni) `boot.initrd.prepend` ile; amd-ucode `mkOrder 1` ile önde
  (initrd'de microcode ofset 110 < acpi 307310). `Opt2Tabl` 33 SSDT içinde benzersiz.
- Çalışma zamanı ayak izi SIFIR → 4.28W idle tabanı korunur.

### Reboot sonrası doğrulama (Faz C — İLK BOOT'TA KOŞ)
1. `sudo dmesg | grep -i 'table upgrade'` → `override [SSDT-OptRf2-Opt2Tabl]`.
   **`install [SSDT-...]`** = duplicate yüklendi → önceki Limine generation'a dön.
   `Bad table checksum` da kabul edilemez. Microcode erken yükleme satırı durmalı.
2. İçerik: `sudo grep -la Opt2Tabl /sys/firmware/acpi/tables/SSDT*` → store'daki
   `ssdt9-pc00fix.aml` ile `cmp` (veya `xxd -l 28`: ofset 9 = 0x91, ofset 24 = `01 10 00 00`).
3. Spam: dGPU (0000:64:00.0) suspended iken 3× `nvidia-smi` ile uyandır →
   `journalctl -kb --grep 'PSHAREPARAMS|AE_NOT_FOUND'` boş. (D3cold döngüsü için
   `power/control` `auto` olmalı.)
4. 0x4B fonksiyonel test: `nvidia-powerd` durdur → `WMBD 0 0x4B 80` → `nvidia-smi -q -d
   POWER` → `0x4B 87` ile bitir (`NLIM=1` reboot'a kadar açık kalır) → powerd'yi başlat.

Rollback: önceki Limine generation'ı boot et; kalıcı kaldırma = configuration.nix'ten tek
import satırı.

### BIOS güncelleme politikası (staleness)
BIOS güncellemesinden sonra İLK iş `dmesg | grep -i 'table upgrade'`:
- `override` VARSA: BIOS SSDT9 içeriğini kimlikleri koruyarak değiştirdiyse 0x1001
  tablomuz yeni içeriği **maskeler** — ve sysfs artık BİZİM tabloyu gösterir, saf yeniden
  dump kendini kandırır → import'u kapat, temiz boot'ta dump al, diff'le.
- `install` / `AE_ALREADY_EXISTS` VARSA: kimlikler değişmiş, duplicate (tehlikesiz) →
  import'u kapat.
sha256 + patcher guard'ları sabitler yenilenmeden build'i zaten durdurur.

### Kazanç ve sonraki adım
NVRM log hijyeni + 0x4B TGP kanalı (75–87 W, `NLIM=1` + `Notify(PEGP,0xC0)` → sürücü
GPS/PSHAREPARAMS'tan okur). (`wmi.nix` notu, 31 Tem: 0x4B EC tarafından geri yazılıyor.)

## Sürücü 0.2.0'a yükseltme (2026-07-29) — UYGULANDI + DOĞRULANDI

aorus-laptop upstream `0.2.0` (tag `8bd8bef`, 2026-07-05); pin `912b4e9` (2026-06-08)
→ 25 commit. `master` (`fc2f217`) yalnız 2 paketleme commit'i ileride → tag pinlendi.

### Bizim 4 bulgumuzun durumu: HİÇBİRİ düzelmedi
(Issue #22 yorumumuz tag'den 6 gün sonra.) Sessiz mod probe'u aynı (`if (output < 0)`),
`convert_fan_rpm` hâlâ tüm ailelere, `gpu_boost=3` ve custom-fan ölülüğü dokunulmamış.

### Bizi ilgilendiren yenilikler
- **PWM düğümleri (salt-okuma)**: `FAN_PWM 0x50` (=`FDTY`), `GPU_FAN_DUTY 0x47` (=`GDTY`).
- Probe eğrinin 15 noktasını okuyor (0x68); bizde hep 0, ama WMBC 0x68'in `Sleep(100ms)`
  × 15 = **modül yüklenmesi ~1.5 sn uzuyor**.
- `light_sensor` yeni `0xFC` metodu; bizde `0xFC->0` → eski metoda düşüyor.
- Çift fan mantığı `CPU_FAN_DUTY 0x46` ile feature-detect; `FDTY` fan dururken 0 → bayrak
  boot anına göre değişebilir (pratik sonucu yok).
- DMI tablosuna `"AERO"` ve `"GIGABYTE GAMING"` eklendi; eşleşmemiz değişmedi.

### Kırıcı değişiklik (bizi etkilemiyor)
`fan_custom_speed` 25-100/5'in katı değil, ham **0-255**. Kullanmıyoruz.

### `patches` → `postPatch` geçişi (neden)
0.2.0'da `u8 result, result2;` → `u8 result;` oldu ve eski patch'in bağlamı bozuldu.
GNU patch varsayılan **fuzz=2** ile hunk'ı yine yapıştırıp sessizce "başarılı" olabilir;
`substituteInPlace --replace-fail` hedef kaybolunca build'i açık hatayla düşürür. Yamalar:
1. `FAN_SILENT_OLD` → `FAN_SILENT_MODE` + `if (output < 0)` → `if (ret == 0)`.
2. `convert_fan_rpm` gövdesi no-op (`return fan_rpm;`).

### Doğrulama sonuçları (2026-07-29 reboot sonrası)
| Kontrol | Sonuç |
|---|---|
| Build | ✅ Her iki `--replace-fail` hedefi bulundu |
| Modül canlı | ✅ `srcversion` `1B107436…` → **`922D3D6F…`**; `fan_pwm` düğümü belirdi |
| Probe bağlandı | ✅ Tüm sysfs düğümleri yerinde; `charge_limit=60`, `fan_mode=0` |
| Yama 1 (sessiz mod) | ✅ dmesg: `aorus_laptop: Newer model detected, using new silent fan mode ID` |
| Yama 2 (RPM swap) | ✅ `fan1_input=5555`, `fan2_input=5769` (boot rampası); swap sürseydi **45845** (0xB315). Fanlar durunca 0 |
| Yeni PWM kanalları | ✅ `pwm1`/`pwm2`/`fan_pwm` okunuyor; fan-stop'ta 0 |
| Işık sensörü | ✅ `Using old light sensor method` |
| Servisler | ✅ `gigabyte-power-profile` + `gigabyte-charge-limit` `status=0/SUCCESS` |

"Dual fan speed control required" artık basılıyor (yoklama `ec_read(0xB0/0xB1)` yerine
FDTY) — bayrak modül yüklenme anındaki fan durumuna bağlı, deterministik değil.

### Kabuk notu
Kullanıcının fish'inde `grep` → **ripgrep** alias'lı: `grep -i 'a\|b'` literal boru arar
→ sessiz yanlış negatif; `-E` rg'de `--encoding`. Komutları `rg -i 'a|b'` ile kullan.

## Sürücü master'a yükseltme (2026-08-16) — YEREL YAMALAR SİLİNDİ

**İki yamamız da upstream'e girdi.** Pin `8bd8bef` (0.2.0) → `8abb6655` (master, 8 Ağu).

### Diff'in tamamı (0.2.0 → master), üç değişiklik

| Commit | Ne | Bizim karşılığımız |
|---|---|---|
| `fdfa76a0` | `convert_fan_rpm` swap'ı DMI dalına `"GIGABYTE AERO"` eklenerek atlanıyor | Faz F §1 — önerdiğimiz biçimin birebir aynısı |
| `c0b0bd14` | Probe, DMI ailesi eşleşince 0xFA yoklamasını atlayıp `FAN_SILENT_MODE` (0x57) seçiyor (`goto obtain_fan_mode`) | Faz F §2 — farklı yol, aynı sonuç |
| — | `pr_*` string'lerine `\n` | kozmetik |

İkisi de `DMI_PRODUCT_FAMILY` tam string eşleşmesine bağlı; ölçüldü:

```
product_family: [GIGABYTE AERO]        ← iki dal da eşleşiyor
product_name:   [GIGABYTE AERO X16 1VH]
```

### Doğrulama (2026-08-16)
| Kontrol | Sonuç |
|---|---|
| `nixos-rebuild build` | ✅ `aorus-laptop-0.2.0-unstable-2026-08-08` derlendi |
| Derlenen `.ko` | ✅ `strings` → `"Skipping silent fan mode ID check…"` var; eski modülde yok |
| `srcversion` | `4B2AB85A3316A028911ED17` (önceki `922D3D6F…`) |

**`modprobe -r && modprobe` YETMEZ** (16 Ağu'da denendi, eski modül geri yüklendi):
`modprobe` `/run/booted-system/kernel-modules/…`'e bakar, `booted-system` reboot'a kadar
eski nesli gösterir. Ağaç-dışı modül güncellemesi yalnız reboot ile doğrulanır.
`fan1_input=0` tek başına arıza değil (EC fan-stop); 16 Ağu ölçümü: boşta ~1900 RPM,
10 sn tam yükte 3000 RPM.

İki `--replace-fail` hedefi master'da yok olduğu için `postPatch` silindi — bırakılsa build
açık hatayla düşerdi (tasarlanan davranış).

## Ortam ışığı sensörü (ALS) — AÇIK İŞ, 16 Ağu 2026

**Donanım VAR** ("AI Eyecare"; kullanıcı Windows'ta kullanmış). Linux'ta hiçbir kanaldan
çıkmıyor.

### Ölçülen dört kanal

| Kanal | Bulgu |
|---|---|
| `aorus_laptop/light_sensor` | WMI `0xF7` (eski metod). **Işıkta da kapalıyken de sabit `0`** (fenerle test) — ÖLÜ. `0xFC` (yeni metod) da 0 |
| AMD SFH | PCI cihazı var: `65:00.7 [1022:164a]`, `pcie_mp2_amd` bağlı, `amd_sfh` yüklü. Ama **hiç sensör enumere etmemiş** — IIO yok. `amd-pmf AMDI0107:00: No Smart PC policy present` |
| EC paylaşım penceresi | DSDT'de **`LUXM=0x18, LUXL=0x19, LUXH=0x1A`** (PECM içinde; `Offset(0x1B)` aritmetiği doğruluyor). Mutlak **`0xFC7E0818/19/1A`**. Hiçbir ACPI metodu okumuyor |
| ACPI ALS / IIO | `ACPI0008` yok, `/sys/bus/iio/devices/` boş, DSDT'de `_ALI`/`_ALR`/`ambient`/`illuminance` yok |

Klasik `ERAM` yalnız `0x5F`/`0x60` tanımlıyor — LUX orada değil, `ec_sys` ile okuma
garanti değil.

### Bekleyen deney: `scripts/als-probe.py` — YAZILDI, ÇALIŞTIRILMADI

`/dev/mem` üzerinden `0xFC7E0818`'i okur; self-check olarak aynı pencereden `RPM1/RPM2`'yi
hwmon `fanN_input` ile karşılaştırır. Çalıştırma: `sudo python3 scripts/als-probe.py` —
bir kez normal ışıkta, bir kez fenerle.

| Sonuç | Yorum | Sonraki adım |
|---|---|---|
| RPM tutuyor + LUX fenerle değişiyor | kanal canlı | okuyucu + histerezisli parlaklık eşlemesi (gerçek örnekleyici ister → idle bütçesi tasarımın merkezinde) |
| RPM tutuyor, LUX hep 0 | adres doğru, EC yazmıyor | `amd_sfh` neden sensör bulmuyor — upstream işi |
| ~~`/dev/mem` reddedildi~~ | ELENDİ (16 Ağu) | — |

> **Kısmi sonuç (16 Ağu 2026):** `/dev/mem` bu çekirdekte çalışıyor (PECM `dd` ile
> okundu); eşleme `0x8C`/`0x90` ↔ ACPI `TCLT`/`PPPT` ile doğrulandı. **`LUXM/LUXL/LUXH`
> döküm anında `00 00 00`** — ikinci satıra güçlü işaret, ama tek ışık koşulunda; iki
> koşullu koşu hâlâ gerekli.

**Hipotez:** "AI Eyecare" AMD PMF Smart PC politikası (OEM ikilisi, Linux'ta yok)
üzerinden çalışıyor; doğruysa sensör SFH'de ve çözüm `amd_sfh` tarafında.

## TCLT — termal setpoint: **DOĞRULANDI, ÖLÇÜLDÜ** (16 Ağu 2026)

### Sonuç — tek cümle

`\DPTT(0x03, N)` **çalışıyor**: AMD ALIB fonksiyon 0x0C (DPTC) üzerinden SMU'nun Tctl
hedefini `N` °C'ye çeker, makine o sıcaklıkta **sapmasız kilitlenir**, `95` geri yazılınca
serbest bırakır. Yazma EC'nin `TCLT@0x8C` baytına **dokunmaz**.

### Kanıtın imzası: varyansın sıfırlanması

Bağlayan setpoint'te Tctl **min = max**; bağlamayan kolda 0.3–0.9 °C gezinir.

| Kol | Örnek sayısı | Tctl min | Tctl max | Yorum |
|---|---|---|---|---|
| `N=70` (tavanlı rejim) | 30 | **70.0** | **70.0** | bağladı |
| `N=85` (tavansız rejim) | 40 | **85.0** | **85.0** | bağladı |
| `N=95` taban | 40 | 85.5 | 86.4 | bağlamadı (setpoint'in altında) |
| `N=90` | 40 | 87.0 | 87.5 | bağlamadı (setpoint'in altında) |

Yazılan = kilitlenen (70→70.0, 85→85.0): `Case(0x03)` çarpansız, birim °C. Aynı düz-kilit
`fan_mode 1`'in 95.0 °C'sinde görülmüştü — **aynı denetleyici**.

### Yöntem

Yük hiç durmadan sürerken setpoint koşu içinde kademelendi (ayrı koşularda ortam/termal
birikim setpoint etkisini taklit eder).
- Yük: 16 thread AVX-512 FMA (8 bağımsız akümülatör, sıfır syscall).
- 2 Hz; her basamağın son 15–20 s'i kararlı pencere.
- Tctl `k10temp/temp1_input`, paket gücü `amdgpu/power1_input` (µW), saat
  `cpu0/scaling_cur_freq`, fan `aorus_laptop/fan1_input`.
- Betik: `scripts/tclt-probe.sh` (`capped` / `uncapped`). CSV: `/tmp/tclt-probe/{capped,uncapped}.csv`.
- AC=1, `fan_mode=1` sabit.

`scaling_cur_freq` bu sürücüde gerçek ölçüm — `cpuinfo_avg_freq` ile ~20 MHz içinde.

### Kanıt 1 — tavanlı rejim: setpoint 70

4.5 GHz tavanıyla makine ~72 °C'de oturuyor (termal duvara varmıyor):

| Basamak | Tctl | PPT | Saat | Fan |
|---|---|---|---|---|
| taban (95) | 71.78 °C | 34.52 W | 4480 MHz | 1993 rpm |
| **→ 70** | **70.00 °C** | **30.05 W** | **4482 MHz** | 2079 rpm |
| → 95 (geri) | 75.67 °C | 35.05 W | 4481 MHz | 2072 rpm |

t=40'ta yazım, 72.5 °C'den ~6 s'de 70.0'a; **44 s sapmasız**; t=90'da 95 yazılınca 73.9'a
tırmanıyor. Tam tersinir.

**Saat düşmüyor, yalnız güç (−13 %)**: frekans 4.5 GHz'e çivili ve V/f eğrisinin düz
kısmında; SMU gücü voltaj/kaçak üzerinden kırpıyor. `fan_mode 1`'in 95 °C kilidinde
(tavansız, 4840 MHz, eğrinin dik kısmı) hem güç hem saat düşüyordu (51→45 W, 4840→4742
MHz) — aynı eğrinin iki noktası, çelişki yok.

### Kanıt 2 + takas — tavansız rejim (tavan geçici kaldırıldı)

Tavansız rejim = oyun rejimi (`game-perf` tavanı kaldırır).

| Setpoint | Tctl | PPT | Saat | Fan | Bağladı mı? |
|---|---|---|---|---|---|
| N=95 (taban) | 85.86 °C | 45.02 W | 4928 MHz | 2365 rpm | ❌ hayır |
| N=90 | 87.23 °C | 44.16 W | 4918 MHz | 2367 rpm | ❌ hayır |
| **N=85** | **85.00 °C** | **41.05 W** | **4876 MHz** | 2369 rpm | ✅ **evet** |
| N=95 (kontrol) | 88.51 °C | 44.11 W | 4911 MHz | 2369 rpm | ❌ hayır |

> **Bu üç ayrı ölçüm noktası DEĞİL.** `N=95`/`N=90`'da makine setpoint'in altında kaldı;
> o satırlar yalnız termal birikimi gösterir. **Gerçek veri tek noktadır: `N=85`.**

`N=85` ↔ `N=90` (bağlamayan = fiilen sınırsız):

| Büyüklük | Ham fark (85 ↔ 90) | Sürüklenme düzeltmeli |
|---|---|---|
| Tctl | **−2.23 °C** | −2.89 °C |
| Saat | −42 MHz (**−0.85 %**) | −38 MHz (−0.78 %) |
| PPT | −3.11 W | −3.08 W |

Düzeltme: bağlamayan kollar monoton ısınıyor (85.86 → 87.23 → 88.51 °C); `N=85`'in
karşı-olgusu interpolasyonla ~87.9 °C. İnterpolasyondur, ölçüm değil — ham sütun esas.

**Cevap:** ölçülen tek noktada **~2.2–2.9 °C serinlik ≈ %0.8 saat** (ve ~3 W).
**Fan hiç değişmedi** (2365→2369 rpm): soğuma tamamen SMU güç kırpmasından — fan
ölçümündeki "fan sıcaklığı düşürmez, performansa çevirir" bulgusunun simetriği.

### Mekanizma — yazım EC'ye değil, doğrudan SMU'ya gidiyor

Her iki koşuda, istisnasız: `EC TCLT@0x8C` = **95** (`/dev/mem`), `gpe0A` deltası = **0**
(hiç `_Q20` tetiklenmedi). `\DPTT` `_Q20 → DPTT → ALIB(0x0C)` zincirini atlayıp doğrudan
SMU'ya yazıyor; EC bir sonraki `_Q20`'de kendi 95'ini yeniden göndermeli. Ölçüm geçerli,
ama kalıcılık yokluğu doğrulanmadı.

### Kapsam

- **Normal masaüstünde ETKİSİZ:** AC'deki 4.5 GHz tavanıyla 16 thread AVX-512'de bile
  **73.5 °C / 36 W**; bağlaması için performansı boşuna kesen bir değer gerekir.
- **Değeri yalnız tavanın kalktığı oyun rejiminde.**

### Sınırlar — ölçülmeyenler (ekstrapolasyon YOK)

1. **`N=95` ve `N=90` sınanmadı** (bağlamadılar); gerçek oyun yükünde davranış bilinmiyor.
2. **İş yükü hafif:** 16 thread AVX-512 tavansız yalnız **85.86 °C / 45 W**; önceden **4
   thread düz tamsayı LCG, tavansız → 4850 MHz, 58 W, 99 °C sürekli** ölçülmüştü
   (sebep hipotez: SMT + Zen5c yayılımı, AVX-512 frekans/güç davranışı). Oyun yükünde
   ölçülmedi.
3. **Kalıcılık doğrulanmadı** (`_Q20` ateşlemedi).
4. **Yalnız aşağı yön.** `N > 95` denenmedi ve denenmemeli.
5. **dGPU dahil değil.**

Sonraki adım (yapılırsa): ≥95 °C'ye çıkaran **tamsayı** yük ya da gerçek oyun.

### Metodoloji notu — örnekleme ekseni kayar, sonu buna göre kırp

Betiğin zaman ekseni nominal (0.5 s × indeks); tavansız koşuda gerçek süre ~%6 fazla,
220 s'lik yük nominal t≈197.3'te bitti. İlk rapordaki son kol saati **4502 MHz**, 180–200
penceresine düşen 5 yük-sonrası boşta örnekten (623 MHz) geliyordu. Yük-canlı pencereyle
(177–197) kol **88.51 °C / 44.11 W / 4911 MHz** (tabloda düzeltilmiş değer). Pencereyi
gerçek geçen süreye bağla ya da yükün canlı olduğunu örnek başına doğrula.
