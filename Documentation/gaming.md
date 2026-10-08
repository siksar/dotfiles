# AERO X16 — Oyun Kurulumu ve Kullanımı

*Kurulum: 2026-07-05 · Sürücü: NVIDIA 610.43.02 (open) · Kernel 7.1.1 · DLSS 4.5 dönemi*

## 11 Eyl 2026 — COSMIC oturumunda dGPU zinciri ölçüldü, sağlam

`system/desktop/cosmic.nix`'in 2 Eyl notu (*"COSMIC_DRM_ALLOW_DEVICES yalnız iGPU'ya
izin verdiği için gamerun'ın PRIME offload'ı COSMIC'te çalışmaz"*) ölçülmemiş bir
tahmindi ve yanlış çıktı. Canlı oturumda:

```
$ echo $XDG_CURRENT_DESKTOP $COSMIC_DRM_ALLOW_DEVICES
COSMIC 0x1002:0x1114                       ← guard oturumda AKTİF

$ vulkaninfo --summary | grep deviceName
AMD Radeon 860M Graphics (RADV KRACKAN1)
NVIDIA GeForce RTX 5060 Laptop GPU         ← dGPU GÖRÜNÜYOR
llvmpipe (LLVM 21.1.8, 256 bits)

$ GR_NOPERF=1 GR_QUIET=1 gamerun vulkaninfo --summary
GPU1: deviceType = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU

$ GR_NOPERF=1 GR_QUIET=1 gamerun env | grep __NV
__NV_PRIME_RENDER_OFFLOAD=1
__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0

$ cat /sys/bus/pci/devices/0000:64:00.0/power_state
D3cold                                     ← boştayken hâlâ uykuda
```

**Sonuç:** guard yalnız **compositor'ın** açacağı DRM node'unu kısıtlar; oyun süreci
Vulkan/NVIDIA sürücüsüne doğrudan gider. İdle bütçesi (dGPU D3cold) ile oyun
offload'ı aynı anda geçerli. Ölçülmeyen: gerçek bir Steam oyununun uçtan uca kare
üretimi. 29 Eyl 2026'dan beri varsayılan oturum GNOME (guard = udev etiketi
`mutter-device-ignore`); oturum başına dGPU durumu: `Documentation/desktop.md`.

## 2 Eyl 2026 — gamerun SIFIRDAN YAZILDI (iki ölçülmüş kök neden)

Belirti: *"gamerun bozuk, çoğu oyunda çalıştıramıyorum; Sekiro vs. ayar menüsüne
girince donabiliyor."* `localconfig.vdf` doğruluyordu — gamerun çoğu oyundan
çıkarılmış, kalan bir satır `%command%`siz `"gamerun"` yazılıydı.

### Kök neden 1 — `DXVK_NVAPI_VKREFLEX=1` bir env AYARI değil, KATMAN anahtarı

Eski gamerun bunu koşulsuz export ediyordu (*"Reflex — güvenli, açık kalır"*).
Gerçekte proton-cachyos içindeki bir **implicit Vulkan katmanının**
`enable_environment`'ı:

```json
// share/dxvk-nvapi-vkreflex-layer/implicit_layer.d/VkLayer_DXVK_NVAPI_reflex.json
"name": "VK_LAYER_DXVK_NVAPI_reflex",
"device_extensions": [{ "name": "VK_NV_low_latency", "spec_version": "1" }],
"enable_environment": { "DXVK_NVAPI_VKREFLEX": "1" }
```

Katman **eski** `VK_NV_low_latency` (rev 1)'i taklit eder; sürücü yerlisini zaten
veriyor (`vulkaninfo`, 2 Eyl 2026, NVIDIA 610.57.04):

```
VK_NV_low_latency2 : extension revision 2   ← dxvk-nvapi'nin gerçekte kullandığı
VK_NV_low_latency  : extension revision 1   ← katmanın taklit ettiği eski sürüm
```

> **Kanıtın sınırı.** ÖLÇÜLEN: değişkenin katman anahtarı olduğu (manifest) ve
> sürücünün `low_latency2`'yi yerlisinden verdiği → katman **gereksiz**.
> ÖLÇÜLMEYEN: donmaların bu katmandan geldiği (çıkarım; ayar menüsü swapchain'i
> yeniden kurar; 26 Ağu 2026'da Elden Ring'de `DXVK_NVAPI_VKREFLEX=0` zaten
> denenmiş, Steam logunda duruyor). Kaldırma yine de doğru: gereksiz katman tutulmaz.
> Donma sürerse ilk şüpheliler `system/drivers/gpu.nix`'teki
> `powerManagement.finegrained` (dGPU D3cold uyandırma yolu) ve Proton sürümü.
> Doğrulama: aynı sahneyi 3 kez dene; donarsa `GR_NOPERF=1 gamerun`, sonra gamerun'sız.

MangoHud'un 22 Tem 2026'da kaldırılmasıyla **aynı sınıf** hata (oyun↔Vulkan sürücüsü
arasına giren katman). **Yeni gamerun hiçbir Vulkan katmanı enjekte etmez.** Reflex
kaybolmadı — sürücü/dxvk-nvapi onu `low_latency2` üzerinden yapıyor.

### Kök neden 2 — `gamemoderun`'ın LD_PRELOAD'ı konteyneri geçemiyor

Eski gamerun `exec gamemoderun "$@"` ile bitiyordu (`LD_PRELOAD=libgamemodeauto.so.0`
+ store `LD_LIBRARY_PATH`). Oyun Steam'in pressure-vessel konteynerinde açılır ve
store yolu içeride yoktur. Ölçülen (`~/steam-1245620.log`, Elden Ring, satır satır):

```
gamemodeauto: dlopen failed - libgamemode.so: cannot open shared object file
```

→ gamemode aktive olmuyor → `custom.start` koşmuyor → `game-perf.service`,
`scx_lavd`, 0xED profili, turbo fan: **hiçbiri**. 10 Ağu düzeltmesi yalnız
`command not found`u çözmüş; zincirin geri kalanı 2 Eyl'e kadar ölüydü. Ayrıca
`LD_PRELOAD` her alt sürece miras kalıyordu — anti-cheat'li oyunlarda (Elden Ring
`start_protected_game.exe` = EAC) gereksiz risk.

**Düzeltme:** gamemode aradan çıktı; gamerun `game-perf.service`'i **doğrudan**
sürüyor (kullanıcı `zixar`, parolasız, `system/kernel/sched.nix` polkit kuralı):

```
systemctl start game-perf.service → rc=0
scx.service → active | fan_mode → turbo | PPD → balanced
systemctl stop  game-perf.service → fan_mode → responsive | PPD → balanced
```

### Kök neden 3 — PRIME offload OpenGL'de HİÇ ÇALIŞMIYORDU (Minecraft iGPU'daydı)

`glxinfo -B` (2 Eyl 2026, `mesa-demos` bu flake'in pinli nixpkgs'inden):

| Ortam | `OpenGL renderer string` |
|---|---|
| ham (sarmalayıcısız) | AMD Radeon 860M Graphics (radeonsi) |
| **ESKİ gamerun** | **AMD Radeon 860M Graphics (radeonsi)** ← offload ETMEMİŞ |
| ESKİ gamerun + `GR_NVONLY=1` | NVIDIA GeForce RTX 5060 Laptop GPU |
| **YENİ gamerun** | **NVIDIA GeForce RTX 5060 Laptop GPU** |

Sebep: GLX satıcısını `__GLX_VENDOR_LIBRARY_NAME` seçer; eski gamerun onu varsayılan
kapalı `GR_NVONLY`'nin arkasına saklamıştı (nixpkgs `nvidia-offload` betiği onu her
zaman verir). Etkilenen: OpenGL kullanan her şey, başta **Minecraft** — bugüne kadar
iGPU'da koşmuş. Vulkan oyunları etkilenmedi (DXVK/VKD3D cihazı kendi seçer).

**Yeni gamerun üçlüyü her zaman verir.** Ters yön dışarıdan ezilir (`:-` deseni,
verilen değer kazanır) — ölçüldü:

```
LIBGL_ALWAYS_SOFTWARE=1 gamerun …                          → NVIDIA (NO-OP! LIBGL_* Mesa'ya özgü)
LIBGL_ALWAYS_SOFTWARE=1 __GLX_VENDOR_LIBRARY_NAME=mesa gamerun … → llvmpipe (doğru)
```

Bu, aşağıdaki HOI4/Paradox launcher düzeltmesini doğrudan ilgilendirir.

### Kök neden 4 (yan bulgu) — `scx.service` iki oyun açılışında ÖLÜYORDU

Upstream `scx.nix` `StartLimitBurst=2` / `StartLimitIntervalSec=30s` koyuyor;
**30 saniye içinde iki kez oyun açmak** scx.service'i kalıcı `failed`a düşürüyordu:

```
scx.service: Start request repeated too quickly.
scx.service: Failed with result 'start-limit-hit'.
```

`reset-failed` olmadan bir daha başlamıyordu — çöken oyunu hemen yeniden açmak
scx_lavd'ı sessizce öldürüyordu. `sched.nix`'te `startLimitIntervalSec = lib.mkForce 0`
(game-perf için de; onun varsayılanı 5/10s idi). Tetikleyen bir insan, çöküş döngüsü değil.

> Bu değişiklikten önce sınıra takıldıysan bir kez `sudo systemctl reset-failed scx.service`.

### Yeni gamerun'ın tasarım ilkeleri

| İlke | Ne demek |
|---|---|
| **A — Oyun her hâlükârda açılır** | taskset/game-perf/PRIME hepsi opsiyonel; başarısız olursa uyarı basıp devam eder. Hiçbir kod yolu oyunu başlatmamaya karar veremez. |
| **B — Katman enjekte etme** | Vulkan katmanı yok, LD_PRELOAD yok. Yalnız süreç nitelikleri (env, CPU affinity) + sistem servisleri. |
| **C — Yalnız ölçülmüş iş** | DLSS/MFG/FG/SmoothMotion/low-latency/ntsync/VKD3D env'leri gamerun'dan **çıkarıldı**. Oyuna özgüler; launch options'a doğrudan yazılırlar (aşağıdaki tablo). |
| **D — Temizlik garantili** | `trap` + referans sayacı: çıkışta game-perf mutlaka durur. SIGKILL kaçağı 12 Eyl 2026'da kapatıldı: gamerun açılışta sızmış oturumu sıfırlıyor + `game-perf-reap.service` udev/uyanışta aynısını yapıyor. |

C'nin sonucu: gamerun o değişkenlere dokunmadığı için ezmez de — `PROTON_USE_NTSYNC=1
gamerun %command%` olduğu gibi geçer, ve `PROTON_USE_OPTISCALER=1 PROTON_FSR4_UPGRADE=1
gamerun %command%` artık çakışmıyor (gamerun NGX/DLSS override'ı yapmıyor).

**Kaybedilen tek şey:** gamemode'un `renice -20` + `ioprio 0`'ı — Steam yolunda zaten
hiç çalışmıyordu; mc-run/emu-run yolunda küçük gerileme. Karşılığında oyun boyunca
gerçekten koşan `scx_lavd --performance`.

## 10 Ağu 2026 — KRİTİK: gamerun Steam'den hiç çalışmıyordu

`console-linux.txt` bu tarihe kadar `gamerun: command not found` basıyordu: Steam
launch options'ı kendi FHS/pressure-vessel kum havuzunda `/bin/sh -c` ile koşuyor
(`PATH=/usr/bin:/bin`); gamerun HM profilindeydi, içeride görünmüyordu. Yani tüm zincir
o güne kadar **hiçbir Steam oyununda tetiklenmedi**. mc-run/emu-run etkilenmedi
(normal kullanıcı PATH'i).

**Düzeltme:** gamerun `lib/gamerun.nix`'e taşındı (`home/apps/games.nix` ile
`usr/steam.nix`'in ortak noktası); `usr/steam.nix` onu `programs.steam.extraPackages`
ile kum havuzuna ekliyor → `/usr/bin/gamerun`.

Aynı gün gelen **CPU maske delme**: `system/kernel/cores.nix` masaüstünü Zen5c'ye
kilitliyor (ayrıntı `Documentation/aerox16/cpu-hybrid.md`); gamerun varsayılan
`taskset -c 0-15` ile başlayıp maskeyi oyun için deliyor (`GR_PIN` ile daraltılabilir).

Aynı gün eklenen `GR_NVONLY`/`GR_DLSS`/`GR_CACHE` opt-in'leri **2 Eyl 2026'da
kaldırıldı**: `GR_NVONLY` yerine `GR_GPU=nvidia` (GLX satıcısı ondan ayrılıp her zaman
açık oldu), diğer ikisi ilke C gereği ham env olarak launch options'a.

**Steam tarafı (nix dışı):** üç oyunda launch options `"gamerun"` / `"gamerun "`
yazılıydı — `%command%` yok. Her satır `gamerun %command%` olmalı.

## Mimari özet

2 Eyl 2026'dan beri gamemode zincirde DEĞİL (kök neden 2):

```
Steam (iGPU'da açılır)
  └─ launch options: gamerun %command%   (FHS kum havuzunda /usr/bin/gamerun — 10 Ağu)
       │
       ├─ 0. argüman yoksa HATA VER (=%command% unutulmuş; eskiden sessizdi)
       │
       ├─ 1. dGPU PRIME offload — GL/EGL tarafı, nixpkgs `nvidia-offload` üçlüsü:
       │     __NV_PRIME_RENDER_OFFLOAD=1 + _PROVIDER=NVIDIA-G0 + __GLX_VENDOR_LIBRARY_NAME=nvidia
       │     (Vulkan cihaz SAYIMINA dokunmaz → "sıfır cihaz görüp kapanma" riski yok)
       │
       ├─ 2. Vulkan cihaz seçimi: VARSAYILAN KARIŞMAZ (DXVK zaten ayrık GPU'yu seçer)
       │     GR_GPU=nvidia → yalnız dGPU | GR_GPU=igpu → yalnız iGPU  (opt-in, filtreler)
       │
       ├─ 3. taskset -c 0-15 — cores.nix'in Zen5c-only masaüstü maskesini del
       │     GR_PIN=big/fast/liste ile daralt · maske geçersizse UYAR ve devam et (ilke A)
       │
       ├─ 4. GR_CPUMAX=1 ise $XDG_RUNTIME_DIR/gamerun-cpumax işaretini bırak
       │
       ├─ 4b. SIZINTI SIFIRLAMASI (12 Eyl 2026): ölü PID kayıtlarını sil; canlı örnek
       │      KALMADIYSA ve game-perf hâlâ "active" ise önce STOP (oneshot+RemainAfterExit
       │      → aktif birime `start` ExecStart'ı yeniden koşturmaz).
       │
       ├─ 5. systemctl start game-perf.service   ← DOĞRUDAN (polkit), referans sayaçlı
       │        ├─ scx_lavd --performance
       │        ├─ AC'deyse fan_mode turbo
       │        ├─ AC'deyse PPD → balanced (GPU-öncelik; gamerun-cpumax varsa performance)
       │        └─ AC'deyse WMBD 0xED profil 2: ACBT 160 + agresif fan eğrisi
       │           (KCD ölçümü: GPU 38W→62-83W sustained, ort. ~70W; fan %32-35→%46-49)
       │           ⚠ SIRA ZORUNLU: 0xED, PPD'DEN SONRA. Gerekçe aşağıda.
       │
       └─ 6. oyunu ARKA PLANDA çalıştır + wait  (exec DEĞİL — trap koşabilsin)
             ├─ INT/TERM/HUP → oyuna ilet (Steam'in "Durdur" düğmesi çalışsın)
             └─ ÇIKIŞTA: kendi PID kaydını sil; başka CANLI gamerun yoksa
                systemctl stop game-perf.service
                  → scx durur (EEVDF döner) +
                    aero-power-profile (fan modu AC→responsive / BAT→balanced, ACBT geri) +
                    platform_profile → balanced (fişte) / low-power (pilde) +
                    power-display (PPD + 4.5 GHz tavanı + affinity maskesi)
```

### 0xED'in İKİ yazıcısı var (12 Eyl 2026 — üç ayrı arızanın ortak kökü)

7 Eyl'de gelen `aero_eg61h` sürücüsü **`platform_profile` handler'ı** olarak kayıtlı
ve aynı WMBD 0xED register'ını yazıyor (`kernel/aero-profile.c`):

| platform_profile | WMBD 0xED | ATPP | ACBT | AC PL1/PL2/PL3 |
|---|---|---|---|---|
| `low-power` | 0 | 0xA0 | 0 (kapalı) | 20/65/65 W |
| `balanced` | 1 | 0xC8 | 0x50 | 25/65/80 W |
| `performance` | 2 | ECPL | 0xA0 (en üst) | 30/80/80 W |

PPD `/sys/firmware/acpi/platform_profile`'a yazıyor, çekirdek onu **tüm handler'lara**
dağıtıyor. Ölçüm (12 Eyl):

```
powerprofilesctl set performance
  → platform-profile-0 (aero_eg61h) = performance   ← 0xED 2 yazıldı
  → platform-profile-1 (amd-pmf)    = performance
```

Üç sonucu vardı, üçü de düzeltildi:

1. **Oyun profili eziliyordu.** Eski sıra `0xED 2` → `PPD balanced`; ikinci adım
   handler üzerinden `0xED 1` yazıyordu — 7 Eyl'den beri oyun profili birkaç ms
   yaşıyordu. **Sıra ters çevrildi.**
2. **Çıkışta EC en kısıtlı profilde kilitleniyordu.** `gamePerfStop` ham `0xED 0`
   yazıyordu; `power-display`'in `ppd_apply balanced`'i PPD zaten balanced olduğu için
   no-op'a düşüyordu (`power-display.nix`, 2026-07-27 ölçümü) → ACBT kapalı, AC PL1
   20 W, sysfs "balanced" diye yalan söylüyordu. **Ham yazım kaldırıldı**, standart
   `platform_profile` düğümüne yazılıyor.
3. **Sürücü önbelleği oyun sırasında bayat.** 0xED'in geri okuması yok; oyun boyunca
   sysfs "balanced", EC 2'de. Bilinçli; çıkışta senkronlanıyor.

**Referans sayacı:** iki oyun açıkken biri kapanınca diğerinin fanı düşmesin diye her
örnek `$XDG_RUNTIME_DIR/gamerun.d/<pid>` bırakır; yalnız canlı başka örnek kalmadıysa
servis durur. Ölçüldü 2 Eyl 2026: kısa örnek biterken `fan_mode` 5'te kaldı, uzun
örnek bitince düştü.

**Turbo fan (2026-07-17):** oyun süresince (AC'de) `fan_mode turbo` (~6900 RPM). CPU
yine **~95°C** olur (EC/SMU tavanı; bkz. `Documentation/aerox16/wmi-ec.md` preset
karakterizasyonu) ve **seslidir** — kullanıcı tercihi: "oyunlarda her zaman soğuk".
Pilde uygulanmaz. Oyun bitince `aero-power-profile.service` fanı AC'de `responsive`,
pilde `balanced` yapar. Turbonun eşi 0xED profil 2 (ACBT 80→160 + agresif fan eğrisi) —
ölçüm (6 Tem 2026, KCD A/B): GPU 38W→62-83W sustained (86-87°C'de ~70W ort.), fan duty
%32-35→%46-49. Ham kayıt: `Documentation/aerox16/wmi-ec.md` "Deneysel 0xED / 0xF1–F3
logu", 07-06 satırı.

**Düzeltme (10 Ağu 2026):** `aero-power-profile` fiş/uyanışta koşulsuz fan modu
yazıp oyun ortasında turboyu düşürüyordu; artık `game-perf` aktifken fan modunu
yazmıyor (ACBT/boost kolu AC/BAT'a göre devam).

**Düzeltme (12 Eyl 2026) — turbo takılı kalıyordu, iki bağımsız neden:**

- *Ölü birim adı.* `gamePerfStop`, 7 Eyl'de yeniden adlandırılan birimi eski adıyla
  çağırıp hatayı `|| true` ile yutuyordu (journal, üç kapanış:
  `Failed to start gigabyte-power-profile.service: Unit ... not found.`). Fan reboot'a
  kadar turbo'da kalıyordu; AERO Kontrol'de hiçbir ön ayar seçili görünmüyordu (GUI'de
  artık "Custom").
- *Yapışkan oyun istisnası.* `game-perf` `Type=oneshot` + `RemainAfterExit=true`;
  gamerun SIGKILL edilirse birim süresiz "active" kalır ve `aero-power-profile` ile
  `power-display` fan/affinity yazmayı atlar. İki olay tetikli ağ eklendi (poll yok):

| ağ | nerede | ne zaman |
|---|---|---|
| gamerun sıfırlaması | `lib/gamerun.nix` 4b | her oyun açılışında, kendi kaydından önce |
| `game-perf-reap.service` | `system/kernel/sched.nix` | udev (ACAD) + uyanış |

İkisi de aynı testi yapar: canlı PID kalmadıysa → `systemctl stop game-perf.service`.

Donanım tarafı AC'ye bağlı otomatik: fan modu 2 + NPCF.ACBT 80W → nvidia-powerd
dGPU'yu 75–85W bandına çıkarır (`system/arch/aerox16/wmi.nix`). VRR: COSMIC'te panel
`Adaptive Sync: automatic` bildirdi (11 Eyl 2026, `cosmic-randr list`); ayar
masaüstünün kendisinde yaşar, repo dokunmaz. Pilde panel 60Hz'e çekilir
(`power-display-user`, power-display.nix).

**GPU-öncelik: oyunda PPD balanced (18 Tem 2026).** CPU ile dGPU ACBT 80W'lık Dynamic
Boost bütçesini **paylaşır**. PPD `performance`'ta amd-pmf CPU'ya en yüksek STAPM
preset'ini basar → CPU 100°C Tjmax'te bütçeyi yer → dGPU ~30W'a düşer (tavan 85W →
**açlık**, güç limiti değil). `balanced`'ta bütçe dGPU'ya kayar → GPU-bound oyunda daha
çok watt + FPS. CPU-bound oyun (sim/strateji, KCD kalabalık şehir) için `GR_CPUMAX=1`.
Undervolt bu makinede platform-kilitli (`Documentation/aerox16/undervolt.md`);
güç iştahını kısmak tek kol. 100°C by-design (Zen5 mobil Tjmax hedefi).

**Pilde oyun:** tasarım gereği kısıtlı — CPU 2GHz tavan + boost kapalı + ACBT 0. İdle
tabanı (4.28W) etkilenmez: boşta scx inactive, zram pasif, gamemoded uykuda.

## Launch options matrisi

**`%command%` ZORUNLU** — içermeyen dize sarmalayıcı sayılmaz, oyunun argümanı olarak
sonuna eklenir (`oyun.exe gamerun` diye açılır, gamerun hiç koşmaz).

### gamerun'ın KENDİ anahtarları (`GR_*`) — hepsi bu kadar (2 Eyl 2026)

| Amaç | Launch options |
|---|---|
| **Taban** — dGPU offload + `taskset -c 0-15` + game-perf zinciri | `gamerun %command%` |
| Yalnız dGPU görünsün (oyun iGPU'ya düşüyorsa) | `GR_GPU=nvidia gamerun %command%` |
| Yalnız iGPU görünsün (hafif oyun, dGPU'yu uyandırma) | `GR_GPU=igpu gamerun %command%` |
| Tek-çekirdeğe bağımlı sim (HOI4/Stellaris/Factorio) | `GR_PIN=big gamerun %command%` |
| En hızlı iki çekirdek + SMT | `GR_PIN=fast gamerun %command%` |
| Özel CPU listesi (`taskset -c` biçimi) | `GR_PIN=0,2,4 gamerun %command%` |
| CPU tam güç (CPU-bound oyun; varsayılan balanced/GPU-öncelik) | `GR_CPUMAX=1 gamerun %command%` |
| **Arıza ikilemesi:** perf zincirini hiç kurma (yalnız offload+taskset) | `GR_NOPERF=1 gamerun %command%` |
| gamerun'ın kendi loglarını sustur | `GR_QUIET=1 gamerun %command%` |

`GR_NOPERF=1`: "oyun açılmıyor"da suçluyu ikiye böler — açılıyorsa sorun perf
zincirinde (systemd/polkit), açılmıyorsa gamerun'la ilgisi yok.

gamerun stderr'e tek satır banner basar (`gamerun: başlıyor — CPU=… GPU=… perf=…`); bu
Steam'in `console-linux.txt`'sine düşer → "gerçekten koştu mu?" logdan okunur.

`GR_PIN`: `big` = 4× Zen5 5.09GHz (Zen5c 3.5GHz dışarıda), `fast` = yalnız cpu4/6+SMT
(iki firmware sıralaması da bu dörtlüyü işaret ediyor: CPPC 208, ITMT 203). Zamanlayıcı
Zen5/Zen5c ayrımını **biliyor** (16 Ağu 2026: `amd_hfi` bağlı, ITMT açık,
`sched_core_priority` Zen5'te 196/203, Zen5c'de 135; kanıt
`Documentation/aerox16/cpu-hybrid.md`) — 0-15 havuzunda ITMT tek-thread işi zaten
Zen5'e yönlendiriyor. `GR_PIN=big`, ITMT'nin yalnız *tercih* olmasına karşı garanti;
sim oyunlarında dene, ama önce GR_PIN'siz ölç.

### Oyuna özgü env'ler — gamerun'a DEĞİL, doğrudan launch options'a

2 Eyl 2026'da gamerun'dan çıkarıldı (ilke C); gamerun'la ve gamerun'sız aynı çalışır,
OptiScaler ile birlikte kullanılabilir.

| Amaç | Launch options |
|---|---|
| ntsync'i zorla aç / kapat | `PROTON_USE_NTSYNC=1 gamerun %command%` / `=0` |
| DLSS NGX updater (en yeni DLL) | `PROTON_ENABLE_NGX_UPDATER=1 gamerun %command%` |
| DLSS SR / RR override | `DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on gamerun %command%` |
| DLSS Frame Generation override | `DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on gamerun %command%` |
| MFG 4x | `DXVK_NVAPI_DRS_NGX_DLSSG_MODE=on DXVK_NVAPI_DRS_NGX_DLSSG_MULTI_FRAME_COUNT=3 gamerun %command%` |
| Dinamik MFG — 165 FPS hedef | `DXVK_NVAPI_DRS_NGX_DLSSG_MODE=dynamic DXVK_NVAPI_DRS_NGX_DLSSG_DYNAMIC_TARGET_FRAME_RATE=165 gamerun %command%` |
| DLSS render preset'i zorla | `DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest gamerun %command%` |
| Smooth Motion (DLSS'siz oyuna sürücü framegen; FG/MFG ile BİRLEŞMEZ) | `NVPRESENT_ENABLE_SMOOTH_MOTION=1 gamerun %command%` |
| Düşük gecikme kare tempolama (yalnız Proton-CachyOS; FG ile birleşmez) | `PROTON_DXVK_LOWLATENCY=1 PROTON_VKD3D_LOWLATENCY=1 DXVK_FRAME_PACE=low-latency-vrr-165 gamerun %command%` |
| Proton Wayland (deneysel) | `PROTON_ENABLE_WAYLAND=1 gamerun %command%` |
| NVIDIA GL disk shader cache (kalıcı, ~12GB) | `__GL_SHADER_DISK_CACHE=1 __GL_SHADER_DISK_CACHE_PATH=$HOME/.cache/nv __GL_SHADER_DISK_CACHE_SIZE=12000000000 gamerun %command%` |
| **Blackwell:** DX12 bir süre sonra donarsa → VKD3D cache kapat (#2793) | `VKD3D_SHADER_CACHE_PATH=0 gamerun %command%` |
| **Blackwell:** Xid 109 sert çökme fix (o oyuna Proton-CachyOS seç) | `PROTON_VKD3D_HEAP=1 gamerun %command%` |
| **Blackwell:** ham VKD3D_CONFIG | `VKD3D_CONFIG=dxr11 gamerun %command%` |

**Geri gelmeyecek tek şey `DXVK_NVAPI_VKREFLEX=1`** — gereksiz uyumluluk katmanının
anahtarı (kök neden 1). Reflex için hiçbir şey yazma.

Önceki varsayılanların tarihi: 17 Tem 2026'da FG override, `render_preset` ve ntsync
zorlaması opt-in'e alınmıştı (zorla FG Tsushima'da "GPU kare basmayı durduruyor"
yapıyordu; ntsync zorlaması GE'nin per-game blocklist'ini eziyordu); 2 Eyl'de SR/RR
dahil hepsi gamerun'dan çıktı.

**Pencere modu:** gamerun hiçbir pencere argümanı eklemez (`GR_WIN` 2 Eyl 2026'da
kaldırıldı — Proton komut satırının sonuna `-w/-h/-screen-*` eklemek ölçülmemiş kazanç
için "açılmıyor" riskiydi). Çözünürlük/pencere oyunun kendi config'inden gelir
(FromSoft `GraphicsConfig.xml`, HOI4 `settings.txt`, Hogwarts `GameUserSettings.ini`,
KCD `user.cfg`, RE Engine `config.ini`). Bunlar daha önce windowed'a çevrilmişti; tam
ekran için `*.bak` yedeklerinden geri al.

**Öncelik — DÜZELTİLDİ 2 Eyl 2026.** Bu bölüm 18 Tem'den beri "oyun `renice -20`
koşuyor" diyordu; Steam yolunda hiç doğru olmamış (kök neden 2). Artık renice/ioprio
**hiçbir yolda** uygulanmıyor; gecikme kolu **scx_lavd `--performance`**.
`programs.gamemode` açık kalıyor: gamemode API'sini kendisi çağıran oyunlar için yedek
yol (`sched.nix`'teki "OTORİTE DEĞİŞTİ" bloğu). **RT (SCHED_FIFO/RR) bilinçli olarak
kullanılmadı:** sched_ext'in üstünde koşup scx_lavd'ı bypass eder, busy-loop'ta makineyi
kilitleyebilir.

**Blackwell (RTX 5060) DX12/VKD3D kaçış bayrakları (opt-in, 22 Tem 2026)** — şu an
sorun yok, gerektiğinde oyun başına aç:

- **`VKD3D_SHADER_CACHE_PATH=0`** — bazı DX12 oyunları dakikalar–saatler sonra donuyor
  (vkd3d-proton **#2793**, Ocak 2026; RTX 4070 ve 5070 doğrulanmış). Bedeli ilk-render
  shader stutter'ı → yalnız donan oyunda.
- **`PROTON_VKD3D_HEAP=1`** (VK_EXT_descriptor_heap) — shader derleme fazında **Xid 109
  sert çökmesi** (vkd3d-proton **#2914** / PR #2805; ör. Crimson Desert). Yalnız
  Proton-CachyOS'ta etkin; GE-Proton'da zararsız no-op.
- **`VKD3D_CONFIG=<token>`** — ham passthrough (`dxr11`, `force_raw_va_cbv`, vb.).

**Proton-CachyOS (22 Tem 2026):** `usr/steam.nix` GE-Proton'un **yanına**
Proton-CachyOS'u kurar (`chaotic-nyx` input + `nyx-cache.chaotic.cx`). GE-Proton
varsayılan; inatçı DX12/Blackwell oyunlarında (Xid 109, #2793) Steam'de oyun başına
Proton-CachyOS + `PROTON_VKD3D_HEAP=1`. Alternatif: Proton Experimental / Proton 11.

**Oyunları Vulkan'a taşıma (kullanıcı uygular):**
- **HOI4 (ve Paradox / native-OpenGL oyunları):** Steam → Uyumluluk → GE-Proton (veya
  Proton-CachyOS) zorla → D3D11→DXVK→Vulkan (5060'ta daha stabil). Tek-thread sim →
  `GR_PIN=big gamerun %command%`.
- **Paradox Launcher (launcher-v2) beyaz/boş pencere (30 Tem 2026):** Electron/CEF
  launcher (`--use-angle=gl`) Wine altında donanım GL ile açılıyor; bu hibritte +
  Xwayland'de GL context kompozisyona düşmüyor → kalıcı beyaz pencere, log/Crashpad
  yok. Düzeltme: `LIBGL_ALWAYS_SOFTWARE=1 %command%`. **gamerun'la birlikte (2 Eyl
  2026'dan beri)** satıcı da çevrilmeli, yoksa no-op (ölçüldü, `glxinfo -B` hâlâ RTX
  5060): `__GLX_VENDOR_LIBRARY_NAME=mesa LIBGL_ALWAYS_SOFTWARE=1 GR_PIN=big gamerun %command%`
  (ölçüldü → `llvmpipe`). Oyunun kendisi DXVK→Vulkan koştuğu için (prefix'te taze
  `.dxvk.bin`/`.dxvk.lut` doğrulandı) yalnız launcher arayüzü CPU'da render olur. Aynı
  belirti Epic/GOG Galaxy gibi başka launcher'da görülürse ilk şüpheli bu. **Tuzak:**
  launcher'ın 127.0.0.1:11000 tek-örnek kilidi — beyaz pencere dururken "Play" eski
  pencereyi öne getirir, yeni launch option'ı görmez; önce Steam'den Durdur (ya da
  `reaper SteamLaunch AppId=<id>` sürecini öldür).
- **Minecraft:** VulkanMod (Fabric) native Vulkan verir; offload `mc-run`→`gamerun`'dan
  miras, `__GL_THREADED_OPTIMIZATIONS=0` VulkanMod'da etkisiz-zararsız.

## Minecraft (Prism Launcher)

*Kurulum: 2026-07-15 · `home/apps/minecraft.nix` (HM katmanı)*

Prism her instance'ı **Wrapper Command** üzerinden başlatır:

```
Prism Launcher (iGPU'da açılır)
  └─ WrapperCommand=mc-run → __GL_THREADED_OPTIMIZATIONS=0 export → exec gamerun
       └─ gamerun java -Xmx8192m <G1 bayrakları> ...
            ├─ dGPU PRIME offload (RTX 5060) — MC OpenGL, GLX vendor=nvidia ŞART
            │  (2 Eyl 2026'ya kadar opt-in'in arkasındaydı → MC iGPU'da koşuyordu; kök neden 3)
            ├─ taskset -c 0-15 (Zen5c masaüstü maskesini del)
            └─ systemctl start game-perf.service   ← DOĞRUDAN (gamemode yok, 2 Eyl 2026)
                 └─ scx_lavd + AC'deyse turbo fan + PPD balanced + 0xED profil 2 (PPD'den SONRA)
                    (Steam'dekiyle aynı; GR_CPUMAX=1 ile performance)
```

**FPS düzeltmesi — `__GL_THREADED_OPTIMIZATIONS=0` (17 Tem 2026):** NVIDIA sürücüsü
Prism'den başlatılan MC'yi tanımadığından threaded-GL optimizasyonu yanlış devreye
girip FPS düşürüyordu (Sodium wiki Driver-Compatibility + issue #1830). `mc-run` bunu
**yalnız MC'ye** verir (bazı OpenGL oyunlarında ters etki yapar).

**Java:** nixpkgs sarmalayıcısı jdk8/17/21/25'i `PRISMLAUNCHER_JAVA_PATHS` ile sunar,
`AutomaticJavaSwitch=true` sürüme göre seçer (1.8→8, 1.17+→17, 1.20.5+→21). Prism'in
Java indirmesi KAPALI (`AutomaticJavaDownload=false`): generic binary NixOS'ta çalışmaz.

**JVM bayrakları — Aikar seti (global `JvmArgs`, `prismlauncher.cfg`; 18 Tem 2026):**
`-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch
-XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M
-XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem
-XX:MaxTenuringThreshold=1` — Java 8→25 hepsinde geçerli (ZGC 21+ olduğundan global
konamaz).

**Neden (periyodik hitch fix):** hitch hem VulkanMod hem Sodium'da görülüyordu → **GC
kaynaklı**. Eski set: `MinMemAlloc=512`/`MaxMemAlloc=8192` uçurumu (sürekli heap
resize) + `MaxGCPauseMillis=50` (çok sık küçük GC). Yeni: **sabit heap** (Min=Max=8192)
+ `+AlwaysPreTouch` + `MaxGCPauseMillis=200`. 8192 MiB 32 GB RAM'de güvenli; ağır
modpack'te instance başına yükselt. VulkanMod'un ilk-render pipeline derleme hitch'i
JVM'den bağımsızdır, tam gitmeyebilir.

**Shader + Distant Horizons:** DH LOD arazisi yalnız **DH-uyumlu shader**'da gölgelenir
(Complementary Reimagined/Unbound, Bliss 2.1+, Photon, Shrimple). Uyumsuz shader (ör.
Voyager) + DH = dikiş + flicker + bozulma. Shader seçimi kullanıcıda; env/wrapper/bellek
bu modülde.

**Yapılandırma deklaratif:** `prismlauncher.cfg` her `hms`'te store kopyasıyla tazelenir
(vesktop'taki mutable-copy deseni) → kalıcı *global* ayar `home/apps/minecraft.nix`'e
işlenmeli. Hesaplar (`accounts.json`) ve instance'lar etkilenmez.

Doğrulama (instance açıkken, AC'de):
```bash
systemctl is-active game-perf scx   # active / active
nvidia-smi                          # java süreci dGPU'da, yükte watt artar
```

## Oyun-içi ölçüm (MangoHud kaldırıldı, 22 Tem 2026)

MangoHud oyun ile Vulkan sürücüsü arasına giren bir katmandı (burada segfault geçmişi:
gamescope `--mangoapp` coredump) → kaldırıldı. Ölçüm **dış araçla**:

- **`nvtop`** (2. terminal) — iGPU + dGPU: watt, clock, util, VRAM, süreç→GPU eşlemesi.
- **`nvidia-smi dmon`** — dGPU saniyelik telemetri; **`nvidia-smi`** — Dynamic Boost
  watt tavanı doğrulaması.
- **FPS/frametime:** oyunun kendi sayacı (VulkanMod/Sodium F3, motor overlay'leri) veya
  `PROTON_LOG=1` + `~/steam-<appid>.log` içindeki dxvk/vkd3d init satırları.

## RTX 5060 özellik durumu (DLSS 4.5, Linux/Proton)

2 Eyl 2026'dan beri hiçbiri `gamerun` varsayılanı değil — hepsi oyun başına launch
options'a yazılır ("Oyuna özgü env'ler" tablosu).

| Özellik | Destek | Nasıl |
|---|---|---|
| DLSS SR (2. nesil transformer) | ✔ tüm RTX | `DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on` (ya da oyun menüsü) |
| DLSS Ray Reconstruction | ✔ | `DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on` |
| DLSS render preset (en yeni) | ✔ | `DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest` |
| DLSS Frame Generation | ✔ (oyun desteği şart) | `DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on`; oyun menüsünden de aç |
| Multi Frame Gen 2x–6x | ✔ RTX 50'ye özel | `DXVK_NVAPI_DRS_NGX_DLSSG_MODE=on` + `..._MULTI_FRAME_COUNT=<N-1>` |
| Dynamic MFG (hedef FPS) | ✔ RTX 50'ye özel | `DXVK_NVAPI_DRS_NGX_DLSSG_MODE=dynamic` + `..._DYNAMIC_TARGET_FRAME_RATE=165` |
| Reflex (VK_NV_low_latency2) | ✔ | **hiçbir şey yazma** — sürücü yerlisini veriyor (`vulkaninfo`: revision 2). `DXVK_NVAPI_VKREFLEX=1` YAZMA (rev-1 uyumluluk katmanı, donmalar) |
| ntsync (Proton NT senkron) | ✔ | `PROTON_USE_NTSYNC=1` / `=0` (varsayılan: Proton karar verir) |
| Smooth Motion (sürücü framegen) | ✔ RTX 50 | `NVPRESENT_ENABLE_SMOOTH_MOTION=1` — yalnız FG'siz oyunlarda |
| NGX güncelleyici (DLL OTA) | ✔ | `PROTON_ENABLE_NGX_UPDATER=1` → prefix `ProgramData/NVIDIA/NGX/` |

**Kurallar:**
- **Smooth Motion ile oyun-içi FG/MFG asla birlikte** (resmî uyarı: artefakt + düşük
  performans). Eskiden gamerun bunu zorluyordu; artık zorlayan yok.
- FG/MFG yalnız DLSS-FG içeren oyunlarda; içermeyenlerde Smooth Motion.
- DLSS override'ları **OptiScaler ile çakışır** (aynı NGX/nvapi katmanı) — OptiScaler'lı
  oyunda DLSS satırlarını yazma.

## 860M (iGPU) FSR4 durumu — 30 Tem 2026 araştırması

AMD resmî olarak RDNA 3.5 iGPU'lara (890M/880M/**860M**/840M) FSR 4.1 "planlamıyor";
pratikte Proton-CachyOS (protonfixes `upscalers.py` + AMD sunucusundan çekilen gerçek
`amdxcffx64.dll` 4.1.1) bunu çalıştırıyor:

- **Native FSR4 oyunlar** (Resident Evil Requiem, PRAGMATA, KCD2 —
  `amd_fidelityfx_loader_dx12.dll` + `amd_fidelityfx_upscaler_dx12.dll` taşıyanlar): ek
  ayar gerekmez; menü "FSR 3.1.x" dese de sürücünün FSR4 modeli sessizce araya giriyor.
- **Native olmayanlar** (KCD1, Ghost of Tsushima, Hogwarts Legacy): **OptiScaler**
  enjeksiyonu (`dxgi.dll` kılığında; FSR4 paketini `umu/` altına indirir).

**Çalışan tarif (yalnız upscale, FG yok) — iki türde de aynı:**
```
PROTON_USE_OPTISCALER=1 PROTON_FSR4_UPGRADE=1 PROTON_OPTISCALER_CONFIG="Spoofing.Dxgi=false" %command%
```
`Spoofing.Dxgi=false` şart — yoksa OptiScaler sahte GPU kimliği bildiriyor (görülen:
"AMD Radeon RX 6700 XT / 7.96GB VRAM"), oyun gerçek donanımla (860M, 512MB dedike VRAM
carveout) uyuşmayan kaynak yüklüyor.

**`hidenvgpu` (STEAM_COMPAT_CONFIG) TAM gizlemiyor:** `WINE_HIDE_NVIDIA_GPU=1` yalnız
DXGI/D3D listelemesini etkiliyor; oyun NVAPI/Streamline üzerinden dGPU'yu bulup
kullanabiliyor (kanıt: `nvidia-smi`, hidenvgpu oturumunda `re9.exe` RTX 5060'ta 5.8GB).
İlk FSR4 sonuçları (RE Requiem 90 FPS, Tsushima 60 FPS) bu yüzden **NVIDIA kirliliğiyle
şişmişti**. Blacklist de yetmiyor (bazı servisler `modprobe`'u açıkça çağırıyor); temiz
ölçüm için `boot.extraModprobeConfig`'de `install nvidia /bin/false` (+ diğer 3 modül),
`nvidia-powerd.service` kapalı + reboot gerekti (o dönemin compositor'ı NVIDIA DRM
cihazını tuttuğu için canlı `modprobe -r` düşmüyordu).

**Gerçek 860M performansı (NVIDIA çekirdekten tamamen kaldırılmış, max ayar):** RE
Requiem ve Tsushima **30-45 FPS** — kirli 90/60 değil. 12 CU iGPU için oynanabilir;
teorik tahminle (dGPU'ya 3-6× çıplak güç farkı, FSR4 kapatmaz) tutarlı.

**Frame Generation — ÇALIŞMIYOR, vazgeçildi.** Sırayla denenen, hiçbiri kararlı değil:
- `Spoofing.StreamlineSpoofing=false` → hâlâ yanlış GPU + parlama (FG açıkken)
- `FrameGen.fginput=fsrfg` → ana menüden parlama + oyunda tam çökme (Wine SEH/unwind)
- Prefix `Version=win11` + `PROTON_MLFG_UPGRADE=1` → çökme yerine 14-15 FPS
- `FSR.Fsr4ForceEnableInt8=true` (RDNA3/3.5 mobil FP8→INT8) → düzelmedi

Sonuç: RDNA 3.5 iGPU + OptiScaler + Linux'ta FG güvenilir değil; yalnız upscale.

## Düşük gecikme kare tempolama (31 Tem 2026 · anahtar değişti 2 Eyl 2026)

`GR_LL=1` 2 Eyl 2026'da kaldırıldı; üç env doğrudan yazılır:
`PROTON_DXVK_LOWLATENCY=1 PROTON_VKD3D_LOWLATENCY=1 DXVK_FRAME_PACE=low-latency-vrr-165 gamerun %command%`

Proton-CachyOS **11.0-20260703** (pinli sürüm, 22 Tem 2026'da yayınlandı)
netborg-afps'in iki eklentisini getirdi — store'daki `version` dosyalarından doğrulandı:

```
files/lib/wine/dxvk/version              dxvk (v3.0.2-2)                 ← D3D11 tabanı
files/lib/wine/dxvk-low-latency/version  low-latency-framepacing-2.7.1   ← PROTON_DXVK_LOWLATENCY
files/lib/wine/vkd3d-low-latency/version vkd3d-low-latency initial-rel.  ← PROTON_VKD3D_LOWLATENCY
files/lib/wine/vkd3d-proton/version      vkd3d-proton (vkd3d-1.1-5438)
```

**GE-Proton11-1'de bu env'ler YOK** (`grep PROTON_.*LOWLATENCY proton` boş) → o oyuna
Proton-CachyOS seçilmezse sessizce no-op.

Reflex API'sini çeviri katmanının içinde uygular (`VK_NV_low_latency2`'ye çevirmeden) +
Waitable DXGI Swapchain ile tempolar. `low-latency-vrr-165` v-blank'i hesaba katar;
165 Hz panel + tam ekran VRR ile uyumlu. Başka hedef:
`DXVK_FRAME_PACE=low-latency-vrr-120 PROTON_DXVK_LOWLATENCY=1 gamerun %command%`.

**Neden opt-in (üstakım README'sindeki sınırlar):**

| Sınır | Sonuç |
|---|---|
| Frame Generation **desteklenmiyor** | DLSSG (FG/MFG) env'leriyle aynı satıra yazma |
| Oyun Reflex marker'ı (Simulation Start + Present Begin) göndermeli, ya da Waitable Swapchain kullanmalı | Desteklemeyen oyunda **hiçbir etkisi yok** |
| Kareler `dxgi.present()` öncesi CPU'da örtüşmüyor | CPU-bound sahnede **tavan FPS düşebilir** |
| D3D12 tarafı "initial-release" | VRR pacing modu D3D12'de henüz yok (planlı) |
| Intel GPU / AMD Anti-Lag 2 | Desteklenmiyor — bizde ilgisiz (NVIDIA offload) |

**Ölçüm:** FPS değil **gecikme** — aynı sahnede env'li/env'siz input→ekran hissini
karşılaştır; `nvidia-smi dmon` ile GPU kullanımının düşmediğini teyit et (düşüyorsa
CPU-bound sınır, o oyunda kapat).

Kaynaklar: [vkd3d-low-latency](https://github.com/netborg-afps/vkd3d-low-latency) ·
[dxvk-low-latency](https://github.com/netborg-afps/dxvk-low-latency) ·
[proton-cachyos 11.0-20260703](https://github.com/CachyOS/proton-cachyos/releases/tag/cachyos-11.0-20260703-slr) ·
[GamingOnLinux duyurusu](https://www.gamingonlinux.com/2026/07/proton-cachyos-adds-support-for-vkd3d-low-latency-upgrades-d7vk-and-more/)

**DXVK 3.0.2 zaten aktif** (25 Haz 2026, Proton güncellemesiyle): dxbc-spirv derleyicisi;
bazı oyunlarda ~1 GiB daha az bellek, shader derleme tamamen worker thread'lerde.
[DXVK 3.0 duyurusu](https://www.phoronix.com/news/DXVK-3.0-Release)

## 31 Tem 2026 — donanım-performans denetimi (CPU/iGPU/dGPU/RAM/SSD/NPU)

Araştırma + canlı doğrulama. Sonuç: parça başına zaten iyi ayarlı.

**Radeon 860M / Mesa:** canlı **Mesa 26.1.5** (RADV KRACKAN1). 860M'nin darboğazı RT
değil ham CU sayısı (FSR4 bulgusuyla birlikte oku); 26.1.6 (29 Tem) yalnız bakım sürümü.

**RTX 5060 / Dynamic Boost:** nvidia-powerd canlıda sağlıklı (D-Bus bağlı); tek
yinelenen log SBIOS'un "DC controller"ı (pil modu) kapatması — boost mantığı zaten AC'ye
kilitli, muhtemelen zararsız. Kanıt sürüm numarası değil, zincir: ACBT WMI yazımı (0x4C,
aero-power-profile) → nvidia-powerd → GPU tavanı, KCD'de **38W→62-83W** (ort. ~70W;
23 Eyl 2026'da ham kayda — wmi-ec.md 0xED logu — göre düzeltildi, eskiden 70-83W). Bu,
jenerik "Dynamic Boost AMD CPU'da çalışmıyor" sınırından (open-gpu-kernel-modules
**#392**, 2022'den beri açık) bağımsız: kazanç WMI yan-kanalından geliyor. Sürüm
avcılığına gerek yok.

**CPU / amd-pstate prefcore (16 Ağu 2026'da düzeltildi; 10 Ağu sonucu yanlıştı):**
`amd_pstate=active` doğru; `prefcore = disabled` HFI'li tasarımlarda upstream'in kasıtlı
davranışı (*"cpufreq/amd-pstate: Disable preferred cores on designs with workload
classification"*). Sıralamayı HFI veriyor (`amd_hfi` → `AMDI0104:00`, ITMT açık).
10 Ağu'daki "zamanlayıcıya ulaşmıyor" sonucu kaldırılmış
`/proc/sys/kernel/sched_itmt_enabled` yoluna bakmaktan doğdu (arayüz
`/sys/kernel/debug/x86/`, root). scx_lavd Zen5/Zen5c kapasite farkından habersiz —
`cores.nix` maskesi ve gamerun'ın `taskset`/`GR_PIN` kolu bu yüzden var. Kanıt:
`Documentation/aerox16/cpu-hybrid.md`.

**NPU (XDNA2):** oyun/upscaling'de kullanımı yok; `power.nix`'teki
`boot.blacklistedKernelModules = [ "amdxdna" ]` doğru karar.

**DDR5 — zaten optimal:** `sudo dmidecode`: 2× 16GB Micron/Crucial `CT16G56C46S5`
SODIMM, gerçek dual-channel, **5600 MT/s @ 1.1V = parçanın JEDEC anma hızı** (seri
JEDEC-only, EXPO yok). Fiziksel dizi 64GiB'a kadar (32GiB kurulu). BIOS FB0A (28 May
2026)/EC 3.10 — EC elle tersine mühendislik edildiğinden (`Documentation/aerox16/wmi-ec.md`)
BIOS güncellemesi önerilmiyor.

**NVMe:** scheduler = **none**, APST `power/control` = **auto** — ikisi de optimal.

**scx_lavd ↔ scx_rusty otomatik geçiş (UYGULANMADI):** topluluk kalıbı
(blog.foulkes.cloud) GameMode kancalarıyla oyun↔masaüstü zamanlayıcı değiştiriyor. Bu
repo oyun bitince EEVDF'e dönüyor; boşta da koşan ikinci bir sched_ext daemon'ı 4.28W
idle bütçesine ölçülmemiş risk ekler. İstenirse idle watt A/B ile değerlendirilir.

## Doğrulama komutları

```bash
# Kurulum sonrası (bir kez):
ls -l /dev/ntsync                 # crw-rw-rw-
swapon --show                     # zram0 prio 5 + nvme prio -1
sysctl vm.max_map_count           # 2147483642

# gamerun'ı Steam'siz, 5 saniyede sına:
gamerun                            # rc=2 + "%command% EKSİK" uyarısı
gamerun sh -c 'grep Cpus_allowed_list /proc/self/status'   # 0-15 (maske delindi)
gamerun sh -c 'env | grep ^__NV'   # PRIME offload üçlüsü
gamerun sleep 5 &                  # koşarken: aşağıdaki "oyun sırasında" bloğu
                                   # bitince: game-perf inactive + fan_mode responsive
GR_NOPERF=1 gamerun <oyun>         # arıza ikilemesi: perf zinciri olmadan aç

# Steam kum havuzu (10 Ağu / 2 Eyl düzeltmeleri):
rg 'command not found' ~/.local/share/Steam/logs/console-linux.txt | tail   # yeni satır OLMAMALI
rg 'gamerun: başlıyor' ~/.local/share/Steam/logs/console-linux.txt | tail   # HER launch'ta OLMALI
rg 'gamemodeauto: dlopen failed' ~/steam-*.log | tail                       # yeni satır OLMAMALI
taskset -pc <oyun pid>                                                      # 0-15 (GR_PIN yoksa)

# Oyun sırasında (AC'de):
cat /sys/kernel/sched_ext/state /sys/kernel/sched_ext/root/ops   # enabled + scx_lavd
systemctl is-active game-perf scx                                # active / active
cat /sys/bus/wmi/devices/ABBC0F75-*/fan_mode                     # turbo
nvidia-smi                                                       # yükte ≥75W
nvtop                                                            # (2. terminal) dGPU'da oyun süreci + watt/util
# fişi çek/tak veya uykudan dön → fan_mode turbo'da KALMALI

# DLSS init şüphesinde:
PROTON_LOG=1 gamerun %command%    # ~/steam-<appid>.log içinde nvapi/ngx satırları
ls ~/.local/share/Steam/steamapps/compatdata/<appid>/pfx/drive_c/ProgramData/NVIDIA/NGX/

# Oyun kapandıktan sonra:
systemctl is-active scx           # inactive; sched_ext/state → disabled
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor     # PPD yönetiminde (amd-pstate active → powersave+EPP)
```

## Bilinen sınırlar

- `PROTON_ENABLE_WAYLAND=1` Steam Overlay ve Steam Input'u bozar — yalnız test için.
- ntsync varsayılanda zorlanmıyor (Proton/GE per-game blocklist'i karar verir).
- NVIDIA sürücü `nvidiaPackages.latest` (`system/drivers/gpu.nix`) — `nix flake update`
  ile oynayabilir. Geri pinleme: `mkDriver { version + hash }` (gerekçe gpu.nix'te).
- Kernel 7.x + Blackwell'de bilinen s2idle resume hang riski (open-gpu issue #1117);
  dGPU suspend'de D3cold'da olduğundan pratikte atlanıyor — uyandırma takılırsa ilk şüpheli.
- Tearing (`allow_tearing`/immediate) hiçbir oturumda ayarlanmadı ve test edilmedi.
- **Renice (-20) UYGULANMIYOR** (2 Eyl 2026) — bkz. "Öncelik".
- gamescope + MangoHud KALDIRILDI (22 Tem 2026): gamescope bu hibritte çöküyordu (AMD
  iGPU süren + NVIDIA dGPU offload, penceresiz; coredump geçmişi — izolasyon gerekirse
  oyun-içi "unfocused'ta duraklat"ı kapatmak yeterli), MangoHud fazladan Vulkan
  katmanıydı. **Aynı gerekçe 2 Eyl 2026'da `DXVK_NVAPI_VKREFLEX` katmanını da düşürdü**
  — "araya katman koyma" bu makinede tekrar eden bir arıza sınıfı. Yeni Vulkan katmanı
  eklemeden önce bu iki vakayı oku.

## Faz E — Deneysel EC kolları (0xED, 0xF1–F3) · KOŞU BAŞINA ONAY

Amaç: GCC'nin Windows'ta kullandığı iki kolu ölçümle keşfetmek: `0xED` (bütünleşik
performans profili 0–3) ve `0xF1/0xF2/0xF3` (SPL/SPPT/FPPT, mW). Protokol ve log:
`Documentation/aerox16/wmi-ec.md` "Deneysel 0xED / 0xF1–F3 logu".

2026-07-12: SSDT9 PC00→PCI0 düzeltmesiyle **`0x4B` (dGPU TGP set, 75–87 W)** canlı oldu
(`Documentation/aerox16/wmi-ec.md` "SSDT9 PC00→PCI0 düzeltmesi").

**SONUÇ (31 Tem 2026) — 0x4B ve 0xF1-F3 KAPANDI, bir daha denenmeyecek:** SSDT9
initrd'den sağlıklı yükleniyor (dmesg) ve NVRM PSHAREPARAMS spam'i bitti (0 kayıt, eski
32/boot). Ama `0x4B` ve `0xF1/0xF2/0xF3` için **EC yazılan değeri kendisi geri alıyor**.
Fark: `0xED`/`0x4C` (ACBT) EC'nin tanıdığı ön tanımlı modlar arasında seçim — tutuyor
(KCD 38W→62-83W). `0x4B`/`0xF1-F3` EC'nin sürekli yeniden hesapladığı ham limit
alanları — tek seferlik yazım tutmuyor. CPU'nun 21W sürdürülebilir kıskacının kaynağı
bilinmiyor ama bu selector'larla açılmıyor; undervolt/CO kilidiyle
(`Documentation/aerox16/undervolt.md`) aynı tema — mevcut 0xED/ACBT zinciri en iyi
kanıtlanmış kol.

**Güvenlik kartı:**
- EC bu makinede **uçucu**: şarj limiti/fan/ACBT her boot yeniden uygulanıyor → kötü
  değerde **reboot = temiz sayfa**; ACBT için `systemctl start aero-power-profile`.
- Donma/anomali → güç tuşu 15 sn (sert kapanış), gerekirse AC çek.
- SMU korumaları EC isteklerinden bağımsız (CPU zaten 95°C tavanında kıskaçlı) —
  donanım hasarı gerçekçi değil; en kötü bedel kaydedilmemiş iş kaybı.
- **YASAK:** `0x51` (3 = dGPU eject!) ve CMOS/NVRAM'a yazan `0x63, 0x87, 0x88,
  0xA3, 0xE6` (reboot ile SIFIRLANMAZ — uçuculuk güvencesi geçersiz).

**Protokol özeti** (AC + fan_mode 2 + işler kayıtlı):
1. Taban ölç: RAPL 10 sn delta (`/sys/class/powercap/*/energy_uj`), `nvidia-smi dmon`,
   sabit yük (aynı oyun sahnesi 2 dk veya stress-ng) + frametime.
2. **Tek yazım**, sonra ölç, sonra logla:
   `echo '\_SB.PCI0.AMW0.WMBD 0 0xED 1' > /proc/acpi/call` (profil 1'den başla).
   0xF1 için GCC değer uzayında kal: `0xF1 25000` (SPL 25W) → RAPL tepkisi var mı?
3. Geri-okuma: 0xED sonrası NPCF alanları (`ACBT`/`AMAT`, Faz D yöntemi); 0xF1–F3
   geri-okuması RAPL davranışından (Get metodu yok).
4. Geri dönüş: tam temizlik = **reboot**; ACBT restorasyonu = `aero-power-profile`.
5. Abort: RAPL 2 denemede tepkisiz → faz kapat · sürekli >95°C / termal gariplik →
   derhal reboot · input/ekran anomalisi → güç 15 sn.
6. Kanıtlanan kazanç `game-perf.service`'e kalıcı eklenir (oyun-anı kapsamı korunur).
