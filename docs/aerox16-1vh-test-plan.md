# AERO X16 1VH — güvenli manuel test planı (sürücü bulgu doğrulama)

Amaç: `docs/upstream-gigabyte-wmi-report.md` (issue #22 yorumu) yayınlanmadan önce,
pinlenen sürücü kaynağıyla (`912b4e9`) **çelişen** iki iddiayı canlı makinede
doğrulamak: (1) RPM byte-swap zaten `convert_fan_rpm` ile düzeltilmiş mi, (2) sürücü bu
şasiyi "Older model" sanıp `fan_mode 1` (sessiz) yolunu boş WMBD `0xFA` case'ine mi
bağlıyor. Kaynak analizi: `aorus-laptop.c` (`…/scratchpad/gigabyte-laptop-wmi/`) ve
`~/dsdt.dsl`. Ölçüm geçmişi: `docs/aerox16-1vh-wmi.md` "Canlı test sonuçları".

**Güvenlik kuralı:** Part 1 **salt-okuma**. `dmesg`/`cat`/`sensors` saf okuma;
`echo <id> > debug_method` yalnızca bir sonraki `cat debug_method` için hangi **WMBC
(Get)** metodunun çalışacağını *seçer* — WMBC hiçbir EC durumunu yazmaz
(`docs/aerox16-1vh-wmi.md`: "debug_method = serbest WMBC okuma kapısı"). Bu fazda
`fan_mode`/eğri/şarj **yazımı YOK**. Part 2 (yazma) ancak Part 1 sonrası, tek register,
her adımda gözlenebilir etki + revert ile.

---

## Part 1 — Salt-okuma doğrulama  (BUNU ÇALIŞTIR, ÇIKTIYI YAPIŞTIR)

```bash
P=/sys/devices/platform/aorus_laptop

echo "== 0) Çalışan modül pinlenen 912b4e9 build'i mi? =="
sudo modinfo aorus-laptop 2>/dev/null | grep -E 'filename|version|srcversion'

echo "== 1) Tespit dalları: hangi model algılandı? ışık sensörü? dual-fan? =="
sudo dmesg | grep -iE 'aorus|model detected|light sensor|dual fan|invalid'

echo "== 2) hwmon: RPM/temp değerleri makul mü (byte-swap uygulanmış mı)? =="
sensors 2>/dev/null | grep -iE 'fan|temp|adapter|aorus'
for f in "$P"/hwmon/hwmon*/fan*_input "$P"/hwmon/hwmon*/temp*_input; do
  [ -e "$f" ] && printf '%s = %s\n' "${f##*/hwmon*/}" "$(cat "$f")"
done

echo "== 3) Ham WMBC okuma (debug_method = salt Get): RPM/temp ham değerleri =="
for id in 0xE4 0xE5 0xE1 0xE2; do
  sudo sh -c "echo $id > $P/debug_method"; printf '%s -> ' "$id"; cat "$P/debug_method"
done

echo "== 4) Tespit selector'ü: X16 WMBC 0xFA / 0xFC / 0x57 ne döndürüyor? =="
for id in 0xFA 0xFC 0x57; do
  sudo sh -c "echo $id > $P/debug_method"; printf '%s -> ' "$id"; cat "$P/debug_method"
done

echo "== 5) Mevcut fan modu tabanı =="
cat "$P/fan_mode" "$P/fan_custom_speed" 2>/dev/null
```

### Sonuç — ÖLÇÜLDÜ (2026-07-11), her iki iddia da netleşti

Part 1 canlı çıktısı (`docs/aerox16-1vh-wmi.md`'ye de işlenecek):

| Gözlem (ölçülen) | Anlamı / raporu nasıl kilitledi |
|---|---|
| dmesg **"Older model detected, using old ID"** ✔ | `fan_modes[1]=0xFA` → `fan_mode 1` boş WMBD `Case(0xFA)` (`dsdt.dsl:9105`) yazıyor = **sessiz mod ölü**. Rapor §2 (silent no-op) **onaylandı**. |
| WMBC `0xFA -> 0`, `0xFC -> 0`, `0x57 -> 1` ✔ | X16 WMBC'de `Case(0xFA)`/`Case(0xFC)` YOK → **0 döndürüyor** (uninitialized değil, deterministik 0). Sürücünün `if (output < 0)` kontrolü 0'ı "eski cihaz" sanıyor (`aorus-laptop.c:779-790`). Mekanik kanıt. Doğru selector `0x57` okunuyor (→1). |
| Raw WMBC `0xE4 -> 2970` (0x0B9A), `0xE5 -> 3333` (0x0D05) **ama** hwmon `fan1_input=39435` (0x9A0B), `fan2_input=1293` (0x050D) ✔ | EC değeri **zaten doğru sırada** veriyor; sürücünün `convert_fan_rpm` (`rol16 8 = swab16`) çağrısı onu BOZUYOR (`39435=swab16(2970)`). Rapor §1: bug GERÇEK ama **ters** — swap eklenmeli değil, **kaldırılmalı** (`GIGABYTE AERO` no-swap dalına). |
| `fan3_input`/`fan4_input` = 0; `temp3_input` = 0 ✔ | Yalnız 2 tach var; `temp3` = `ec_read(0x62)` port-EC (bu eSPI EC'de boş → 0). Rapor §1/§5 dipnotu. |
| `temp1_input=95000` (raw `0xE1=95`), `temp2_input=67000` (raw `0xE2=67`) | Sıcaklıklar swap edilmiyor (`output*1000`), doğru. |

---

## Part 2 — Korumalı yazma testleri  (Part 1'den SONRA, tek tek)

Ortam: AC + sabit yük (örn. `stress-ng --cpu 4` veya bir oyun), sıcaklık 50-65 °C
bandında (sessiz↔normal farkının ölçülebildiği bant — `docs/aerox16-1vh-wmi.md` preset
karakterizasyonu). Her adım: **önkoşul → komut → beklenen gözlem → revert**.

### 2a. Sessiz mod gerçekten çalışıyor mu? (0xFA vs 0x57)
Sürücünün `fan_mode 1`'i (misdetect → WMBD `0xFA`, boş) ile ham WMBD `0x57`'yi
karşılaştır; FDTY/GDTY duty'yi `debug_method` ile izle.

```bash
P=/sys/devices/platform/aorus_laptop
base() { for id in 0x46 0x47; do sudo sh -c "echo $id > $P/debug_method"; \
         printf '%s -> ' "$id"; cat "$P/debug_method"; done; }

# önkoşul: normal mod, taban duty
sudo sh -c "echo 0 > $P/fan_mode"; sleep 30; echo "[normal]"; base

# A) sürücü sessiz (misdetect'te 0xFA=no-op olması beklenir)
sudo sh -c "echo 1 > $P/fan_mode"; sleep 45; echo "[fan_mode 1]"; base

# B) ham 0x57 (gerçek CRAF sessiz komutu)
sudo sh -c "echo '\\_SB.PCI0.AMW0.WMBD 0 0x57 1' > /proc/acpi/call; cat /proc/acpi/call"
sleep 45; echo "[raw 0x57]"; base
```
- **Beklenen:** `fan_mode 1` sonrası FDTY/GDTY = normal ile aynı (no-op doğrulaması);
  ham `0x57` sonrası 50-60 °C bandında duty birkaç puan düşer (CRAF sessiz tablosu).
- **Revert:** `sudo sh -c "echo 0 > $P/fan_mode"` (normal moda dön; CRAF'ı EC kendisi
  temizler — `docs/aerox16-1vh-wmi.md` mod-mekanizması notu).

**SONUÇ — register seviyesi ÖLÇÜLDÜ (2026-07-11, pil / 34 °C idle,
`scratchpad/fan-bits.sh`):** her yolda EC durum bitleri okundu.

| Yol | CRAF `0x57` | FANB `0x71` | TENF `0x67` | ADJF `0x6A` | FDTY/GDTY |
|---|---|---|---|---|---|
| normal (0) | 1 | 0 | 0 | 0 | 0/0 |
| sürücü sessiz (1 → `0xFA`) | 1 | 0 | 0 | 0 | 0/0 |
| ham `WMBD 0x57` arg1 | 1 | 0 | 0 | 0 | 0/0 |
| gaming (2 → `0x71`) | 1 | **1** | 0 | 0 | 0/0 |

- **`fan_mode 1` normal ile bit-bit AYNI** → boş `0xFA` no-op kesinleşti (§2). ✔
- **gaming yalnız `FANB`'yi çeviren yol** → `0x71` çalışıyor. ✔
- **`CRAF` EC'ce 1'e kilitli** (ham `0x57` bile oynatmıyor) → sessiz modun gerçek
  fan etkisi ancak Part 2a-thermal (AC + yük, aşağıda) ile görülebilir. FDTY/GDTY=0
  çünkü idle/fan-stop.
- **Thermal ölçüm — DENENDI, NULL (2026-07-11, pil, `scratchpad/thermal-test.sh`):**
  16× `yes` yükü pilde çekirdeği ısıtamadı — temp **44 °C'de platoya oturdu**, tüm test
  boyunca tepe **49 °C**. Fan-stop eşiği ~48-54 °C olduğundan **hiçbir modda fan dönmedi**
  (normal/`0x57`/gaming hepsinde FDTY=GDTY=RPM=0) → `0x57` fan etkisi ÖLÇÜLEMEDİ.
  Sebep: pil SPL ~15-20W kilidi. **Ölçmek için AC gerekli** (yüksek SPL) ya da CPU+GPU
  ortak yük. Rapordaki "0x57 fan etkisi ayrı/firmware-bağımlı soru" ifadesi geçerli kalıyor;
  register seviyesi (§2 silent no-op) zaten kanıtlı.

### 2b. gpu_boost — **3 YAZMA (dGPU EJECT)**
> ⛔ **`echo 3 > gpu_boost` YAPMA.** Bu DSDT'de WMBD `0x51` arg 3 =
> `Notify (^^GPP9.PEGP, 0x03) // Eject Request` (`dsdt.dsl:9396`) → dGPU'yu
> ACPI'den çıkarma isteği. `gpu_boost 2` = no-op (case yok), `gpu_boost 1` = `ACBT=LCBT`
> ama Linux'ta LCBT=0 → etkisiz. Dinamik boost için doğru yol zaten çalışan servisin
> ham `WMBD 0x4C` yazımı (`modules/hardware/gigabyte-wmi.nix`).
- Test edilecek tek şey: **hiçbir şey**. Bu kutu sadece "sakın" içindir.

### 2c. dGPU boost bütçesi (ACBT) — salt cross-check
Zaten `gigabyte-power-profile.service` AC'de `WMBD 0x4C 10` (80W) yazıyor. Doğrula:
```bash
nvidia-smi -q -d POWER | grep -iE 'current power limit|max power limit'
```
- **Beklenen:** AC'de tavan 75W'a kadar (boşta ~60W). Yazma yok, salt okuma.
- Revert: yok (durum servisçe yönetiliyor; pilde 0'a döner).

---

## Kanıt referansları (rapor için)
- `aorus-laptop.c:178-182` `convert_fan_rpm` (`rol16(v,8)`), `:249-252` aile guard'ı.
- `aorus-laptop.c:779-790` tespit (uninit `output`, `fan_modes[1]` ataması), `:760`
  `GIGABYTE AERO` DMI kaydı.
- `aorus-laptop.c:541-563` `gpu_boost_store` (mode≤3 clamp, WMBD `0x51`'e geçiş).
- `aorus-laptop.c:234` `ec_read(0x62)` mobo temp, `:812` `ec_read(0xD)`, `:846-852`
  `ec_read(0xB0/0xB1)` dual-fan — hepsi port-EC (bu eSPI EC'de boş).
- `dsdt.dsl:9105-9107` WMBD `0xFA` boş case; `:9375-9396` WMBD `0x51` (eject);
  WMBC `9525-9720` (`0xFA` case yok, `Default` yok).
