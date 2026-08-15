# CPU — hibrit Zen5/Zen5c çekirdek politikası

**Bulgu (16 Ağu 2026): çekirdek zamanlayıcı bu CPU'nun hibrit olduğunu BİLİYOR.**
`amd_hfi` sürücüsü bağlı, ITMT açık (`sched_itmt_enabled = Y`), çekirdek öncelikleri
HFI'nin sıralama tablosundan dolmuş, workload classification aktif. Zamanlayıcı
tek-thread'lik işi **bilerek** Zen5'e yolluyor — yazı-tura değil, tasarım.
`system/kernel/cores.nix`'in Zen5c maskesi bu yüzden "kör kernel'e protez" değil,
**çalışan bir ITMT'yi güç bütçesi adına bilinçli olarak ezmek**tir. Karar geçerli;
gerekçesi değişti.

> **10 Ağu 2026 tarihli önceki bulgu ("zamanlayıcı hibrit farkında değil") YANLIŞTI.**
> Silinmedi, aşağıda "Neden üç tur yanlış ölçtük" başlığında duruyor — çünkü hatanın
> kendisi tekrarlanabilir cinsten: kaldırılmış/taşınmış sysfs yollarına bakıp
> "yok" sonucunu "kapalı" diye okuduk. Dördüncü kez düşmemek için kayıtta.

---

## Donanım: AMD Ryzen AI 7 350 "Krackan Point"

`lscpu` + `model name`: family 26 (0x1A), 8 çekirdek / 16 thread, hibrit Zen5 + Zen5c.

| Sınıf | CPU listesi (mantıksal) | `cpuinfo_max_freq` |
|---|---|---|
| Zen5 ("büyük") | `0,2,4,6` + SMT `8,10,12,14` | **5090910 kHz** (~5.09 GHz) |
| Zen5c ("verimlilik") | `1,3,5,7` + SMT `9,11,13,15` | **3506494 kHz** (~3.51 GHz) |

`amd_pstate_prefcore_ranking` (firmware'in kendi sıralaması, yüksek=hızlı):
Zen5 çekirdekleri 196/202/208, Zen5c çekirdekleri hepsi 135. `4,6,12,14` (Zen5'in
en yüksek rütbeli 4'ü) `gamerun`'ın `GR_PIN=fast` listesiyle birebir örtüşüyor.

## Kanıt: zamanlayıcı hibrit-farkında (ölçüm 16 Ağu 2026, kernel 7.1.7)

ITMT arayüzü **`/proc/sys/` altında değil, debugfs'te** — okumak için root gerekir:

```
sudo ls   /sys/kernel/debug/x86/
sudo cat  /sys/kernel/debug/x86/sched_itmt_enabled
sudo cat  /sys/kernel/debug/x86/sched_core_priority
sudo cat  /sys/kernel/debug/x86/amd_hfi/class_capabilities
```

| Kontrol | Değer | Anlamı |
|---|---|---|
| `/sys/kernel/debug/x86/sched_itmt_enabled` | **`Y`** | ITMT AÇIK — zamanlayıcı çekirdek önceliğini kullanıyor |
| `/sys/kernel/debug/x86/sched_core_priority` | Zen5 196/203, Zen5c 135 | öncelik tablosu DOLU |
| `/sys/kernel/debug/x86/amd_hfi/class_capabilities` | 3 sınıf × 16 CPU | workload classification AKTİF |
| `/sys/bus/platform/drivers/amd_hfi/AMDI0104:00` | **symlink var** | sürücü cihaza BAĞLI (`probe()` 0 döndü) |
| `ACPI` tabloları | `SSDT ... AMD Hetero` mevcut | firmware hibrit topolojiyi beyan ediyor |
| `amd_pstate/prefcore` | `disabled` | **kasıtlı** — HFI'li tasarımlarda upstream böyle yapar (aşağıda) |
| `cpuN/cpu_capacity` | 16 CPU'da `1024` | **ilgisiz** — ITMT capacity üzerinden çalışmaz (aşağıda) |

### ITMT öncelik tablosu (`sched_core_priority`)

| Çekirdek | CPU'lar | ITMT önceliği |
|---|---|---|
| Zen5 (yüksek rütbe) | `4,6` + SMT `12,14` | **203** |
| Zen5 (düşük rütbe) | `0,2` + SMT `8,10` | **196** |
| Zen5c | `1,3,5,7` + SMT `9,11,13,15` | **135** |

`4,6,12,14`'ün en yüksek çıkması `gamerun`'ın `GR_PIN=fast` listesini bağımsız olarak
doğruluyor — hem CPPC hem HFI aynı dörtlüyü işaret ediyor.

**Dikkat: iki ayrı firmware sıralaması var ve birbirini tutmuyor.**
`amd_pstate_prefcore_ranking` (CPPC kaynaklı) Zen5'te `196/202/208` derken,
ITMT önceliği (HFI kaynaklı) `196/203` diyor. Sıralamanın *yönü* ikisinde de aynı
(Zen5 > Zen5c), ama mutlak değerler farklı — bir sayı gördüğünde hangi kaynaktan
geldiğine bak. ITMT'yi besleyen HFI'dir (`ipcc_scores[0]` = WLC 0'ın Perf sütunu).

### Workload classification (`class_capabilities`) — asıl sürpriz

Donanım her CPU için **3 iş sınıfı** (WLC 0/1/2) başına ayrı Perf ve Eff puanı veriyor:

| CPU sınıfı | WLC | Perf | Eff |
|---|---|---|---|
| Zen5 | 0 | 196 / 203 | 141 |
| Zen5 | 1 | **58** | 141 |
| Zen5 | 2 | **58** | 141 |
| Zen5c | 0 | 135 | **255** |
| Zen5c | 1 | **135** | **255** |
| Zen5c | 2 | **135** | **255** |

WLC 0'da (genel iş) Zen5 açık ara önde. Ama **WLC 1 ve 2'de tablo tersine dönüyor**:
Zen5'in performans puanı 58'e çöküyor, Zen5c 135'te kalıyor — yani bu iki sınıf için
donanımın kendisi *"bu işi Zen5c'de yap"* diyor, üstelik verimlilik puanı da orada
tavan (255 vs 141). Bu, `cores.nix`'in Zen5c tercihinin en azından bazı iş tipleri
için donanım tarafından da onaylandığı anlamına geliyor — maske kaba, HFI ince, ama
yönleri belirli sınıflarda örtüşüyor.

## Sonuç zinciri (neden "bazen 5GHz'e zıplıyor" hissi doğru)

Semptom gerçek, ama mekanizma 10 Ağu'da yazıldığı gibi değil:

1. ITMT açık ve Zen5'in önceliği 203'e karşı Zen5c'nin 135'i — zamanlayıcı
   tek-thread'lik işi **yazı-tura değil, tercihen** Zen5'e koyuyor. Maske olmasa
   bir tarayıcı sekmesi ya da compositor repaint'i sistematik olarak hızlı çekirdeğe
   giderdi.
2. `system/kernel/power-display.nix` AC'de her `ACAD` olayında tüm CPU'ların
   `scaling_max_freq`'ini `cpuinfo_max_freq`'e (Zen5'te 5090910) geri açıyor + boost'u
   açıyor (power-saver'ın 2GHz kilidini geri almak için — bkz. o dosyadaki yorum).
3. EPP `balance_performance` (PPD `balanced`) — talep gelince klok hızla yükseliyor.
4. Sonuç: iş Zen5'e düştüğünde, kısa bir tek-thread patlaması bile o çekirdeği
   5GHz tavanına götürüyor. **Zorlayan bir "işlem" yok — zamanlayıcı hızlı çekirdeği
   bilerek seçiyor, donanım izin veriyor.** Tasarım gereği böyle, arıza değil.

## Neden üç tur yanlış ölçtük (16 Ağu 2026)

Üç ayrı "kanıt" satırı da var olmayan yollara bakıyordu; "dosya yok" sonucu
"özellik kapalı" diye okundu. Gerçekte:

| Yanlış kontrol | Neden yanlış |
|---|---|
| `/proc/sys/kernel/sched_itmt_enabled` yok → "ITMT hiç oluşmamış" | Bu yol **kaldırıldı**. `arch/x86/kernel/itmt.c`'de `sched_set_itmt_support()` artık `register_sysctl()` çağırmıyor; `debugfs_create_file_unsafe("sched_itmt_enabled", …, arch_debugfs_dir, …)` ile `/sys/kernel/debug/x86/` altına yazıyor |
| `/sys/bus/platform/devices/amd_hfi/driver` yok → "sürücü bağlanmamış" | **Yanlış düğüm.** `amd_hfi_init()` önce `platform_device_register_simple("amd_hfi", …)` ile bir stub cihaz yaratır; sürücü ona değil, ACPI'nin numaralandırdığı `AMDI0104:00`'e bağlanır (`.acpi_match_table`). Stub'ın sürücüsüz olması normal ve beklenen |
| `cpuN/cpu_capacity` = 1024 → "EEVDF hepsini eşit sanıyor" | **İlgisiz ölçü.** ITMT `cpu_capacity` üzerinden değil, per-CPU `sched_core_priority` + `SD_ASYM_PACKING` üzerinden çalışır. `cpu_capacity` asimetrik-kapasite/EAS mekanizmasına ait, x86'da zaten 1024 sabit |
| `prefcore = disabled` → "global anahtar kapalı" | **Kasıtlı.** Upstream yaması: *"cpufreq/amd-pstate: Disable preferred cores on designs with workload classification"* — HFI olan tasarımlarda sıralamayı HFI'nin vermesi tercih edildiği için amd-pstate prefcore'u bilerek kapatır. `disabled` + `amd_hfi` bağlı = beklenen durum |

Ayrıca `amd_hfi` başarı yolunda **hiçbir log satırı basmıyor** (yalnız `pr_debug`),
üstelik bu makinede `quiet loglevel=0` var — `dmesg`'de iz aramak da boşa çıkar.

**Ders:** bir sysfs/procfs yolunun yokluğu, özelliğin kapalı olduğunun kanıtı değildir.
Yol taşınmış, yeniden adlandırılmış veya hiç var olmamış olabilir. Bir arayüzün
gerçekten yok olduğunu iddia etmeden önce **o sürümün kaynağından** doğrula.

## Politika: `system/kernel/cores.nix` (10 Ağu 2026, gerekçe 16 Ağu'da düzeltildi)

Kernel kararını **veriyor** — ama verdiği karar (hızlı çekirdeği tercih et) idle güç
bütçesiyle çelişiyor. Maske o kararı ezmek için:

```
systemd.settings.Manager.CPUAffinity = "1,3,5,7,9,11,13,15";   # yalnız Zen5c
systemd.services.nix-daemon.serviceConfig.CPUAffinity = "0-15"; # derleme muaf
```

- **Mekanizma:** systemd PID1'in `CPUAffinity`'si `sched_setaffinity` ile ayarlanır ve
  fork/exec zinciriyle tüm alt süreçlere miras kalır — masaüstü, tarayıcı, compositor
  dahil her şey fiziksel olarak Zen5c'de kalır. Zen5'ler talep gelmeyince C-state'e
  düşer, 5GHz o çekirdeklerde yapısal olarak imkânsız hale gelir.
- **YUMUŞAK maske:** bu `sched_setaffinity`, cgroup `AllowedCPUs` DEĞİL — `taskset`
  ile her zaman geri açılabilir. `AllowedCPUs` bilinçli seçilmedi: cgroup düzeyinde
  kısıtlama çocuk süreçlerin `taskset` ile bile kaçmasını engeller, `gamerun`'ın oyunu
  16 CPU'ya açması imkânsız olurdu.
- **Delme yolları:**
  - Oyun: `gamerun` varsayılan olarak `taskset -c 0-15` ile başlatır (`lib/gamerun.nix`);
    `GR_PIN=big`/`fast`/özel liste ile Zen5'e daha dar pinleme de yapılabilir.
  - Kaçış alias'ı: fish `aia` (`home/shell/fish.nix`) → `taskset -c 0-15` öneki.
  - Derleme: `nix-daemon.service` muaf (`cores.nix`'in kendisinde).
- **Kapatma:** `CPUAffinity` satırını yorum satırı yap + rebuild.

## İzlenecek riskler (switch sonrası)

- **PipeWire xrun / ses çıtırtısı** — pipewire `user@.service` altında, o da maskeli;
  RT thread'ler 8 mantıksal Zen5c'de yarışıyor. Şüpheli buysa çözüm
  `pipewire.service`'e `CPUAffinity=0-15` muafiyeti eklemek.
- **Compositor tepkiselliği** — Hyprland/Caelestia 165Hz'de Zen5c'de koşuyor
  (bilinçli — compositor'a muafiyet verilmedi). Takılma gözlenirse ilk gözden
  geçirilecek nokta burası.
- **Boot/login süresi** — systemd de maskeli; birkaç yüz ms yavaşlama olası, ölçülmedi.

## Yeniden değerlendirme koşulu

Önceki sürümdeki koşul ("kernel bir gün `amd_hfi`'yi bağlarsa maskeyi gözden geçir")
**zaten gerçekleşmiş durumda** — bağlı, ITMT açık. Yani maske artık "kernel eksiğini
kapatan geçici protez" değil, kalıcı bir politika tercihi: *hızlı çekirdeği kullanma,
çünkü 4.28 W idle tabanı 5 GHz'lik kısa patlamaları kaldırmıyor.* Bu tercihi ancak
güç bütçesi değişirse gözden geçir, kernel sürümü değişirse değil.

Kernel yükseltmesi sonrası yine de bakılacaklar:

- `sudo cat /sys/kernel/debug/x86/sched_itmt_enabled` — `Y` kalıyor mu
- `sudo cat /sys/kernel/debug/x86/sched_core_priority` — sıralama bozulduysa
  `gamerun`'ın `GR_PIN=fast` listesi (`4,6,12,14`) hâlâ doğru mu
- `sudo cat /sys/kernel/debug/x86/amd_hfi/class_capabilities` — WLC 1/2'de Zen5c
  üstünlüğü sürüyor mu (sürüyorsa maskenin donanım onayı da devam ediyor demektir)

**ITMT'yi kapatmak bir seçenek değil:** `sched_itmt_enabled`'a `0` yazmak yalnız
öncelik sıralamasını devre dışı bırakır, işin Zen5'e düşmesini engellemez (yerleşim
keyfîleşir, "Zen5c'yi tercih et" diye bir mod yok). Üstelik debugfs olduğu için
kalıcı değil. İstenen davranışı veren tek araç maskenin kendisi.

## İlgili

- Idle güç bütçesi (4.28W) ve gaming kısıtları: `CLAUDE.md` güç yönetimi bölümü,
  `Documentation/aerox16/power.md`.
- Oyun sırasında maskeyi delme + fan turbo zinciri: `Documentation/gaming.md`.
- CPU undervolt/Curve Optimizer (ayrı, ilgisiz alt sistem — platform kilidi):
  `Documentation/aerox16/undervolt.md`.
