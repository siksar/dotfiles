# Güç — idle bütçesinin ölçüm defteri

**4.28 W temiz idle tabanı bu repodaki sert kısıttır** (bkz. CLAUDE.md ve
`system/kernel/sched.nix` başındaki tasarım notu). Bu dosya o sayının nereden
geldiğini tutar; `system/kernel/power.nix` ve `power-display.nix`'e dokunmadan
önce okunur.

Ölçüm yöntemi: firmware `power_now` bildirmiyor, watt'ı elle hesapla —
`current_now × voltage_now / 1e12`, kaynak `/sys/class/power_supply/BAT1/`.
Ham dökümleri `scripts/power-audit.sh` üretir (çıktı dizini gitignore'da;
kalıcı bulgular buraya yazılır).

---

## 2026-07-02 — IPS force testi + temiz taban

Tüm ölçümler: pilde, 60Hz, %40 parlaklık, boost=0, EPP=power, temiz idle
(120s sakinleşme + 6×10s örnek, current_now×voltage_now).

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
- Ayrıca IPS aktifken `amdgpu_gfxoff_status` debugfs okuması display controller'ı
  kilitledi (flip_done timeout, VT değişimi dahil). GPU reset (`amdgpu_gpu_recover`)
  ile kurtarıldı; param revert edildi (commit 29f630b). BU DOSYAYI IPS force
  altında ASLA OKUMA.

## Doğrulanan kalıcı kazançlar

- Pille boot → 60Hz + %40 parlaklık + blur/gölge/animasyon kapalı (boot+oturum servisleri)
- CPU boost off, 2GHz tavan, iGPU dpm low, platform low-power, webcam hard-off
- aorus-laptop (gigabyte-laptop-wmi): fan idle'da 0 RPM (doğrulandı), CPU 34°C,
  şarj limiti %80 (her boot oneshot), fan_mode EC default silent
- amdxdna blacklist, workqueue.power_efficient, pcie_port_pm=force, ABM4

## Kalan tüketimin dağılımı (tahmini, 4.28W)

Panel+backlight %40 ~1.2-1.5W · SoC idle ~1.5-2W · WiFi (rtw89 PS on) ~0.3-0.5W
· NVMe APST ~0.2-0.4W · RAM/EC/misc ~0.5W · dGPU D3cold ~0.05W

## Denenmedi / gelecek fikirler

- Panel 48Hz destekliyor (EDID V-range 48–165). PSR statikte scanout'u zaten
  durdurduğu için beklenen kazanç küçük; VRR denenirse PSR etkileşimine dikkat.
- Pil: 73.8 Wh → 4.28W'ta ~17.2 saat idle.

---

## 2026-08-24 — Hibernate neden kapatıldı (oyunda tam kilitlenmenin kökü)

**Belirti.** Oyun sırasında sistem tamamen kilitleniyor: görüntü donuyor, girdi
gitmiş, TTY yok, güç tuşuna kısa basış kapatmıyor. Tek çıkış güç tuşunu basılı
tutmak.

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

**Neden *tamamen* kilitleniyor.** CPU donmuyor — bırakılmamış bir spinlock var.
`list_del` bozulmayı yakalayınca `BUG()` atıyor ve görev TTM LRU spinlock'unu
**tutarken** ölüyor; `exited with preempt_count 1` tam olarak bunu söylüyor.
O kilit bir daha bırakılmıyor, amdgpu'ya dokunan her şey (Hyprland, oyun,
compositor) sonsuza kadar dönüyor. `.swayosd-server` kurban, suçlu değil —
sadece küçük GEM tahsisi yapan sık bir çağıran olduğu için zehirli listeye
ilk o dokunuyor.

**Neden loga hiç "çökme" gibi görünmedi.** `nowatchdog nmi_watchdog=0` (bu
dosyadaki idle bütçesi ayarları) softlockup ve hardlockup dedektörlerini
kapatıyor → panik yok, otomatik reboot yok, crash dump yok. Kanıt yalnızca
journald ilk oops satırlarını diske yetiştirdiği için hayatta kaldı.

**Bağıntı (25 boot, 29 Tem – 24 Ağu).**

| Boot | s2h denemesi | TTM WARN | Sonuç |
|---|---|---|---|
| -8 (16 Ağu) | var | 0 | NULL pointer deref |
| -6 (19 Ağu) | var (3) | 10 | list_del BUG → kilitlenme |
| -1 (24 Ağu) | var (2) | 11 | list_del BUG → kilitlenme |
| -12,-11,-10,-7,-5,-4,-3,-2,0 | **yok** | 0 | temiz |

Çöken 3 boot'un 3'ünde de hibernate denemesi var; denenmemiş 9 boot'ta sıfır
çökme. TTM WARN gören 2 boot'un 2'sinde de çökme geldi — WARN, saatler
öncesinden haber veren bir sinyal:
`journalctl -kb | grep ttm_resource_add_bulk_move`.

**Karşılığında kaybedilen yok: hibernate hiç çalışmamıştı.**
Hiçbir boot'ta imaj yazma logu yok; her açılışta
`systemd-hibernate-resume: Unable to resume from device ... continuing boot
process`; hiçbir boot'ta `Resuming from`; boot ID'ler uykular boyunca
kesintisiz. MAINTAINERS'ın 30 Tem'den beri "ELLE TEST BEKLİYOR" dediği
doğrulama buydu, sonucu: çalışmıyor. 25 dakikalık RTC alarmı ise her uykuda
makineyi bir kez boşuna uyandırıyordu; o da gitti.

**Uygulanan.** `system/kernel/power.nix`:
`HandleLidSwitch`/`HandleLidSwitchExternalPower`/`HandleSuspendKey` → `suspend`,
artı `nohibernate` kernel parametresi. İkincisi şart: handler'lar tek başına
`HandleHibernateKey`'i ve Caelestia menüsünün `suspendThenHibernate` çağrısını
kapatmıyor; `nohibernate` ile `CanHibernate` "na" dönüyor ve o yollar
kendiliğinden düz suspend'e düşüyor.

**Geri açma koşulu.** Kernel'i güncelle, elle bir `systemctl hibernate` dene,
sonra ikisi birden tutmalı: `journalctl -kb | grep ttm_resource_add_bulk_move`
BOŞ, ve `journalctl -b | grep 'Resuming from'` bir satır. Biri eksikse açma.

## 2026-08-24 — USB uyandırma kapatıldı (iki klavye)

Kullanıcı "uykudayken bazen USB cihazları sistemi uyandırıyor" dedi. Journal'da
25 boot boyunca **kendiliğinden uyanma bulunamadı**: her `PM: suspend exit`'in
karşılığı kapak açılması, güç tuşu ya da yukarıdaki 25 dk'lık RTC alarmıydı.
Gözlemin bir kısmı büyük olasılıkla o alarmdı (artık yok).

Yetenek denetimi yine de gerçek bir açık gösterdi — uyandırma izni olan tam iki
USB cihazı:

| Cihaz | ID | Tür | Önce | Sonra |
|---|---|---|---|---|
| BY Tech Gaming Keyboard | `258a:0049` | removable (harici) | enabled | **disabled** |
| GIGABYTE USB-HID Keyboard | `0414:8104` | fixed (dahili Fn/RGB HID) | enabled | **disabled** |
| Glorious Model I (fare) | `22d4:1503` | removable | disabled | (dokunulmadı) |
| Bluetooth Radio | `0bda:0852` | fixed | disabled | (dokunulmadı) |

Fare ve Bluetooth çekirdek varsayılanıyla zaten kapalı; ölçülmemiş bir davranışı
kurala bağlamak regresyon üretir diye onlara kural yazılmadı.

Uyandırmaya devam edenler: kapak (`PNP0C0D`), güç tuşu (`PNP0C0C`) ve dahili
AT klavye (`serio0`/i8042 — yazılan asıl klavye, USB'den ayrı yol), yani
"tuşa basınca uyanma" jesti korundu.

**Neden hem udev'de hem `power-tunables-restore`'da.** powertop ikilisinde
`/sys/bus/usb/devices/%s/power/wakeup` yolu ve bir `usb_wakeup` tunable sınıfı
var (`strings` ile görüldü). Ölçüm: klavyeler 17:10:51'de enumere oldu, powertop
17:10:57–59'da koştu, sonrasında ikisi de hâlâ `enabled` → auto-tune wakeup'ı
**kapatmıyor**. Ama çekirdek varsayılanı da `enabled` olduğu için "hiç
dokunmuyor" ile "enabled yazıyor" ayırt edilemiyor; ikinci ihtimalde udev
kuralı ezilirdi (`power/control`'de bizzat yaşanan senaryo). Tek satır
maliyetine kapatıldı.

**⚠️ `/proc/acpi/wakeup` kullanma.** O arayüz TOGGLE: cihaz adını yazmak durumu
ters çevirir, aynı satırı iki kez çalıştıran bir servis ilk yazımı geri alır.
Buradaki sysfs yolu idempotent.

**Doğrulama.** `cat /sys/bus/usb/devices/{3-2,3-4}/power/wakeup` → `disabled`.
Bir uykudan sonra kimin uyandırdığı `/sys/.../power/wakeup_count` sayaçlarında.

---

## 2026-08-27 — PSR ölçüldü, iki varsayım düştü, bir ölçüm tuzağı bulundu

Bu bölümün çıkış noktası bir şikâyetti: "pilde 9-12 W çekiyorum, 6 W beklerdim."
Sonuç: **regresyon yoktu, ölçülen şey yüktü.** Yol boyunca üç varsayım test edildi;
ikisi düştü. Ölçüm aracı `scripts/psr-idle-watts.sh` olarak repoya girdi.

### PSR gerçekten çalışıyor (varsayım → ölçüm)

Bu dosyanın 2 Tem bölümü "PSR statikte scanout'u zaten durduruyor" diye
**varsayıyordu**; hiç doğrulanmamıştı. Doğrulandı:

```
/sys/kernel/debug/dri/0000:65:00.0/eDP-1/     ← PCI yolu; dri/1 semboliktir
  psr_capability            Sink support: yes [0x03] / Driver support: yes
  disallow_edp_enter_psr    0
  psr_state                 6  (PSR_STATE3 — panel kendini tazeliyor)
```

Statik ekranda 30 ve 60 s'lik pencerelerin **tamamında** `state=6`; bir kez bile
çıkılmadı. Yani panel boştayken gerçekten ucuz.

**⚠️ `psr_residency` BİRİKMELİ SAYAÇ DEĞİL.** Okuma onu sıfırlıyor ve değer yalnız
PSR'den ÇIKILDIĞINDA yazılıyor — "tamamlanmış son oturumun süresi". Pencere boyunca
PSR hiç çıkmazsa sonda **0** okunur, delta negatif çıkar. `0` burada hata değil,
**en iyi sonuç**. Delta alma; başta+sonda `psr_state` oku.

**⚠️ `psr_state` OKUMASI ÖLÇÜMÜ BOZAR.** Sürücüde bu dosyanın okuması, okumadan önce
`dc_allow_idle_optimizations(dc, false)` çağırıyor. Saniyede bir poll etmek idle
optimizasyonlarını düzenli kapatır ve ölçtüğün watt'ı yukarı taşır. İlk seri (aşağıda)
bu hatayla alındı; `psr-idle-watts.sh` artık yalnız pencere başında/sonunda okuyor.

### Statik ekran tabanı: %65 parlaklıkta 4.88 W

Altı koşu, `psr_state` poll'u AÇIKKEN (yani hafif şişik):

| # | Süre | Ort | Min | Maks | Yayılım |
|---|---|---|---|---|---|
| 1 | 30 s | 5.51 | 4.84 | 8.94 | 4.10 |
| 2 | 30 s | 5.30 | 4.63 | 7.87 | 3.23 |
| 3 | 30 s | 5.49 | 4.85 | 12.31 | **7.46** |
| 5 | 30 s | 4.96 | 4.71 | 5.57 | **0.85** |
| 6 | 60 s | **4.88** | **4.66** | 5.33 | **0.67** |

**Yayılım = kalite göstergesi, gürültü değil.** Minimumlar altı koşuda 4.63-4.85
arasında (±0.2 W) — taban sabit. Oynayan şey maksimum: arka planda bir şey uyanınca
12 W'a fırlıyor ve **ortalamayı** yukarı çekiyor, tabanı değil. Kirli bir koşuda
güvenilecek sayı ortalama değil **minimum**dur. Eşik ampirik: temiz koşularda yayılım
0.67-0.85 W, kirlilerde 3.2-7.5 W — arada net boşluk var.

4.28 W tabanı %40 parlaklıkta ölçülmüştü; 4.88 W %65'te. +0.6 W, bu dosyanın kendi
dağılımının (panel+backlight %40'ta 1.2-1.5 W) beklediği büyüklük. **Taban yerinde.**

### DÜŞEN VARSAYIM 1 — 165 Hz pilde bedava (kontrollü A/B)

```
165 Hz: 8.39 W     60 Hz: 8.33 W     → fark 0.06 W = gürültü
```

Tek değişken yenileme hızı, her biri 6×5 s. PSR statik içerikte scanout'u zaten
durdurduğu için yenileme hızının boşta bedeli yok. `power-display.nix`'in pilde 60 Hz'e
düşmesinin ölçülmüş bir gerekçesi **yok**.

**Bu ölçüm KESİN DEĞİL:** taban 8.3 W, yani pencere yük altındaydı (temiz idle 4.9 W).
60 Hz kolu bu yüzden koruma amaçlı BIRAKILDI. Kaldırmadan önce temiz A/B şart:
`sudo -E bash scripts/psr-idle-watts.sh` ile her iki modda, DUR=60.

### DÜŞEN VARSAYIM 2 — animasyonun boşta maliyeti sıfır

Hyprland 0.56.1 kaynağı: `shouldTickForNext()` = `!m_vActiveAnimatedVariables.empty()`.
Son animasyon bitip liste boşalınca tick zinciri kopuyor, `scheduleFrame` çağrılmıyor.
Maliyet tam olarak animasyonun süresi kadar; kuyruğu yok. Yukarıdaki "kalıcı kazançlar"
listesi animasyonu **paket halinde** sayıyordu (60Hz + %40 parlaklık + blur/gölge/
animasyon) ve bileşen hiç izole edilmemişti. Üstelik blur/gölge fiilen hiç
kapatılmıyordu — yalnız `animations:enabled 0` yazılıyordu. Satır kaldırıldı
(`power-display.nix`, aynı tarih). **Watt kaybı yok, his kazancı var.**

### Oturum başına fiyat: Serpantinum vs Caelestia

| | Serpantinum | Caelestia |
|---|---|---|
| Yeni süreç/s | **380** | **0** |
| Wakeup/s | 2701 | — |
| Güç (aynı yük) | 12.2 W | 8.0-8.4 W |

Serpantinum'un QML katmanı fetcher script'lerini timer'dan sürekli yeniden doğuruyor;
her çağrı bash + zincirleme `grep`/`awk`/`cat` forkluyor. `/proc/stat`'ın `processes`
sayacıyla ölçüldü. Bu, `CLAUDE.md`'nin Serpantinum'u "karantinalı istisna" saymasının
sayısal karşılığı.

Ayrıca o oturumda **35 dakikadır açık kalmış bir `bluetoothctl` discovery** bulundu
(bağlı cihaz yokken radyo %100). Panel kapanışında taramayı durduran bir `trap` yok —
oturumdan bağımsız gerçek bir kaçak.

### Ölçüm tuzakları (bu bölümün en pahalı dersi)

- **`ps -eo pcpu` yaşam boyu ORTALAMADIR**, anlık değil. 25 saatlik bir compositor için
  bu sayı tüm aktif kullanımı içerir; boşta yük kanıtı olarak kullanılamaz. Doğrusu
  `/proc/<pid>/stat` (utime+stime) deltası.
- **`gpu_busy_percent` GRBM'i ölçer, Display Core'u KAPSAMAZ.** "iGPU %X meşgul"
  okuması eksik metriktir.
- **`fdinfo`'da `drm-engine` sayacı olmaması "iş yok" demek değil, "sayaç yok" demek.**
  Hyprland'ın hiçbir fd'sinde bu sayaç yok çünkü aquamarine DRM master (kart düğümü)
  kullanıyor; amdgpu sayaçları yalnız render-node istemcilerine yazıyor.
- **Aynı `drm-client-id`'ye ait fd'leri toplama** — üç fd tek istemciyse sayı 3× şişer.
- **Ölçüm aracının kendisi yük**: terminale basılan her satır pencereyi yeniden çizdirir
  ve PSR'yi dışarı atar. `psr-idle-watts.sh` bu yüzden pencere içinde hiçbir şey
  yazdırmaz ve döngüde fork etmez (`sleep` yerine `read -t`, watt hesabı saf bash
  tamsayı aritmetiği: µA×µV = pW).

## 2026-09-01 — CachyOS çekirdeğine geçiş: taban 4.28 → 5.16 W (+0.88 W)

`linuxPackages_latest` (7.2.0, nixpkgs, gcc) → `linux-cachyos-bore-lto-zen4` (7.2.2,
xddxdd, clang+ThinLTO+BORE). Geçişin kendisi ve derleme tuzakları MAINTAINERS'ta; bu
bölüm yalnız **güç sonucunu** taşır.

### Ölçüm

İlk okuma `powertop` üzerinden 7.20 W'dı ve **atıldı** — o anda Claude Code oturumu
(%19.5 CPU), Deezer'ın Electron yığını (GPU+network+audio servisleri) ve terminal
koşuyordu, load average 1.50. Bu dosyanın kendi "ölçüm aracının kendisi yük" dersinin
bir tekrarı. Uygulamalar kapatılıp `scripts/idle-baseline.sh` ile:

```
örnekler : 5.81 5.28 5.35 5.16 5.23 5.28
ORTALAMA : 5.35   MİNİMUM : 5.16   MAKSİMUM : 5.81   YAYILIM : 0.65  → TEMİZ
```

Koşul taban ile birebir: %40 parlaklık (26214/65535), `low-power`/EPP `power`, AC yok,
dGPU `suspended`, fork/s 0, gpu_busy %0. Yayılım 0.65 W bu dosyanın temiz-koşu
aralığında (0.67-0.85), yani sayı kullanılabilir ve karşılaştırma geçerli:
**4.28 → 5.16 W, +0.88 W (%+21).**

`idle-baseline.sh` bu tur MİNİMUM/MAKSİMUM/YAYILIM basacak şekilde genişletildi —
"kirli koşuda ortalamaya değil minimuma bak" kuralı yazılıydı ama script onu
uygulamıyordu, yalnız ortalama basıyordu.

### Sebep araması — üç aday, biri elendi

İki çekirdeğin `.config`'i yan yana konarak (eskisi
`linuxPackages_latest.kernel.configfile`'dan indirildi):

| Anahtar | 7.2.0 nixpkgs | 7.2.2 cachyos |
|---|---|---|
| `CONFIG_RCU_LAZY_DEFAULT_OFF` | kapalı → lazy RCU **AÇIK** | `=y` → lazy RCU **KAPALI** |
| preemption | `PREEMPT_LAZY=y` | `PREEMPT=y` (full) |
| `CONFIG_CPU_IDLE_GOV_TEO` | yok | `=y` |

Üçüncüsü **elendi**: `/sys/devices/system/cpu/cpuidle/current_governor` ikisinde de
`menu`. TEO derlenmiş ama seçilmemiş, yani davranış değişmiyor.

Kalan ilk şüpheli **lazy RCU**. Boştaki bir CPU'yu her RCU callback'i için uyandırmak
yerine onları toplu işler — doğrudan bu bütçenin konusu. Canlıda doğrulandı:
`/sys/module/rcutree/parameters/enable_rcu_lazy` = `N`, ve dosya `0444`, yani
runtime'da açılamıyor → kernel parametresi gerekiyor.

`power.nix`'e **tek değişken olarak** `rcutree.enable_rcu_lazy=1` eklendi. Reboot
sonrası aynı protokolle yeniden ölçülecek.

### Sıradaki kaldıraç (henüz denenmedi)

Lazy RCU farkı kapatmazsa: `preempt=voluntary`. `PREEMPT_DYNAMIC` iki çekirdekte de
açık, ama CachyOS'ta `PREEMPT_LAZY` **derlenmemiş**, dolayısıyla eski davranışın
birebir karşılığı yok; `voluntary` en yakın nokta. Ayrı bir ölçümle, tek değişken
olarak denenmeli.
