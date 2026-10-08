# Güç — idle bütçesinin ölçüm defteri

**4.28 W temiz idle tabanı bu repodaki sert kısıttır** (bkz.
`system/kernel/sched.nix` başındaki tasarım notu). Bu dosya o sayının nereden
geldiğini tutar.

Ölçüm yöntemi: firmware `power_now` bildirmiyor, watt'ı elle hesapla —
`current_now × voltage_now / 1e12`, kaynak `/sys/class/power_supply/BAT1/`.
Ham dökümleri `scripts/power-audit.sh` üretir (çıktı dizini gitignore'da).

---

## 2026-07-02 — IPS force testi + temiz taban

Tüm ölçümler: pilde, 60Hz, %40 parlaklık, boost=0, EPP=power, temiz idle
(120s sakinleşme + 6×10s örnek).

## Sonuçlar

| Konfigürasyon | Ortalama | Not |
|---|---|---|
| IPS force (0x4000) aktif | **7.25–7.75 W** | REGRESYON — rcg=0, idle workqueue kapalı; charge_now deltasıyla doğrulandı (7.62W) |
| IPS force revert + dpm=low | **4.28 W** | temiz taban |
| dpm=auto | 4.36 W | fark gürültü (±0.08W) → `low` kaldı |
| SMT off | ~4.21 W (5 örnek) | kazanç ~0.06W ≈ gürültü → SMT açık kaldı |

## IPS force olayı (neden revert edildi)

- `amdgpu.dcdebugmask=0x4000` (DC_FORCE_IPS_ENABLE) IPS1/IPS2 sayaçlarını
  çalıştırdı AMA RCG'yi (önceden 721 giriş) ve idle workqueue'yu tamamen kapattı.
  Net etki: +3.3W. Krackan'da config=6 (RCG aktif + IPS2 ekran-kapalıda) zaten optimal.
- IPS aktifken `amdgpu_gfxoff_status` debugfs okuması display controller'ı
  kilitledi (flip_done timeout, VT değişimi dahil); `amdgpu_gpu_recover` ile
  kurtarıldı, param revert edildi (commit 29f630b). IPS force altında bu dosyayı
  ASLA OKUMA.

## Doğrulanan kalıcı kazançlar

- Pille boot → 60Hz + %40 parlaklık + blur/gölge/animasyon kapalı (boot+oturum servisleri)
- CPU boost off, 2GHz tavan, iGPU dpm low, platform low-power, webcam hard-off
- aorus-laptop (gigabyte-laptop-wmi; 7 Eyl 2026'da `aero_eg61h` ile değişti): fan
  idle'da 0 RPM (doğrulandı), CPU 34°C, şarj limiti %80, fan_mode EC default silent
- amdxdna blacklist, workqueue.power_efficient, pcie_port_pm=force, ABM4

## Kalan tüketimin dağılımı (tahmini, 4.28W)

Panel+backlight %40 ~1.2-1.5W · SoC idle ~1.5-2W · WiFi (rtw89 PS on) ~0.3-0.5W
· NVMe APST ~0.2-0.4W · RAM/EC/misc ~0.5W · dGPU D3cold ~0.05W

## Denenmedi / gelecek fikirler

- Panel 48Hz destekliyor (EDID V-range 48–165); PSR yüzünden beklenen kazanç küçük,
  VRR denenirse PSR etkileşimine dikkat.
- Pil: 73.8 Wh → 4.28W'ta ~17.2 saat idle.

---

## 2026-07-18 — TLP → power-profiles-daemon

TLP kaldırıldı, güç profilini PPD yönetiyor (`system/kernel/power.nix`). **Neden:**
TLP governor/EPP/`platform_profile`'i kendi başına yazıyordu ve `amd_pstate=active`
altında bu, amd-pstate'in kendi yönetimiyle kavga ediyordu (AMD/Limonciello uyarısı).

TLP'nin öbür işleri: cihaz autosuspend'i → `powertop --auto-tune` (boot) + kernel
ASPM parametreleri + EC; parlaklık/webcam/tazeleme hızı ve **fişe göre PPD profil
seçimi** → `system/kernel/power-display.nix` (PPD AC/BAT'a göre kendiliğinden
profil değiştirmiyor).

---

## 2026-08-16 — powertop ezmesi (girdi cihazları + writeback)

`powertop --auto-tune` her boot'ta `systemd-sysctl`'den ve udev'in ilk turundan
**sonra** koşuyor ve iki ayarımızı eziyor (ölçüldü):

```
vm.dirty_writeback_centisecs : 6000 -> 1500   (sysctl 20:58:22, powertop 20:58:25)
USB power/control            : on   -> auto   (yalnız yeniden enumere olmayan
                                                dahili klavyeye kalıcı zarar)
```

**Dahili klavye (GIGABYTE `0414:8104`)** boot'ta tek sefer (20:58:17) enumere
oluyor; powertop sonra koştuğu için udev'in `on`'u `auto`'ya eziliyor ve cihaz
askıya düşüyor (tuş girişinde gecikme). Ölçüm: uptime'ın **%96,2**'si askıda
(`runtime_suspended_time` 14.029.429 / uptime 14.586.850 ms). Reboot aynı sırayı
tekrarladığı için çözüm değil.

**Eski yorumdaki yanlış iddia** ("fare ve klavye-2 `USB_QUIRK_NO_AUTOSUSPEND`
listesinde"): böyle bir liste yok (v7.1 `quirks.c`'de 258a/22d4/0414 geçmiyor).
O iki cihaz powertop'tan **sonra** yeniden enumere oldukları için (20:58:38,
20:58:39) kazara `on` kalıyordu.

**Uygulanan.** `power-tunables-restore.service` (`power.nix`) powertop'tan sonra
writeback'i ve üç girdi cihazının `power/control`'ünü geri yazıyor; udev kuralı
hotplug için kalıyor. İlk sürüm `multi-user.target`'a asılıydı, sıralama döngüsüne
girip sessizce hiç koşmadı (ölçüldü: 1500/auto kaldı) → `graphical.target`'a
taşındı (aynı tuzak `power-display.nix`'te anlatılıyor).

---

## 2026-08-24 — Hibernate neden kapatıldı (oyunda tam kilitlenmenin kökü)

**Belirti.** Oyun sırasında tam kilitlenme: görüntü donuk, girdi/TTY yok, güç
tuşuna kısa basış kapatmıyor; tek çıkış basılı tutmak.

**Kök neden.** `suspend-then-hibernate`'in hibernate ayağı amdgpu'nun TTM
defterini bozuyor; bozulma saatler sonra, GPU yükü altında patlıyor.

Zincir (24 Ağu, boot -1; 19 Ağu boot -6'da birebir aynısı):

```
23:24  kapak kapandı → suspend entry (s2idle)
23:49  +25 dk RTC alarmı → hibernate ayağı
       PM: hibernation: Allocated 11347244 kbytes
       amdgpu_pmops_freeze → amdgpu_device_evict_resources
         → ttm_device_prepare_hibernation → ttm_bo_swapout
         → ttm_lru_walk_for_evict → ttm_bo_swapout_cb → ttm_resource_alloc
         → WARNING drivers/gpu/drm/ttm/ttm_resource.c:235
            (ttm_resource_add_bulk_move)                    ← 11 kez
       ACPI: PM: Preparing to enter system sleep state S4
       ACPI: PM: Waking up from system sleep state S4        ← imaj YAZILMADAN
       PM: hibernation: hibernation exit
13:30  kapak açıldı — sistem bozuk TTM listeleriyle çalışmaya devam ediyor
17:08  Dark Souls III başladı
17:09  list_del corruption. next->prev should be ... but was ...
       kernel BUG at lib/list_debug.c:65
       Oops: invalid opcode — Comm: .swayosd-server
         ttm_resource_move_to_lru_tail → amdgpu_gem_create_ioctl
       note: .swayosd-server[1849] exited with preempt_count 1
17:09  rcu: INFO: rcu_preempt self-detected stall on CPU 3
       Comm: Hyprland:cs0
         native_queued_spin_lock_slowpath → ttm_resource_manager_usage
         → amdgpu_cs_parser_bos → amdgpu_cs_ioctl
17:09  Power key pressed short. Powering off...   (kapanış hiç ilerlemedi)
```

**Neden *tamamen* kilitleniyor.** `list_del` `BUG()` attığında görev TTM LRU
spinlock'unu **tutarken** ölüyor (`exited with preempt_count 1`); kilit bir daha
bırakılmıyor, amdgpu'ya dokunan her şey sonsuza kadar dönüyor. `.swayosd-server`
kurban, suçlu değil — zehirli listeye ilk dokunan sık GEM çağıranı.

**Neden logda "çökme" görünmedi.** `nowatchdog nmi_watchdog=0` (idle bütçesi
ayarları) lockup dedektörlerini kapatıyor → panik, reboot, crash dump yok. Kanıt
yalnız journald ilk oops satırlarını diske yetiştirdiği için kaldı.

**Bağıntı (25 boot, 29 Tem – 24 Ağu).**

| Boot | s2h denemesi | TTM WARN | Sonuç |
|---|---|---|---|
| -8 (16 Ağu) | var | 0 | NULL pointer deref |
| -6 (19 Ağu) | var (3) | 10 | list_del BUG → kilitlenme |
| -1 (24 Ağu) | var (2) | 11 | list_del BUG → kilitlenme |
| -12,-11,-10,-7,-5,-4,-3,-2,0 | **yok** | 0 | temiz |

Çöken 3 boot'un 3'ünde hibernate denemesi var; denenmemiş 9 boot'ta sıfır çökme.
TTM WARN gören 2 boot'un 2'si çöktü — WARN saatler önceden uyarır:
`journalctl -kb | grep ttm_resource_add_bulk_move`.

**Kaybedilen yok: hibernate hiç çalışmamıştı.** Hiçbir boot'ta imaj yazma logu ya
da `Resuming from` yok; her açılışta `systemd-hibernate-resume: Unable to resume
from device ... continuing boot process`; boot ID'ler uykular boyunca kesintisiz.
25 dakikalık RTC alarmı da her uykuda makineyi boşuna uyandırıyordu; o da gitti.

**Uygulanan.** `system/kernel/power.nix`:
`HandleLidSwitch`/`HandleLidSwitchExternalPower`/`HandleSuspendKey` → `suspend`,
artı `nohibernate` kernel parametresi. İkincisi şart: handler'lar tek başına
`HandleHibernateKey`'i ve masaüstü menülerinin `suspendThenHibernate` çağrısını
kapatmıyor; `nohibernate` ile `CanHibernate` "na" dönüyor ve o yollar düz
suspend'e düşüyor.

**Geri açma koşulu.** Kernel'i güncelle, elle bir `systemctl hibernate` dene,
sonra ikisi birden tutmalı: `journalctl -kb | grep ttm_resource_add_bulk_move`
BOŞ, ve `journalctl -b | grep 'Resuming from'` bir satır. Biri eksikse açma.

## 2026-08-24 — USB uyandırma kapatıldı (iki klavye)

"Uykudayken bazen USB cihazları uyandırıyor" şikâyeti: journal'da 25 boot boyunca
**kendiliğinden uyanma bulunamadı** — her `PM: suspend exit`'in karşılığı kapak,
güç tuşu ya da 25 dk'lık RTC alarmıydı (gözlemin bir kısmı büyük olasılıkla o alarm).

Yetenek denetimi yine de uyandırma izni olan iki USB cihazı gösterdi:

| Cihaz | ID | Tür | Önce | Sonra |
|---|---|---|---|---|
| BY Tech Gaming Keyboard | `258a:0049` | removable (harici) | enabled | **disabled** |
| GIGABYTE USB-HID Keyboard | `0414:8104` | fixed (dahili Fn/RGB HID) | enabled | **disabled** |
| Glorious Model I (fare) | `22d4:1503` | removable | disabled | (dokunulmadı) |
| Bluetooth Radio | `0bda:0852` | fixed | disabled | (dokunulmadı) |

Fare ve Bluetooth çekirdek varsayılanıyla zaten kapalı; ölçülmemiş davranışa kural
yazılmadı. Uyandırmaya devam edenler: kapak (`PNP0C0D`), güç tuşu (`PNP0C0C`) ve
dahili AT klavye (`serio0`/i8042) — "tuşa basınca uyanma" korundu.

**Neden hem udev'de hem `power-tunables-restore`'da.** powertop ikilisinde
`usb_wakeup` tunable'ı var. Ölçüm: klavyeler 17:10:51'de enumere oldu, powertop
17:10:57–59'da koştu, sonrasında ikisi hâlâ `enabled` → auto-tune wakeup'ı
kapatmıyor; ama varsayılan da `enabled` olduğu için "dokunmuyor" ile "enabled
yazıyor" ayırt edilemiyor. Tek satır maliyetine ikisine de kondu.

**⚠️ `/proc/acpi/wakeup` kullanma.** O arayüz TOGGLE: aynı satırı iki kez yazan
servis ilk yazımı geri alır. Buradaki sysfs yolu idempotent.

**Doğrulama.** `cat /sys/bus/usb/devices/{3-2,3-4}/power/wakeup` → `disabled`.
Uykudan sonra kimin uyandırdığı `/sys/.../power/wakeup_count` sayaçlarında.

---

## 2026-08-27 — PSR ölçüldü, iki varsayım düştü, bir ölçüm tuzağı bulundu

Şikâyet: "pilde 9-12 W çekiyorum, 6 W beklerdim." Sonuç: **regresyon yoktu, ölçülen
şey yüktü.** Ölçüm aracı: `scripts/psr-idle-watts.sh`.

### PSR gerçekten çalışıyor (varsayım → ölçüm)

2 Tem bölümünün "PSR statikte scanout'u durduruyor" varsayımı doğrulandı:

```
/sys/kernel/debug/dri/0000:65:00.0/eDP-1/     ← PCI yolu; dri/1 semboliktir
  psr_capability            Sink support: yes [0x03] / Driver support: yes
  disallow_edp_enter_psr    0
  psr_state                 6  (PSR_STATE3 — panel kendini tazeliyor)
```

Statik ekranda 30 ve 60 s'lik pencerelerin **tamamında** `state=6`; bir kez bile
çıkılmadı.

**⚠️ `psr_residency` BİRİKMELİ SAYAÇ DEĞİL.** Okuma onu sıfırlıyor ve değer yalnız
PSR'den çıkıldığında yazılıyor. Pencere boyunca PSR hiç çıkmazsa sonda **0** okunur
— bu hata değil, **en iyi sonuç**. Delta alma; başta+sonda `psr_state` oku.

**⚠️ `psr_state` OKUMASI ÖLÇÜMÜ BOZAR.** Sürücü okumadan önce
`dc_allow_idle_optimizations(dc, false)` çağırıyor; poll etmek watt'ı yukarı taşır.
İlk seri (aşağıda) bu hatayla alındı; `psr-idle-watts.sh` artık yalnız pencere
başında/sonunda okuyor.

### Statik ekran tabanı: %65 parlaklıkta 4.88 W

Altı koşu, `psr_state` poll'u AÇIKKEN (hafif şişik):

| # | Süre | Ort | Min | Maks | Yayılım |
|---|---|---|---|---|---|
| 1 | 30 s | 5.51 | 4.84 | 8.94 | 4.10 |
| 2 | 30 s | 5.30 | 4.63 | 7.87 | 3.23 |
| 3 | 30 s | 5.49 | 4.85 | 12.31 | **7.46** |
| 5 | 30 s | 4.96 | 4.71 | 5.57 | **0.85** |
| 6 | 60 s | **4.88** | **4.66** | 5.33 | **0.67** |

**Yayılım = kalite göstergesi.** Minimumlar 4.63-4.85 (±0.2 W) — taban sabit;
arka plan uyanmaları maksimumu 12 W'a fırlatıp ortalamayı çekiyor. Kirli koşuda
güvenilecek sayı **minimum**dur. Eşik ampirik: temiz koşularda yayılım 0.67-0.85 W,
kirlilerde 3.2-7.5 W.

4.28 W %40 parlaklıkta, 4.88 W %65'te: +0.6 W, panel+backlight dağılımının
beklediği büyüklük. **Taban yerinde.**

### DÜŞEN VARSAYIM 1 — 165 Hz pilde bedava (kontrollü A/B)

```
165 Hz: 8.39 W     60 Hz: 8.33 W     → fark 0.06 W = gürültü
```

Tek değişken yenileme hızı, her biri 6×5 s. PSR yüzünden yenileme hızının boşta
bedeli yok; `power-display.nix`'in pilde 60 Hz'e düşmesinin ölçülmüş gerekçesi **yok**.

**KESİN DEĞİL:** taban 8.3 W, yani pencere yük altındaydı. 60 Hz kolu koruma amaçlı
BIRAKILDI; kaldırmadan önce temiz A/B şart:
`sudo -E bash scripts/psr-idle-watts.sh` ile her iki modda, DUR=60.

### DÜŞEN VARSAYIM 2 — animasyonun boşta maliyeti sıfır

Hyprland 0.56.1 kaynağı: `shouldTickForNext()` = `!m_vActiveAnimatedVariables.empty()`
— son animasyon bitince tick zinciri kopuyor; maliyet animasyon süresi kadar.
"Kalıcı kazançlar" listesi animasyonu paket halinde sayıyordu ve izole edilmemişti
(blur/gölge fiilen hiç kapatılmıyordu, yalnız `animations:enabled 0` yazılıyordu).
Satır `power-display.nix`'ten kaldırıldı. **Watt kaybı yok, his kazancı var.**

### Oturum başına fiyat: Serpantinum vs Caelestia

| | Serpantinum | Caelestia |
|---|---|---|
| Yeni süreç/s | **380** | **0** |
| Wakeup/s | 2701 | — |
| Güç (aynı yük) | 12.2 W | 8.0-8.4 W |

Serpantinum'un QML katmanı fetcher script'lerini timer'dan sürekli yeniden doğuruyor
(bash + `grep`/`awk`/`cat` fork'ları); `/proc/stat` `processes` sayacıyla ölçüldü.

Ayrıca o oturumda **35 dakikadır açık bir `bluetoothctl` discovery** bulundu (bağlı
cihaz yokken radyo %100); panel kapanışında taramayı durduran `trap` yoktu.

### Ölçüm tuzakları

- **`ps -eo pcpu` yaşam boyu ortalamadır**, boşta yük kanıtı olamaz; doğrusu
  `/proc/<pid>/stat` (utime+stime) deltası.
- **`gpu_busy_percent` GRBM'i ölçer, Display Core'u kapsamaz.**
- **`fdinfo`'da `drm-engine` sayacı yokluğu "iş yok" demek değil.** DRM master
  (kart düğümü) kullanan compositor'ların fd'lerinde bu sayaç yok; amdgpu sayaçları
  yalnız render-node istemcilerine yazıyor.
- **Aynı `drm-client-id`'ye ait fd'leri toplama** — sayı katlanır.
- **Ölçüm aracının kendisi yük**: terminale basılan her satır PSR'yi dışarı atar.
  `psr-idle-watts.sh` pencere içinde hiçbir şey yazdırmaz ve döngüde fork etmez
  (`sleep` yerine `read -t`, watt hesabı saf bash: µA×µV = pW).

## 2026-09-01 — CachyOS çekirdeğine geçiş: taban 4.28 → 5.16 W (+0.88 W)

`linuxPackages_latest` (7.2.0, nixpkgs, gcc) → `linux-cachyos-bore-lto-zen4` (7.2.2,
xddxdd, clang+ThinLTO+BORE). Geçişin tuzakları kodun yanında (`system/kernel/power.nix`
çekirdek bloğu, `flake.nix` `cachyos-kernel`, `system/drivers/gpu.nix` clang notu);
bu bölüm yalnız **güç sonucunu** taşır. BORE boştayken hiçbir şey yapmaz.

**Neden xddxdd, chaotic değil (1 Eyl 2026).** chaotic'in CachyOS configfile'ında
`CONFIG_SCHED_BORE` yok, v3/v4/zen4 varyantı da yok. xddxdd'nin üç çıktısı
(out/dev/modules) attic'te doğrulandı (narinfo 200) → kaynaktan derleme yok.

### Ölçüm

İlk `powertop` okuması (7.20 W) **atıldı**: Claude Code (%19.5 CPU), Deezer Electron
ve terminal açıktı, load 1.50. Uygulamalar kapatılıp `scripts/idle-baseline.sh` ile:

```
örnekler : 5.81 5.28 5.35 5.16 5.23 5.28
ORTALAMA : 5.35   MİNİMUM : 5.16   MAKSİMUM : 5.81   YAYILIM : 0.65  → TEMİZ
```

Koşul taban ile birebir: %40 parlaklık (26214/65535), `low-power`/EPP `power`, AC yok,
dGPU `suspended`, fork/s 0, gpu_busy %0. Yayılım temiz aralıkta:
**4.28 → 5.16 W, +0.88 W (%+21).** `idle-baseline.sh` bu tur MİNİMUM/MAKSİMUM/YAYILIM
basacak şekilde genişletildi.

### Sebep araması — üç aday, biri elendi

İki çekirdeğin `.config`'i yan yana (eskisi `linuxPackages_latest.kernel.configfile`):

| Anahtar | 7.2.0 nixpkgs | 7.2.2 cachyos |
|---|---|---|
| `CONFIG_RCU_LAZY_DEFAULT_OFF` | kapalı → lazy RCU **AÇIK** | `=y` → lazy RCU **KAPALI** |
| preemption | `PREEMPT_LAZY=y` | `PREEMPT=y` (full) |
| `CONFIG_CPU_IDLE_GOV_TEO` | yok | `=y` |

TEO **elendi**: `cpuidle/current_governor` ikisinde de `menu`.

İlk şüpheli **lazy RCU**. Canlıda `/sys/module/rcutree/parameters/enable_rcu_lazy`
= `N` ve dosya `0444` → runtime'da açılamıyor. `power.nix`'e **tek değişken olarak**
`rcutree.enable_rcu_lazy=1` eklendi; reboot sonrası aynı protokolle yeniden ölçülecek.

### Sıradaki kaldıraç (henüz denenmedi)

Lazy RCU farkı kapatmazsa: `preempt=voluntary`. `PREEMPT_DYNAMIC` ikisinde de açık
ama CachyOS'ta `PREEMPT_LAZY` derlenmemiş; `voluntary` en yakın nokta. Ayrı ölçümle,
tek değişken olarak denenmeli.

## power-display boot asılması (24 Eyl 2026)

Belirti: `nh os switch` → "Could not acquire lock". Kilidi önceki switch tutuyordu;
o da boot'tan (16:49) beri `activating` kalan `power-display.service`'i bekliyordu.
Zincir: sistem servisi → `systemctl --user start power-display-user` (bloklayan) →
`cosmic-randr list` compositor'dan 3 sa cevap almadı; `graphical.target` da `waiting`
kaldı. Düzeltme (`system/kernel/power-display.nix`): kullanıcı servisi `--no-block`
ile tetikleniyor, `cosmic-randr` çağrıları `timeout 5` ile sınırlı.

## 2026-10-04 — Kaynak taraması (Hyprland, pilde)

Yöntem: süreç/iş parçacığı başına `/proc/*/task/*/status` bağlam değişimi ve
`utime+stime` deltası, `/proc/stat` `processes` sayacı, `/proc/interrupts`.
Claude Code oturumu açıktı (kendisi ~440 uyanma/s + Ghostty ~120/s), bu yüzden
**watt A/B'si yapılmadı** — aşağıdaki sayılar yapısal, temiz idle tabanı değil.

### Uygulanan

| Değişiklik | Dosya | Ölçülen bedel (önce) |
|---|---|---|
| system76-scheduler kapalı | `system/desktop/cosmic.nix` | 12 MB + BCC `execsnoop` 220 MB RSS, ~20 uyanma/s; closure −180 MB |
| nvidia-powerd yalnız fişte | `system/kernel/power-display.nix` | pilde ~14 uyanma/s, iş yok (DB yalnız AC) |
| `/`: `noatime,lazytime,commit=60` | `system/kernel/power.nix` | jbd2 5 s'de bir commit → NVMe APST'den kalkıyor |
| nix-daemon SCHED_BATCH + G/Ç 7 | `system/kernel/cores.nix` | derleme oturumla eşit pay alıyordu |
| waybar fan/dGPU betikleri forksuz | `home/desktop/hyprland/scripts.nix` | 5 sn'de ~25 süreç |
| waybar `--log-level warning` | `home/desktop/hyprland/bar.nix` | ada animasyonunda kare başına günlük: 30 dk'da 812 satır |
| klavye ışığı boşta söner | `scripts.nix` kbdIdle + `session.nix` | ekran kapalıyken saatlerce yanıyordu |

Switch sonrası aynı koşulda 60 s: **fork/s 7.37 → 1.61**, CAL IPI/s 939 → 760,
kullanılan RAM 6589 → 6440 MB.

### Chromium/Electron gizli pencere: `VizCompositorThread` ~65 uyanma/s

Sesli asistanın arka plandaki Chromium'u da, tepsiye kapatılmış Claude Desktop da
pencere görünmezken Viz iş parçacığında ~60 Hz döngüde kalıyor (~%0.7 CPU her biri;
sayfanın animasyon zaman çizelgesi 0'da donmuş, kare hiç sunulmuyor). Denenen ve
İŞE YARAMAYANLAR: animasyonları CDP ile bitirmek; `Page.setWebLifecycleState
frozen` (renderer susar, Viz sürer; `active`e dönünce sayfa `hidden` kalır → hap
boş açılır, servis yeniden başlatılarak düzeltildi); Hyprland `render_unfocused`
(kare akınca claude.ai sürekli 60 fps çiziyor: daha kötü). **Watt karşılığı
ölçülemeyecek kadar küçük** — aşağıdaki A/B'de iki süreci cgroup'la dondurmak
gürültü içinde kaldı. Uyanma sayısı büyük görünse de bedeli yok.

## 2026-10-05 — Çalışma anı A/B: VRR PSR'ı kapatıyordu (−0.70 W)

Araç: `scripts/power-ab.sh` (root; ABBA/ABBAAB sırası, kol başına 50-55 s ölçüm +
10 s sakinleşme, ölçüm penceresinde fork/çıktı yok, pencere sonunda `psr_state`).
Koşul: pilde, %40 parlaklık, Hyprland boş çalışma alanı (statik duvar kâğıdı),
`systemd-inhibit idle:sleep`, Claude Desktop + sesli asistan + syncthing açık.

**1. tur (VRR=1, kullanıcının o günkü ayarı)** — mW, Δ = B − A:

| Kol | A | B | Δ | Not |
|---|---|---|---|---|
| **vrr 1 → 0** | 6094 | 5398 | **−696** | A'da `psr_state` 0, B'de 6 |
| cpuidle menu → teo | 6078 | 6020 | −58 | 2. turda tekrarlanmadı |
| klavye USB autosuspend | 6088 | 6098 | +10 | xHCI uyusa da fark yok |
| IRQ/wq/kthread → Zen5c | 6077 | 6116 | +39 | |
| **iGPU dpm auto → low** | 6289 | 7967 | **+1678** | `low` çok kötü — Temmuz'daki `low` kararı geçersiz |
| Claude Desktop dondur | 6099 | 6051 | −48 | |
| sesli asistan dondur | 6076 | 6095 | +19 | |

Bütün turda (VRR=1) `psr_state` arm sonlarında **0**: VRR açık panelde PSR hiç
devreye girmiyor; panel 48-165 Hz arasında sürekli taranıyor. `preempt` kolu atlandı:
bu çekirdekte `/sys/kernel/debug/sched/preempt` yok, yalnız açılış parametresi.

**2. tur (PRE_VRR=0 — PSR'lı rejim, ABBAAB):**

| Kol | A | B | Δ |
|---|---|---|---|
| vrr 0 → 3 | 5422 | 5349 | −73 (B'de `psr_state` 6) |
| cpuidle menu → teo | 5323 | 5326 | +3 |
| IRQ/wq/kthread → Zen5c | 5272 | 5317 | +45 |
| Claude Desktop dondur | 5339 | 5306 | −33 |
| sesli asistan dondur | 5329 | 5494 | +165 (tek 13.9 W sıçraması; hariç ~0) |
| klavye USB autosuspend | 5283 | 5280 | −3 |

**Uygulanan:** VRR fişe bağlandı (`lua/main.lua` `power_sync()`): fişte 1
(kullanıcı isteği), pilde **3** (yalnız tam ekran video/oyun) → masaüstünde PSR
serbest. Diğer kolların hiçbiri gürültüyü aşmadı; uygulanmadı. Klavye `on`
kalıyor (girdi gecikmesine değecek bir kazanç yok), menu kalıyor, IRQ dağılımı
çekirdeğe bırakılıyor. Yeni PSR'lı statik taban: **~5.3 W** (%40, uygulamalar açık).

**Uyku doğrulaması:** 4 Eki 19:44 → 22:54 s2idle uykusunda `last_hw_sleep`
11395.5 s / 11400 s — **%99.96 S0i3**. Uyku tarafında kaçak yok.

**Çalışma anında kalan kol yok.** Sıradaki adaylar açılış gerektiriyor ve
reboot'lu A/B ister: `preempt=voluntary` (CachyOS'ta PREEMPT_LAZY derlenmemiş)
ve CachyOS ↔ nixpkgs çekirdeği farkının (+0.88 W, 2026-09-01) geri kalanı.
