# CPU — hibrit Zen5/Zen5c çekirdek politikası

**Bulgu (16 Ağu 2026): çekirdek zamanlayıcı bu CPU'nun hibrit olduğunu BİLİYOR.**
`amd_hfi` bağlı, ITMT açık, çekirdek öncelikleri HFI'den dolmuş, workload
classification aktif — tek-thread'lik iş **bilerek** Zen5'e gidiyor.
`system/kernel/cores.nix`'in Zen5c maskesi bu yüzden "kör kernel'e protez" değil,
**çalışan bir ITMT'yi güç bütçesi adına bilinçli olarak ezmek**tir.

> 10 Ağu 2026 tarihli önceki bulgu ("zamanlayıcı hibrit farkında değil") YANLIŞTI —
> bkz. "Neden üç tur yanlış ölçtük".

---

## Donanım: AMD Ryzen AI 7 350 "Krackan Point"

family 26 (0x1A), 8 çekirdek / 16 thread, hibrit Zen5 + Zen5c.

| Sınıf | CPU listesi (mantıksal) | `cpuinfo_max_freq` |
|---|---|---|
| Zen5 ("büyük") | `0,2,4,6` + SMT `8,10,12,14` | **5090910 kHz** (~5.09 GHz) |
| Zen5c ("verimlilik") | `1,3,5,7` + SMT `9,11,13,15` | **3506494 kHz** (~3.51 GHz) |

`amd_pstate_prefcore_ranking`: Zen5 196/202/208, Zen5c hepsi 135. `4,6,12,14`
(en yüksek rütbeli 4'ü) `gamerun`'ın `GR_PIN=fast` listesiyle birebir örtüşüyor.

## Kanıt: zamanlayıcı hibrit-farkında (ölçüm 16 Ağu 2026, kernel 7.1.7)

ITMT arayüzü **`/proc/sys/` altında değil, debugfs'te** (root gerekir):

```
sudo ls   /sys/kernel/debug/x86/
sudo cat  /sys/kernel/debug/x86/sched_itmt_enabled
sudo cat  /sys/kernel/debug/x86/sched_core_priority
sudo cat  /sys/kernel/debug/x86/amd_hfi/class_capabilities
```

| Kontrol | Değer | Anlamı |
|---|---|---|
| `/sys/kernel/debug/x86/sched_itmt_enabled` | **`Y`** | ITMT AÇIK |
| `/sys/kernel/debug/x86/sched_core_priority` | Zen5 196/203, Zen5c 135 | öncelik tablosu DOLU |
| `/sys/kernel/debug/x86/amd_hfi/class_capabilities` | 3 sınıf × 16 CPU | workload classification AKTİF |
| `/sys/bus/platform/drivers/amd_hfi/AMDI0104:00` | **symlink var** | sürücü cihaza BAĞLI |
| `ACPI` tabloları | `SSDT ... AMD Hetero` mevcut | firmware hibrit topolojiyi beyan ediyor |
| `amd_pstate/prefcore` | `disabled` | **kasıtlı** — HFI'li tasarımlarda upstream böyle yapar (aşağıda) |
| `cpuN/cpu_capacity` | 16 CPU'da `1024` | **ilgisiz** — ITMT capacity üzerinden çalışmaz |

### ITMT öncelik tablosu (`sched_core_priority`)

| Çekirdek | CPU'lar | ITMT önceliği |
|---|---|---|
| Zen5 (yüksek rütbe) | `4,6` + SMT `12,14` | **203** |
| Zen5 (düşük rütbe) | `0,2` + SMT `8,10` | **196** |
| Zen5c | `1,3,5,7` + SMT `9,11,13,15` | **135** |

`4,6,12,14` hem CPPC'de hem HFI'de en üstte — `GR_PIN=fast` bağımsız doğrulandı.

**Dikkat: iki firmware sıralaması birbirini tutmuyor.** CPPC
(`amd_pstate_prefcore_ranking`) Zen5'te `196/202/208`, HFI (ITMT) `196/203` diyor;
yön aynı, mutlak değerler farklı. ITMT'yi besleyen HFI'dir (`ipcc_scores[0]` = WLC 0
Perf sütunu).

### Workload classification (`class_capabilities`)

| CPU sınıfı | WLC | Perf | Eff |
|---|---|---|---|
| Zen5 | 0 | 196 / 203 | 141 |
| Zen5 | 1 | **58** | 141 |
| Zen5 | 2 | **58** | 141 |
| Zen5c | 0 | 135 | **255** |
| Zen5c | 1 | **135** | **255** |
| Zen5c | 2 | **135** | **255** |

WLC 0'da Zen5 önde; **WLC 1 ve 2'de tablo tersine dönüyor** (Zen5 Perf 58, Zen5c 135,
Eff 255 vs 141) — o sınıflar için donanımın kendisi Zen5c'yi öneriyor, yani maskenin
yönü bazı iş tiplerinde HFI ile örtüşüyor.

## Sonuç zinciri (neden "bazen 5GHz'e zıplıyor" hissi doğru)

1. ITMT açık, Zen5 203'e karşı Zen5c 135 — tek-thread iş tercihen Zen5'e gidiyor.
2. `power-display.nix` AC'de her `ACAD` olayında `scaling_max_freq`'i yeniden açıyor
   + boost'u açıyor (power-saver'ın 2GHz kilidini geri almak için).
3. EPP `balance_performance` (PPD `balanced`) — talep gelince klok hızla yükseliyor.
4. Sonuç: kısa bir tek-thread patlaması bile Zen5'i tavana götürüyor. Tasarım gereği,
   arıza değil.

## Neden üç tur yanlış ölçtük (16 Ağu 2026)

Üç "kanıt" satırı var olmayan yollara bakıyordu; "dosya yok" "özellik kapalı" diye
okundu:

| Yanlış kontrol | Neden yanlış |
|---|---|
| `/proc/sys/kernel/sched_itmt_enabled` yok → "ITMT hiç oluşmamış" | Bu yol **kaldırıldı**; `itmt.c` artık `register_sysctl()` değil `debugfs_create_file_unsafe(…, arch_debugfs_dir, …)` ile `/sys/kernel/debug/x86/` altına yazıyor |
| `/sys/bus/platform/devices/amd_hfi/driver` yok → "sürücü bağlanmamış" | **Yanlış düğüm.** `amd_hfi_init()` bir stub `amd_hfi` platform cihazı yaratır; sürücü ACPI'nin `AMDI0104:00`'ine bağlanır. Stub'ın sürücüsüz olması beklenen |
| `cpuN/cpu_capacity` = 1024 → "EEVDF hepsini eşit sanıyor" | **İlgisiz ölçü.** ITMT `sched_core_priority` + `SD_ASYM_PACKING` ile çalışır; `cpu_capacity` x86'da sabit 1024 |
| `prefcore = disabled` → "global anahtar kapalı" | **Kasıtlı.** Upstream: *"cpufreq/amd-pstate: Disable preferred cores on designs with workload classification"*. `disabled` + `amd_hfi` bağlı = beklenen |

`amd_hfi` başarı yolunda log basmıyor (yalnız `pr_debug`) ve bu makinede
`quiet loglevel=0` var — `dmesg`'de iz aramak boşa.

## Politika: `system/kernel/cores.nix` (10 Ağu 2026, gerekçe 16 Ağu'da düzeltildi)

Kernel hızlı çekirdeği tercih ediyor; bu idle güç bütçesiyle çelişiyor. Maske:

```
systemd.settings.Manager.CPUAffinity = "1,3,5,7,9,11,13,15";   # yalnız Zen5c
systemd.services.nix-daemon.serviceConfig.CPUAffinity = "0-15"; # derleme muaf
```

- **Mekanizma:** PID1'in `CPUAffinity`'si fork/exec ile tüm alt süreçlere miras
  kalır — masaüstü Zen5c'de kalır, Zen5'ler talep gelmeyince C-state'e düşer.
- **YUMUŞAK maske:** `sched_setaffinity`, cgroup `AllowedCPUs` DEĞİL — `taskset` ile
  delinebilir. `AllowedCPUs` bilinçli seçilmedi: `gamerun`'ın oyunu 16 CPU'ya açmasını
  imkânsız kılardı.
- **Delme yolları:**
  - Oyun: `gamerun` varsayılan `taskset -c 0-15` (`lib/gamerun.nix`);
    `GR_PIN=big`/`fast`/özel liste ile daha dar pinleme.
  - Kaçış alias'ı: fish `aia` (`home/shell/fish.nix`) → `taskset -c 0-15` öneki.
  - Derleme: `nix-daemon.service` muaf.
- **Kapatma:** `CPUAffinity` satırını yorum yap + rebuild. Yetmez:
  `power-display.nix`'in pil kolu ACAD olayında PID1 + mevcut süreçleri yine Zen5c'ye
  süpürüyor (AC kolu 0-15'e açıyor) — orayı da düzenle.

## Enerji ölçümü: maskenin gerekçesi ilk kez ölçüldü (16 Ağu 2026)

**Yöntem.** Sabit tek-thread iş (60M iterasyonluk tamsayı LCG, python3), `taskset`
ile cpu0 (Zen5) ve cpu1 (Zen5c). Güç: `amdgpu` hwmon `power1_input` = **APU paket
PPT'si**, µW, 20 Hz (RAPL `energy_uj` root-only). Her koşunun öncesi ve sonrası idle
tabanı ortalaması çıkarıldı → marjinal güç. Kollar alternatiflendi, 5 tur, medyan.

| | Zen5 (cpu0) | Zen5c (cpu1) | Fark |
|---|---|---|---|
| Frekans | 4.92 GHz | 3.47 GHz | |
| Süre (medyan) | **5.51 s** | 8.19 s | Zen5 **1.49× hızlı** |
| Marjinal güç | ~12.3 W | ~4.9 W | Zen5 **2.5× çeker** |
| **Enerji (medyan)** | **69.1 J** | **39.5 J** | **Zen5c %43 az** |

**Sonuç (AC):** race-to-idle bu silikonda kazanmıyor — 1.49× hız için 1.75× enerji.

Fişte 30 J fark maliyet değil, ödenen tek şey 1.49× gecikme. Bu yüzden maske 16 Ağu
2026'da fişe bağlandı — `power-display.nix`'in udev-ACAD oneshot'ı (AC → `0-15`,
BAT → Zen5c). PID1'in `CPUAffinity`'si çalışırken değiştirilemediği için mevcut
süreçler `taskset -a -p` ile süpürülür; kernel thread'ler (`cmdline` boş) ve
`nix-daemon` atlanır, `game-perf.service` aktifken süpürme yapılmaz.

> **%43 PİLDE GEÇERLİ DEĞİL (16 Ağu 2026, aynı gün ölçüldü).** Pilde PPD power-saver
> iki çekirdek tipini de 2.0 GHz'e kapıyor; iso-frekansta **Zen5c'nin enerji avantajı
> YOK** — 14 eşleştirilmiş turun 14'ünde Zen5c daha fazla harcadı, medyan **×1.10**.
> %43'ün tamamı V/f etkisi. Maske pilde yine duruyor çünkü **bedava** (frekans zaten
> eşit) ve fişte kalkan mekanizmanın pil kolu; pilde enerjiyi kazandıran PPD'nin
> 2.0 GHz tavanı.

### Pilde iso-frekans ölçümü: Zen5 vs Zen5c, ikisi de 2.0 GHz (16 Ağu 2026)

**Koşullar.** `ACAD/online` = 0 (koşu boyunca da örneklendi), `cpu0`/`cpu1`
`scaling_max_freq` = 2000000, PID1 maskesi Zen5c'de, `fan_mode` = 1 ve dört fan 0 RPM,
başlangıç Tctl 35 °C, `loadavg` ~0.8.

**Yöntem.** AC ölçümüyle aynı iş ve güç kaynağı (**hwmon numarası boot'lar arası sabit
değil, ADLA bul**). Öncesi/sonrası 5 s taban; kollar alternatifli, 5'er tur, medyan;
örnekleyici `cpu3`'e sabit.

**İlk iki parti artefakt.** 2 s beklemeyle alınan koşu-sonrası taban Zen5c kolunda
**+0.251 W** yüksekti (Zen5'te +0.007 W): maskeli masaüstünün cpu1'de biriken işi koşu
biter bitmez boşalıp "taban" sayılıyordu ve sahte bir Zen5c üstünlüğü üretti. 6 s
beklemede asimetri kayboldu (+0.009 W) ve **işaret ters döndü**:

| Parti | Bekleme | Kol sırası | Zen5c/Zen5 enerji (kol medyanlarının oranı) |
|---|---|---|---|
| 1 | 2 s | Zen5 önce | ×0.99 — *artefakt* |
| 2 | 2 s | Zen5 önce | ×0.92 — *artefakt* |
| 3 | 6 s | Zen5 önce | ×1.12 |
| 4 | 6 s | **Zen5c önce** (sıra kontrolü) | ×1.07 |
| 5 | 6 s | cpu0'a yapay yük (yarışma kontrolü) | ×1.09 |

**Ana tablo** — 6 s bekleme, parti 3+4, 10 eşleştirilmiş tur, medyan:

| | Zen5 (cpu0) | Zen5c (cpu1) | Fark |
|---|---|---|---|
| Frekans (koşu medyanı) | 1.998 GHz | 1.996 GHz | iso — fark yok |
| Süre | 13.50 s | 13.78 s | Zen5c %2 yavaş |
| Taban (öncesi+sonrası ort.) | 4.078 W | 4.074 W | aynı |
| Koşu penceresi mutlak güç | 5.008 W | 5.044 W | +0.036 W |
| Marjinal güç | 0.896 W | 0.974 W | Zen5c %12 fazla |
| **Enerji** | **12.1 J** | **13.4 J** | eşleştirilmiş medyan **×1.141**, 10/10 tur |

**Yarışma kontrolü (parti 5).** Boşta meşguliyet: cpu0 **%0.47**, cpu1 **%6.2** (tüm
Zen5c'ler %4.9–10.4). cpu0'a %6.4 duty-cycle yük konunca Zen5 süresi 13.50 → **13.95 s**,
süre farkı sıfırlandı (×1.00) — %2 silikon değil yarışmaymış. Marjinal güç farkı
**kaldı**: 0.939 W'a karşı **1.037 W**, enerji ×1.07 (4/4 tur).

**Sonuç.** İso-frekansta Zen5c daha verimli değil: 14/14 tur, medyan ×1.10, en iyi tur
×1.046. Mutlak fark küçük (5.01 vs 5.04 W paket); %10, 4.08 W tabanın çıkarılmasından
büyüyor.

**Ölçümün sınırları:**

- Sensör/arka plan gürültüsü ±0.02–0.05 W → partiler arası ×1.07–×1.14; işaret 14/14
  tutarlı ama **büyüklüğü ±3 puandan hassas okuma**.
- Tek iş yükü: tamsayı, L1'e sığan, SIMD/bellek baskısı yok — bellek/AVX ağırlıklı iş
  **ölçülmedi**.
- `power1_input` APU paket PPT'sidir: 4.08 W taban ile `power.md`'deki 4.28 W sistem
  idle rakamı **aynı şeyi ölçmüyor**.
- Yalnız 2.0 GHz için geçerli; PPD power-saver tavanı değişirse tekrarla.
- Tek thread, SMT kardeşleri boş; çok-threadli iş ölçülmedi.

**Ölçülen semptom (aynı gün):** Electron/Deezer fişte 3.47 GHz'de kalıyor, oyun
açıkken 2.44 GHz'e düşüyordu — CPU paketi (32 W PPT) ile dGPU (44 W) ~80 W'lık
paylaşımlı ACBT bütçesini bölüşüyor. Deezer: 7 süreç, 1140 MB, %33 CPU (zen-beta:
%4.7 / 551 MB).

### Denenip elenen alternatif: `scx_lavd --cpu-pref-order`

```
scx_lavd --autopower --cpu-pref-order "1,3,5,7,9,11,13,15,0,2,4,6,8,10,12,14"
```

Maskesiz görevlerde 1 hafif görev **%100 Zen5**'e gitti. Sebep: tercih sırası yalnız
core compaction açıkken (`balanced`/`powersave`) kullanılıyor; `--autopower` fişte EPP
`balance_performance`'ı okuyup `performance` seçiyor → liste yok sayılıyor.
`--balanced`/`--powersave` sabitlemek `--autopower`'ın AC/BAT takibini öldürürdü.

## Frekans tavanı taraması: V/f eğrisinin dizi nerede (16 Ağu 2026)

Maske AC'de kalkınca Zen5 5.09 GHz'e çıkıp "kısa patlamada 80-90°C" sıçraması yapıyor.

**Yöntem.** Aynı 60M iterasyon işi, `taskset -c 0`. Tavan tüm policy'lere yazıldı;
kollar arası Tctl ≤ 50°C'ye soğutma; 10 Hz Tctl + PPT, taban koşu öncesi 2 sn.

| Tavan | Süre | Tepe Tctl | Marjinal güç | Enerji | Hızın % | Watt'ın % |
|---|---|---|---|---|---|---|
| 3.51 GHz *(maskeli davranış)* | 7.81 s | 55.8 °C | 4.3 W | 33.7 J | — | — |
| 4.00 GHz | 6.94 s | 58.9 °C | 5.2 W | 36.0 J | 37 | **9** |
| 4.20 GHz | 6.60 s | 60.8 °C | 6.5 W | 42.9 J | 52 | 21 |
| **4.50 GHz** | **6.06 s** | **64.2 °C** | **7.5 W** | 45.6 J | **75** | **31** |
| 5.09 GHz *(tavansız)* | 5.49 s | **80.1 °C** | 14.7 W | 80.5 J | 100 | 100 |

Son iki sütun: 3.51 → 5.09 arasındaki toplam kazancın/maliyetin yakalanan oranı.

| Aralık | mW / MHz |
|---|---|
| 3.51 → 4.00 | 1.9 |
| 4.20 → 4.50 | 3.3 |
| **4.50 → 5.09** | **15.6** |

Son 590 MHz: %9 hız için güç %96, enerji %77, tepe sıcaklık **+15.9 °C** artıyor.

**Karar:** AC'de `scaling_max_freq` 4.5 GHz'e kapandı (`power-display.nix`; `game-perf`
aktifken tavan yok, oyun bitince geri konuyor). Masaüstü 3.51 → 4.50 GHz (%29 hızlı),
80°C sıçraması 64.2°C'ye iniyor. Zen5c'nin tavanı (3506494) zaten CAP'in altında.

## 2026-08-27 — power-saver'da scaling_max_freq SMT asimetrisi

PPD `power-saver`'da `cpu0-7` = 623377 (= `cpuinfo_min_freq`), `cpu8-15` = 2000000.
Bir kez "regresyon" diye raporlandı — **değil**: SMT eşleri, çekirdek iki thread'in
tavanının yükseğinde koşuyor (`cpu6`'da max=623377 iken `scaling_cur_freq`=1997798).
Efektif tavan 2.0 GHz; asimetri kozmetik.

## İzlenecek riskler (switch sonrası)

- **PipeWire xrun / ses çıtırtısı** — pipewire `user@.service` altında maskeli; RT
  thread'ler 8 mantıksal Zen5c'de yarışıyor. Çözüm: `pipewire.service`'e
  `CPUAffinity=0-15` muafiyeti.
- **Compositor tepkiselliği** — compositor 165Hz'de Zen5c'de koşuyor (bilinçli,
  muafiyet yok). Takılma gözlenirse ilk bakılacak yer.
- **Boot/login süresi** — systemd de maskeli; birkaç yüz ms olası, ölçülmedi.

## Yeniden değerlendirme koşulu

Maske bir politika tercihi, kernel eksiği protezi değil: *fişte hızlı çekirdeği
kullan*, *pilde kullanma* (pilde bedava olduğu için duruyor, kazandırdığı için değil).
Ancak güç bütçesi değişirse gözden geçir, kernel sürümü değişirse değil.

Kernel yükseltmesi sonrası yine de bakılacaklar:

- `sudo cat /sys/kernel/debug/x86/sched_itmt_enabled` — `Y` kalıyor mu
- `sudo cat /sys/kernel/debug/x86/sched_core_priority` — `GR_PIN=fast` (`4,6,12,14`)
  hâlâ doğru mu
- `sudo cat /sys/kernel/debug/x86/amd_hfi/class_capabilities` — WLC 1/2'de Zen5c
  üstünlüğü sürüyor mu

**ITMT'yi kapatmak seçenek değil:** `sched_itmt_enabled=0` yalnız sıralamayı kapatır,
işin Zen5'e düşmesini engellemez ("Zen5c'yi tercih et" modu yok); debugfs olduğu için
kalıcı da değil.

## İlgili

- Idle güç bütçesi (4.28W): `Documentation/aerox16/power.md`.
- Oyun sırasında maskeyi delme + fan turbo zinciri: `Documentation/gaming.md`.
- CPU undervolt/Curve Optimizer (ayrı alt sistem — platform kilidi):
  `Documentation/aerox16/undervolt.md`.
