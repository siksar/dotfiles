# AERO X16 — Oyun Kurulumu ve Kullanımı

*Kurulum: 2026-07-05 · Sürücü: NVIDIA 610.43.02 (open) · Kernel 7.1.1 · DLSS 4.5 dönemi*

## 11 Eyl 2026 — COSMIC varsayılan oturum oldu; dGPU zinciri ÖLÇÜLDÜ, sağlam

Hyprland/Caelestia Eylül 2026'da ağaçtan çıktı, `defaultSession = "cosmic"`.
`system/desktop/cosmic.nix` 2 Eyl'de şu notu taşıyordu: *"COSMIC_DRM_ALLOW_DEVICES
yalnız iGPU'ya izin verdiği için bu oturumda dGPU HİÇ açılmaz, yani gamerun'ın
PRIME offload'ı COSMIC'te çalışmaz."* O not **kapsam dışı bırakılmış bir tahmindi**
ve COSMIC varsayılan olunca kritik hale geldi. Canlı oturumda ölçüldü:

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

**Sonuç:** `COSMIC_DRM_ALLOW_DEVICES` yalnız **compositor'ın** açacağı DRM node'unu
kısıtlar; oyunun kendi süreci Vulkan/NVIDIA sürücüsüne doğrudan gider ve guard'dan
etkilenmez. Yani idle bütçesi (dGPU D3cold) ile oyun offload'ı **aynı anda**
geçerli — biri için diğerinden vazgeçmek gerekmiyor.

**Ölçülmeyen (kalan iş):** gerçek bir Steam oyununun COSMIC altında uçtan uca
açılması. Yukarıdaki ölçüm cihaz görünürlüğünü ve env zincirini kanıtlar, kare
üretimini değil.

## 2 Eyl 2026 — gamerun SIFIRDAN YAZILDI (iki ölçülmüş kök neden)

Belirti (kullanıcı): *"gamerun bozuk, çoğu oyunda çalıştıramıyorum; gamerun ile
başlatınca Sekiro vs. ayar menüsüne girince donabiliyor."* `localconfig.vdf`
bunu doğruluyordu — kullanıcı çoğu oyundan gamerun'ı çıkarmış, kalan bir satır
da `%command%`siz `"gamerun"` yazılıydı.

### Kök neden 1 — `DXVK_NVAPI_VKREFLEX=1` bir env AYARI değil, KATMAN anahtarı

Eski gamerun bunu koşulsuz export ediyordu ve yorumu *"Reflex — güvenli, açık
kalır"* diyordu. Gerçekte proton-cachyos içinde bir **implicit Vulkan katmanı**
manifesti var ve bu değişken onun `enable_environment`'ı:

```json
// share/dxvk-nvapi-vkreflex-layer/implicit_layer.d/VkLayer_DXVK_NVAPI_reflex.json
"name": "VK_LAYER_DXVK_NVAPI_reflex",
"device_extensions": [{ "name": "VK_NV_low_latency", "spec_version": "1" }],
"enable_environment": { "DXVK_NVAPI_VKREFLEX": "1" }
```

Katman **eski** `VK_NV_low_latency` (rev 1) uzantısını taklit eder. Ama bu
makinenin sürücüsü yerlisini zaten veriyor (`vulkaninfo`, 2 Eyl 2026):

```
VK_NV_low_latency2 : extension revision 2   ← dxvk-nvapi'nin gerçekte kullandığı
VK_NV_low_latency  : extension revision 1   ← katmanın taklit ettiği eski sürüm
```

Yani katman **gereksizdi**; tek yaptığı oyunla sürücü arasına fazladan bir aracı
koymaktı.

> **Kanıtın sınırı — dürüst olalım.** ÖLÇÜLEN: (a) değişkenin bir katman
> anahtarı olduğu (manifest okundu), (b) sürücünün `low_latency2`'yi yerlisinden
> verdiği (`vulkaninfo` koşturuldu), dolayısıyla (c) katmanın **gereksiz**
> olduğu. ÖLÇÜLMEYEN: donmaların *bu katmandan* geldiği. Bu bir çıkarım —
> gerekçesi güçlü (ayar menüsü swapchain'i yeniden kurar, bir katmanın en
> kırılgan anı odur; ayrıca 26 Ağu 2026'da Elden Ring'de zaten
> `DXVK_NVAPI_VKREFLEX=0` denenmiş, Steam logunda duruyor) ama kanıt değil.
> Bu repo kuralı gereği (CLAUDE.md: *"grep/okuma ile türetilen bir bulgu, bir
> şey koşturulana kadar bulgu değildir"*) böyle işaretleniyor. **Kaldırma kararı
> yine de doğru ve risksiz**, çünkü (c) tek başına yeter: gereksiz bir katman
> tutulmaz. Donma sürerse suçlu başkadır — ilk bakılacak yer
> `system/drivers/gpu.nix`'teki `powerManagement.finegrained` (dGPU runtime
> D3cold; ayar menüsü adaptör listeler → uyandırma yolu) ve Proton sürümü.
> Doğrulama: aynı sahneyi yeni gamerun'la 3 kez dene; donarsa
> `GR_NOPERF=1 gamerun` ve sonra gamerun'sız tekrarla.

Bu, `home/apps/games.nix`'in 22 Tem 2026'da
MangoHud'u kaldırma gerekçesiyle **aynı sınıf** hata ("oyun↔Vulkan sürücüsü
arasına giren katman, burada segfault geçmişi var"); o ilke burada ihlal
edilmişti. **Yeni gamerun hiçbir Vulkan katmanı enjekte etmez.** Reflex
kaybolmadı — sürücü/dxvk-nvapi onu `low_latency2` üzerinden zaten yapıyor.

### Kök neden 2 — `gamemoderun`'ın LD_PRELOAD'ı konteyneri geçemiyor

Eski gamerun son adımda `exec gamemoderun "$@"` yapıyordu. `gamemoderun` işini
`LD_PRELOAD=libgamemodeauto.so.0` + `LD_LIBRARY_PATH=<nix store>` ile yapar.
Oyun ise Steam'in **pressure-vessel konteynerinin içinde** açılır; o konteyner
kendi `LD_LIBRARY_PATH`'ini kurar, store yolu içeride yoktur. Ölçülen sonuç
(`~/steam-1245620.log`, Elden Ring — satır satır tekrarlıyor):

```
gamemodeauto: dlopen failed - libgamemode.so: cannot open shared object file
```

→ gamemode **aktive olmuyor** → `custom.start` kancası koşmuyor →
`game-perf.service`, `scx_lavd`, 0xED profili, turbo fan: **hiçbiri**.
Yani 10 Ağu 2026'daki düzeltme yalnız `command not found`u çözmüş; **zincirin
geri kalanı 2 Eyl'e kadar ölü kalmış.** Üstelik bu `LD_PRELOAD` oyun ağacındaki
her sürece miras kalıyordu — anti-cheat'li oyunlarda (Elden Ring
`start_protected_game.exe` = EAC) gereksiz risk.

**Düzeltme:** gamemode aradan çıkarıldı; gamerun `game-perf.service`'i
**doğrudan** sürüyor. Zaten çalışan bir yoldu, kullanılmıyordu — ölçüm
(kullanıcı `zixar`, parolasız, `system/kernel/sched.nix` polkit kuralı):

```
systemctl start game-perf.service → rc=0
scx.service → active | fan_mode → turbo | PPD → balanced
systemctl stop  game-perf.service → fan_mode → responsive | PPD → balanced
```

### Kök neden 3 — PRIME offload OpenGL'de HİÇ ÇALIŞMIYORDU (Minecraft iGPU'daydı)

`glxinfo -B` ile ölçüldü (2 Eyl 2026, `mesa-demos` bu flake'in pinli
nixpkgs'inden):

| Ortam | `OpenGL renderer string` |
|---|---|
| ham (sarmalayıcısız) | AMD Radeon 860M Graphics (radeonsi) |
| **ESKİ gamerun** | **AMD Radeon 860M Graphics (radeonsi)** ← offload ETMEMİŞ |
| ESKİ gamerun + `GR_NVONLY=1` | NVIDIA GeForce RTX 5060 Laptop GPU |
| **YENİ gamerun** | **NVIDIA GeForce RTX 5060 Laptop GPU** |

Sebep: `__NV_PRIME_RENDER_OFFLOAD=1` **tek başına GLX'i yönlendirmez** —
libglvnd'nin hangi GLX satıcısını yükleyeceğini `__GLX_VENDOR_LIBRARY_NAME`
belirler (`libGLX_nvidia.so.0` vs `libGLX_mesa.so.0`, ikisi de
`/run/opengl-driver/lib` altında var). Eski gamerun bu değişkeni `GR_NVONLY`'nin
arkasına saklamıştı; `GR_NVONLY` ise "riskli" diye varsayılan kapalıydı. Sonuç:
**yarım yapılandırma** — "NVIDIA'ya offload et" deniyor ama GLX mesa'ya gidiyor.

Bu, nixpkgs'in kendi `nvidia-offload` betiğinin dört değişkenini karşılaştırınca
apaçık: o betik `__GLX_VENDOR_LIBRARY_NAME=nvidia`'yı **her zaman** verir.

**Kimi vurdu:** OpenGL kullanan her şey — başta **Minecraft** (`mc-run` →
gamerun; vanilla LWJGL OpenGL'dir). Yani bu belgenin Minecraft bölümündeki
"dGPU PRIME offload (RTX 5060) — MC OpenGL, GLX vendor=nvidia yeterli" satırı
doğru olanı *tarif ediyordu* ama kod onu yapmıyordu; MC bugüne kadar **iGPU'da**
koşmuş. Vulkan oyunları etkilenmedi (DXVK/VKD3D cihazı kendi seçer, GLX satıcısı
onları ilgilendirmez) — bu yüzden arıza Steam tarafında görünmedi.

**Yeni gamerun üçlüyü her zaman verir.** Ters yöne ihtiyaç olursa (yazılım GL
gereken bir launcher gibi) dışarıdan ezilir; gamerun `:-` deseni kullandığı için
verilen değer kazanır — ölçüldü:

```
LIBGL_ALWAYS_SOFTWARE=1 gamerun …                          → NVIDIA (NO-OP! LIBGL_* Mesa'ya özgü)
LIBGL_ALWAYS_SOFTWARE=1 __GLX_VENDOR_LIBRARY_NAME=mesa gamerun … → llvmpipe (doğru)
```

**Bu HOI4'ü doğrudan ilgilendiriyor** — aşağıdaki Paradox launcher düzeltmesi
(`LIBGL_ALWAYS_SOFTWARE=1`) gamerun'la birlikte kullanılacaksa
`__GLX_VENDOR_LIBRARY_NAME=mesa` da yazılmalı, yoksa sessizce etkisiz kalır.

### Kök neden 4 (yan bulgu) — `scx.service` iki oyun açılışında ÖLÜYORDU

Test sırasında ortaya çıktı: upstream `scx.nix` modülü `StartLimitBurst=2` /
`StartLimitIntervalSec=30s` koyuyor. **30 saniye içinde iki kez oyun açmak**
scx.service'i kalıcı `failed`a düşürüyor:

```
scx.service: Start request repeated too quickly.
scx.service: Failed with result 'start-limit-hit'.
```

ve `systemctl reset-failed` yapılmadan bir daha **hiç** başlamıyor. Yani çöken
bir oyunu hemen tekrar açmak scx_lavd'ı sessizce öldürüyordu. `sched.nix`'te
`startLimitIntervalSec = lib.mkForce 0` ile kaldırıldı (game-perf için de aynısı;
onun varsayılanı 5/10s idi). Sınır çöküş-döngüsü koruması içindir — burada
tetikleyen bir insandır, anlamsız.

> **Bir kereye mahsus elle:** bu değişiklikten önce sınıra takıldıysan
> `sudo systemctl reset-failed scx.service` gerekir; `switch` sonrası tekrarı yok.

### Yeni gamerun'ın tasarım ilkeleri

| İlke | Ne demek |
|---|---|
| **A — Oyun her hâlükârda açılır** | taskset/game-perf/PRIME hepsi opsiyonel; başarısız olursa uyarı basıp devam eder. Hiçbir kod yolu oyunu başlatmamaya karar veremez. |
| **B — Katman enjekte etme** | Vulkan katmanı yok, LD_PRELOAD yok. Yalnız süreç nitelikleri (env, CPU affinity) + sistem servisleri. |
| **C — Yalnız ölçülmüş iş** | DLSS/MFG/FG/SmoothMotion/low-latency/ntsync/VKD3D env'leri gamerun'dan **çıkarıldı**. Oyuna özgüler; launch options'a doğrudan yazılırlar (aşağıdaki tablo). |
| **D — Temizlik garantili** | `trap` + referans sayacı: çıkışta game-perf mutlaka durur (fan turbo.da unutulmaz). SIGKILL kaçağı 12 Eyl 2026.de kapatıldı: gamerun açılışta sızmış oturumu sıfırlıyor + `game-perf-reap.service` udev/uyanışta aynısını yapıyor. |

**C'nin pratik sonucu — hiçbir şey kaybolmadı, sahibi değişti.** gamerun artık
o değişkenlere *dokunmuyor*, dolayısıyla ezmiyor da: `PROTON_USE_NTSYNC=1
gamerun %command%` yazınca değişken oyuna olduğu gibi geçer. Eskiden bir
`GR_*` takma adı gerekiyordu; artık gerekmiyor. Bunun asıl kazancı **OptiScaler
ile birlikte kullanabilmek**: `PROTON_USE_OPTISCALER=1 PROTON_FSR4_UPGRADE=1
gamerun %command%` artık çakışmıyor, çünkü gamerun kendi NGX/DLSS override'ını
yapmıyor.

**Kaybedilen tek şey:** gamemode'un `renice -20` + `ioprio 0`'ı. Steam yolunda
zaten hiç çalışmıyordu (kök neden 2); mc-run/emu-run yolunda çalışıyordu, orada
küçük bir gerileme. Karşılığında oyun boyunca gerçekten koşan bir `scx_lavd
--performance` var — asıl gecikme kolu oydu.

## 10 Ağu 2026 — KRİTİK: gamerun Steam'den hiç çalışmıyordu

`~/.local/share/Steam/logs/console-linux.txt` bu tarihe kadar tekrarlı olarak
`gamerun: command not found` basıyordu. Sebep: Steam launch options'ı KENDİ
FHS/pressure-vessel kum havuzunun İÇİNDE `/bin/sh -c` ile koşuyor; o kabın
`PATH`'i yalnız `/usr/bin:/bin`. `gamerun` Home Manager profilindeydi
(`/etc/profiles/per-user/zixar/bin`) — kum havuzunun dışında, hiç görünmüyordu.

**Sonuç:** bu belgede aşağıda anlatılan zincirin TAMAMI (dGPU PRIME offload,
DLSS override'ları, gamemode → game-perf.service → scx_lavd + 0xED profili +
turbo fan) bugüne kadar **bir Steam oyununda hiç tetiklenmedi**. mc-run (Prism
WrapperCommand) ve emu-run çağırıcıları etkilenmedi — onlar `exec gamerun`'ı
normal kullanıcı PATH'inden (HM profili) çağırıyor, kum havuzu sorunu yalnız
Steam'e özgü.

**Düzeltme:** gamerun'ın tanımı `lib/gamerun.nix`'e taşındı (`home/apps/games.nix`
ile `usr/steam.nix`'in ortak import noktası — CLAUDE.md "Renaming rule",
system/usr/ ile home/ ayrı eval bağlamı). `usr/steam.nix`,
`programs.steam.extraPackages` ile onu Steam'in FHS kum havuzuna paket olarak
ekliyor → kum havuzunda `/usr/bin/gamerun` oluşuyor, launch options
`gamerun %command%` **olduğu gibi** çalışmaya başlıyor.

**Aynı düzeltmeyle gelen ikinci değişiklik — CPU maske delme:** `system/kernel/cores.nix`
(10 Ağu 2026, ayrıntı `Documentation/aerox16/cpu-hybrid.md`) masaüstü işlerini
VARSAYILAN olarak Zen5c ("verimlilik") çekirdeklerine kilitliyor — zamanlayıcı bu
CPU'nun hibrit olduğunu BİLİYOR (ITMT açık) ama hızlı çekirdeği tercih ediyor;
maske o tercihi güç bütçesi adına eziyor (düzeltme 16 Ağu 2026).
`gamerun` artık VARSAYILAN olarak `taskset -c 0-15` ile başlıyor → oyun bu
maskeyi kendisi için tamamen deliyor, tüm 16 CPU'ya erişiyor (`GR_PIN` ile daha
dar pinleme hâlâ mümkün).

**Üçüncü değişiklik — bu sarmalayıcı hiç test edilmediğinden varsayılan yüzey
daraltıldı:** `__VK_LAYER_NV_optimus=NVIDIA_only` + `__GLX_VENDOR_LIBRARY_NAME`
(AMD cihazını gizleme), NGX updater + DLSS SR/RR override, ve NVIDIA GL shader
cache VARSAYILAN KAPALI'ya alındı — sırasıyla `GR_NVONLY=1`, `GR_DLSS=1`,
`GR_CACHE=1` ile opt-in. Gerekçe: `NVIDIA_only` AMD Vulkan cihazını gizliyor —
NVIDIA ICD kum havuzunda görünmezse oyun sıfır cihaz görüp anında kapanabilir;
DLSS override bloğu ise kullanıcının OptiScaler kullanan oyunlarıyla (aşağıdaki
"860M FSR4" bölümü) aynı katmanda çakışıyor.

> **ÜSTÜ ÇİZİLDİ 2 Eyl 2026.** Bu üç `GR_*` takma adı artık YOK. `GR_NVONLY`'nin
> yerini `GR_GPU=nvidia` aldı (ve `__GLX_VENDOR_LIBRARY_NAME=nvidia` ondan
> ayrıldı: artık her zaman açık, çünkü yalnız GL/EGL'i etkiliyor ve OpenGL
> oyunlarının doğru çalışması için ŞART). `GR_DLSS`/`GR_CACHE` ise ilke C
> uyarınca tamamen kaldırıldı — ham env'leriyle launch options'a yazılırlar.
> Yukarıdaki 2 Eyl bölümüne bak.

**Steam tarafında elle düzeltilmesi gereken (nix dışı):** üç oyunda launch
options `"gamerun"` / `"gamerun "` yazılıydı — `%command%` YOK. Steam'de
`%command%` içermeyen dize sarmalayıcı SAYILMAZ, oyunun argümanı olarak
sonuna eklenir. Her launch option `gamerun %command%` biçiminde olmalı.

## Mimari özet

Yeniden yazıldı 2 Eyl 2026 — gamemode artık zincirde DEĞİL (yukarıdaki kök neden 2):

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
       ├─ 4b. SIZINTI SIFIRLAMASI (12 Eyl 2026): state dizinindeki ölü PID kayıtlarını
       │      sil; canlı örnek KALMADIYSA ve game-perf hâlâ "active" ise önce STOP.
       │      (game-perf oneshot+RemainAfterExit → aktif birime `start` demek
       │      ExecStart'ı yeniden KOŞTURMAZ; sızıntının üstüne açılan oyun hiçbir
       │      ayarı almazdı.)
       │
       ├─ 5. systemctl start game-perf.service   ← DOĞRUDAN (polkit), referans sayaçlı
       │        ├─ scx_lavd --performance
       │        ├─ AC'deyse fan_mode turbo
       │        ├─ AC'deyse PPD → balanced (GPU-öncelik; gamerun-cpumax varsa performance)
       │        └─ AC'deyse WMBD 0xED profil 2: ACBT 160 + agresif fan eğrisi
       │           (KCD ölçümü: GPU 38W→~70W sustained; fan %32-35→%46-49)
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

7 Eyl'de `aorus_laptop` yerine `aero_eg61h` geldiğinde sessiz bir şey değişti:
yeni sürücü **`platform_profile` handler'ı olarak kayıtlı** ve o handler aynı
WMBD 0xED register'ını yazıyor (`kernel/aero-profile.c`):

| platform_profile | WMBD 0xED | ATPP | ACBT | AC PL1/PL2/PL3 |
|---|---|---|---|---|
| `low-power` | 0 | 0xA0 | 0 (kapalı) | 20/65/65 W |
| `balanced` | 1 | 0xC8 | 0x50 | 25/65/80 W |
| `performance` | 2 | ECPL | 0xA0 (en üst) | 30/80/80 W |

PPD ise profili `/sys/firmware/acpi/platform_profile` üzerinden yazıyor ve
çekirdek onu **tüm handler'lara** dağıtıyor. Ölçüm (12 Eyl):

```
powerprofilesctl set performance
  → platform-profile-0 (aero_eg61h) = performance   ← 0xED 2 yazıldı
  → platform-profile-1 (amd-pmf)    = performance
```

Bunun üç sonucu vardı ve üçü de düzeltildi:

1. **Oyun profili eziliyordu.** Eski sıra `0xED 2` → `PPD balanced` idi; ikinci
   adım handler üzerinden `0xED 1` yazıyordu. Yani 7 Eyl'den beri "oyun profili"
   yalnız birkaç milisaniye yaşıyordu. **Sıra ters çevrildi.**
2. **Çıkışta EC en kısıtlı profilde kilitleniyordu.** `gamePerfStop` ham
   `0xED 0` yazıyordu ("boot varsayılanına dön" diye) — ama boot varsayılanı
   artık 0 değil, PPD'nin yazdığı `balanced` = 1. Üstüne `power-display`'in
   `ppd_apply balanced`'i, PPD zaten balanced olduğu için **no-op**'a düşüyordu
   (bu davranış `power-display.nix`'te 2026-07-27'de ölçülüp belgelenmiş) →
   handler'a hiç yazılmıyordu. Sonuç: ACBT kapalı, AC PL1 20 W, ve sysfs
   "balanced" diyerek yalan söylüyor. **Ham yazım kaldırıldı**, yerine standart
   `platform_profile` düğümüne yazılıyor — EC de sürücü önbelleği de senkron.
3. **Sürücünün önbelleği oyun sırasında bayat.** 0xED'in geri okuması YOK
   (WMBC'de karşılığı yok), o yüzden oyun boyunca sysfs "balanced" der, EC 2'dedir.
   Kaçınılmaz ve bilinçli; çıkışta senkronlanıyor.

**Referans sayacı neden var:** iki oyun aynı anda açıkken biri kapanınca
diğerinin fanını düşürmesin diye. Her gamerun örneği
`$XDG_RUNTIME_DIR/gamerun.d/<pid>` dosyası bırakır; çıkışta yalnız **canlı**
başka örnek kalmadıysa servis durdurulur (ölü kayıtlar aynı taramada silinir).
Ölçüldü 2 Eyl 2026: kısa örnek biterken `fan_mode` 5'te kaldı, uzun örnek
bitince düştü.

**Turbo fan (2026-07-17):** oyun süresince (AC'de) fanlar tam güce alınır
(`fan_mode turbo`, ~6900 RPM) → dGPU en soğuk + fan tepkisi maksimum. **CPU yine
~95°C** olur (EC/SMU tavanı; hiçbir fan bunu değiştirmez — bkz.
`Documentation/aerox16/wmi-ec.md` preset karakterizasyonu) ve **seslidir** — bilinçli
tercih. Pilde uygulanmaz (oyun zaten güç-limitli). Oyun bitince
`aero-power-profile.service` fan modunu AC'de `responsive`, pilde `balanced` yapar.

**Düzeltme (10 Ağu 2026):** `aero-power-profile` (o zamanki adıyla
`gigabyte-power-profile`) daha önce fişi çekip takınca veya uykudan dönünce KOŞULSUZ
fan modu yazıyordu — oyunun ortasında turbo sessizce düşüyordu. Artık
`game-perf.service` aktifken (`systemctl is-active` ile sorgulanır) fan modunu
yazmıyor; ACBT/boost bütçesi kolu aynen AC/BAT'a göre uygulanmaya devam ediyor.

**Düzeltme (12 Eyl 2026) — TURBO TAKILI KALIYORDU, iki bağımsız neden:**

*Birincisi, ölü birim adı.* `gamePerfStop`, 7 Eyl'de `aero-power-profile.service`
olarak yeniden adlandırılmış birimi hâlâ eski adıyla çağırıyordu ve hatayı
`|| true` ile yutuyordu. Journal, üç oyun kapanışı:

```
Failed to start gigabyte-power-profile.service: Unit ... not found.
```

Yani fan modunu geri kuran **tek kol** 5 gündür hiç koşmuyordu. EC uçucu değil →
fan reboot'a kadar turbo'da kalıyordu. Yan etkisi AERO Kontrol'de de görünüyordu:
fan `turbo` + profil `balanced` hiçbir ön ayara uymadığı için arayüzde **hiçbiri
seçili görünmüyordu** (GUI tarafı da düzeltildi — artık bu hâlin "Custom" diye adı var).

*İkincisi, yapışkan oyun istisnası.* `game-perf` `Type=oneshot` +
`RemainAfterExit=true`, yani gamerun SIGKILL edilirse (trap yakalanamaz) birim
süresiz "active" kalır. Bunun bedeli yalnız "servis açık kalır" değil:
`aero-power-profile` **ve** `power-display`, `is-active game-perf` görünce
fan/affinity yazmayı atlıyor — fişi çekmek, kapağı kapatmak, uyanmak, hiçbiri
turbo'dan çıkaramıyordu. İki ağ eklendi, ikisi de olay tetikli (poll YOK):

| ağ | nerede | ne zaman |
|---|---|---|
| gamerun sıfırlaması | `lib/gamerun.nix` 4b | her oyun açılışında, kendi kaydından önce |
| `game-perf-reap.service` | `system/kernel/sched.nix` | udev (ACAD) + uyanış |

İkisi de aynı testi yapar: referans sayacı dizininde **canlı** PID kalmadıysa
oturum bitmiştir → `systemctl stop game-perf.service`.

Donanım tarafı zaten AC'ye bağlı otomatik: fiş takılıyken fan modu 2 ("oyun") +
NPCF.ACBT 80W → nvidia-powerd dGPU'yu 75–85W bandına çıkarır
(`system/arch/aerox16/wmi.nix`). VRR artık COSMIC tarafında: panel
`Adaptive Sync: automatic` bildiriyor (ölçüm 11 Eyl 2026, `cosmic-randr list`),
yani tam ekran/oyun durumunda devreye girer. Bu ayar COSMIC'in kendi
ayarlarında yaşar — repo ona dokunmaz. Pilde panel zaten 60Hz'e çekilir
(`power-display-user`, power-display.nix; 11 Eyl 2026'dan beri `cosmic-randr`
ile, önceden `hyprctl` ile).

**GPU-öncelik: oyunda PPD balanced (18 Tem 2026).** CPU ile dGPU, ACBT 80W'lık
NVIDIA Dynamic Boost bütçesini **paylaşır**. Oyunda PPD `performance` yapılırsa
amd-pmf CPU'ya en yüksek STAPM preset'ini basar → CPU 100°C Tjmax'inde bütçeyi yer →
nvidia-powerd dGPU'ya ancak ~30W verir (tavan 85W → **açlık**, güç-limiti değil).
Bu yüzden oyun varsayılanı artık `balanced`: CPU STAPM tavanı düşer, klok yine talep
üzerine yükselir (EPP=balance_performance), bütçe dGPU'ya kayar → GPU-bound oyunda
daha çok watt + FPS. CPU-bound oyun (bazı sim/strateji, KCD kalabalık şehir) için
`GR_CPUMAX=1` ile performance'a dön. **Not:** CPU'yu undervolt ile soğutmak bu
makinede platform-kilitli (`Documentation/aerox16/undervolt.md`); güç-iştahını kısmak
tek kullanılabilir kol. 100°C by-design'dır (Zen5 mobil Tjmax hedefi), arıza değil.

**Pilde oyun:** tasarım gereği kısıtlı — CPU 2GHz tavan + boost kapalı + ACBT 0.
Tam performans için fişe tak. Pil/idle tabanı (4.28W) bu kurulumdan etkilenmez:
boşta scx inactive, zram pasif, gamemoded uykuda.

## Launch options matrisi

**`%command%` ZORUNLU** — Steam'de bunu içermeyen bir launch options dizesi
sarmalayıcı sayılmaz, oyunun argümanı olarak sonuna eklenir (`gamerun` tek
başına yazılırsa oyun `oyun.exe gamerun` diye açılır ve gamerun hiç koşmaz).
Her satır `gamerun %command%` biçiminde olmalı.

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

`GR_NOPERF=1` neden var: "oyun açılmıyor" şikâyetinde suçluyu ikiye bölmek için.
Açılıyorsa sorun perf zincirinde (systemd/polkit tarafı), hâlâ açılmıyorsa
gamerun'la ilgisi yok — launch options'tan çıkarıp doğrula.

gamerun stderr'e tek satırlık bir banner basar (`gamerun: başlıyor — CPU=… GPU=…
perf=…`) ve bu **Steam'in `console-linux.txt`'sine düşer** → "gerçekten koştu
mu?" sorusu bir daha ölçüm oturumu gerektirmez.

### Oyuna özgü env'ler — gamerun'a DEĞİL, doğrudan launch options'a

Bunlar 2 Eyl 2026'da gamerun'dan çıkarıldı (ilke C). gamerun onlara artık
dokunmadığı için **ezmez de** — yani hem gamerun'la hem gamerun'sız aynı
şekilde çalışırlar, ve OptiScaler ile birlikte kullanılabilirler.

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

**Kaldırılan ve GERİ GELMEYECEK olan tek şey `DXVK_NVAPI_VKREFLEX=1`** — bu bir
"Reflex aç" ayarı değil, yukarıda anlatılan gereksiz Vulkan uyumluluk katmanının
anahtarı ve donmaların sebebi. Reflex zaten sürücünün `VK_NV_low_latency2`'si
üzerinden çalışıyor; açmak için hiçbir şey yazmana gerek yok.

**`GR_WIN` de kaldırıldı** (2 Eyl 2026). Varsayılanı zaten "hiçbir pencere
argümanı ekleme"ydi, yani kimse kaybetmiyor; ama verildiğinde Proton komut
satırının SONUNA `-w/-h/-screen-*` ekliyordu — "oyun açılmıyor" sınıfı bir
riski, hiç ölçülmemiş bir kazanç için taşımaya değmez. Pencere modu oyunun kendi
ayarından yapılır (FromSoft `GraphicsConfig.xml`, HOI4 `settings.txt`, Hogwarts
`GameUserSettings.ini`, KCD `user.cfg`, RE Engine `config.ini` — `*.bak`
yedekleri duruyor).

**Pencere modu:** `gamerun` hiçbir pencere argümanı eklemez — oyunlar kendi
(genelde tam ekran) davranışını kullanır. Çözünürlük/pencere ayarı oyunun kendi
config'inden gelir (FromSoft `GraphicsConfig.xml`, HOI4 `settings.txt`, Hogwarts
`GameUserSettings.ini`, KCD `user.cfg`, RE Engine `config.ini`). **NOT:** o
config'ler daha önce windowed'a çevrilmişti (`*.bak` yedekleri var) → yine
pencereli açılırlar; tam ekran istenirse `*.bak`'tan geri alınır.

**Öncelik — DÜZELTİLDİ 2 Eyl 2026.** Bu bölüm 18 Tem'den beri "oyun süreci
`renice -20` koşuyor" diyordu; **Steam yolunda hiç doğru olmamış** (gamemode'un
`LD_PRELOAD`'ı pressure-vessel konteynerini geçemiyordu — yukarıdaki kök neden 2).
Yeni gamerun gamemode'u zincirden çıkardı, yani renice/ioprio artık **hiçbir
yolda** uygulanmıyor. Gecikme kolu tamamen **scx_lavd `--performance`** —
ve o, 2 Eyl'den beri gerçekten koşuyor.
`programs.gamemode` sistemde açık kalmaya devam ediyor: gamemode API'sini kendi
çağıran oyunlar için yedek yol (`system/kernel/sched.nix`'teki "OTORİTE
DEĞİŞTİ" bloğu).
**Gerçek RT (SCHED_FIFO/RR) bilinçli olarak KULLANILMADI:** RT sınıfı sched_ext'in
üstünde koşar → scx_lavd'ı (oyun için tasarlanan latency-aware zamanlayıcı) bypass
eder, ayrıca bir thread busy-loop yaparsa makineyi kilitleyebilir.

**Blackwell (RTX 5060) DX12/VKD3D kararlılık — kaçış-flag'leri (opt-in, 22 Tem 2026):**
DXVK (D3D9/10/11→Vulkan) + VKD3D‑Proton (D3D12→Vulkan) + dxvk‑nvapi (DLSS/Reflex) zaten
her Proton oyununu Vulkan'a çevirir. Blackwell'e özgü iki bilinen kararsızlık ve cerrahi
(oyun-başına, VARSAYILAN KAPALI) çözümleri — kullanıcıda şu an sorun yok, gerektiğinde aç:

- **`VKD3D_SHADER_CACHE_PATH=0`** (launch options'a doğrudan). NVIDIA'da bazı DX12 oyunları
  dakikalar–saatler sonra donuyor/sessizce çöküyor (vkd3d-proton **#2793**, Ocak 2026;
  RTX 4070 **ve** 5070 doğrulanmış). VKD3D shader cache'i kapatmak donmayı bitirir;
  **bedeli** ilk-render shader stutter'ının artması → yalnız donan o oyunda aç.
- **`PROTON_VKD3D_HEAP=1`** (VK_EXT_descriptor_heap). Blackwell'de bazı DX12
  oyunlarının shader-derleme fazında **Xid 109 sert çökmesi** (vkd3d-proton **#2914** / PR
  #2805; ör. Crimson Desert). Fix yalnız descriptor_heap içeren Proton'da etkin → o oyuna
  **Steam'de Proton-CachyOS** seç (aşağı bak); GE-Proton'da zararsız no-op.
- **`VKD3D_CONFIG=<token>`** ham passthrough. İleri per-oyun: `dxr11` (D3D12
  raytracing zorla), `force_raw_va_cbv` (bazı NVAPI/DLSS kurulumları), vb.

**Proton-CachyOS (Blackwell-sertleştirilmiş, 22 Tem 2026):** `usr/steam.nix`
artık GE-Proton'un **yanına** Proton-CachyOS'u da kurar (`chaotic-nyx` flake input +
`nyx-cache.chaotic.cx` binary cache). Steam'de oyun-başına seçilir (Özellikler → Uyumluluk).
GE-Proton **varsayılan** kalır; inatçı DX12/Blackwell oyunlarında (Xid 109, #2793 donma)
Proton-CachyOS + `PROTON_VKD3D_HEAP=1` dene — en güncel dxvk/vkd3d + VK_EXT_descriptor_heap içerir.

**Oyunları Vulkan'a taşıma (launcher tarafı — kullanıcı uygular):**
- **HOI4 (ve diğer Paradox / native-OpenGL oyunları):** Steam → Özellikler → Uyumluluk →
  "Force GE-Proton (veya Proton-CachyOS)". Native Linux OpenGL yerine oyun D3D11→**DXVK→
  Vulkan** koşar (5060'ta daha stabil). Tek-thread sim → `GR_PIN=big gamerun %command%`.
- **Paradox Launcher (launcher-v2) beyaz/boş pencere (30 Tem 2026):** yeni launcher
  (Electron/CEF, `Paradox Launcher.exe --use-angle=gl`) Wine altında donanım hızlandırmalı
  native OpenGL ile açılıyor; bu hibrit GPU'da (AMD iGPU + NVIDIA dGPU) + Wayland/Xwayland'de
  GL context kompozisyona hiç düşmüyor → pencere kalıcı beyaz, ne uygulama logu ne Crashpad
  raporu var (sessiz kompozisyon hatası — asıl oyunun kendi log/crash altyapısı bu yüzden
  ipucu vermiyordu). HOI4 launch options: `LIBGL_ALWAYS_SOFTWARE=1 %command%` düzeltiyor
  (Mesa'nın GL/GLX yolunu yazılığa zorlar).
  **DİKKAT — 2 Eyl 2026:** yeni gamerun `__GLX_VENDOR_LIBRARY_NAME=nvidia`'yı
  varsayılan verdiği için `LIBGL_ALWAYS_SOFTWARE=1` **gamerun'ın içinde no-op olur**
  (o bir Mesa değişkeni; NVIDIA GLX satıcısını ilgilendirmez — ölçüldü, `glxinfo -B`
  hâlâ RTX 5060 diyor). gamerun'la birlikte kullanılacaksa satıcıyı da geri çevir:
  `__GLX_VENDOR_LIBRARY_NAME=mesa LIBGL_ALWAYS_SOFTWARE=1 GR_PIN=big gamerun %command%`
  (ölçüldü → `llvmpipe`). Oyunun kendisi Vulkan koştuğu için bu yalnız launcher'ın
  küçük GL arayüzünü etkiler.
  **Güvenli:** oyunun kendisi D3D11→DXVK→Vulkan
  koşuyor (prefix'te taze `.dxvk.bin`/`.dxvk.lut` cache doğrulandı) — Vulkan bu env'den
  etkilenmez, yalnız launcher'ın küçük arayüzü CPU'da render olur (önemsiz maliyet). Aynı
  belirti başka Proton/Electron launcher'da (Epic, GOG Galaxy vb.) görülürse ilk şüpheli
  bu. **Tuzak:** launcher'ın 127.0.0.1:11000 tek-örnek kilidi — takılı beyaz pencere
  duruyorken tekrar "Play" o pencereyi öne getirir, yeni launch option'ı hiç görmez;
  önce Steam'den Durdur (ya da `reaper SteamLaunch AppId=<id>` sürecini öldür).
- **Minecraft:** vanilla LWJGL **OpenGL**'dir; **VulkanMod** (Fabric) native Vulkan render
  verir. Sistem env'i zaten destekler (offload `mc-run`→`gamerun`'dan miras;
  `__GL_THREADED_OPTIMIZATIONS=0` VulkanMod'da etkisiz-zararsız). Mod kurulumu Prism = kullanıcı.
- **Ölçüm (MangoHud kaldırıldı):** ikinci terminalde `nvtop` (AMD+NVIDIA) veya
  `nvidia-smi dmon` → dGPU watt/clock/util + oyun sürecinin NVIDIA'da olduğunu doğrula.

**DLSS opt-in (17 Tem 2026):** SR (upscaling) + RR (ray reconstruction) override
varsayılan AÇIK (güvenli, performanslı). FG override, `render_preset` ve ntsync ise
artık **opt-in** ("0 grafik bozulması" kararı): zorla açık FG bazı oyunlarda
artefakt/donma yapıyordu (Tsushima "GPU kare basmayı durduruyor"), ntsync zorlaması
GE'nin per-game blocklist'ini eziyordu. Reflex açık kaldığından **performans düşmez**.

Tüm varsayılanlar `VAR=değer gamerun %command%` ile oyun başına ezilebilir
(sarmalayıcı `:-` deseni kullanır). `GR_PIN`: `big` = 4× Zen5 5.09GHz
(Zen5c 3.5GHz dışarıda), `fast` = yalnız cpu4/6+SMT (iki firmware sıralaması da
bu dörtlüyü işaret ediyor: CPPC 208, ITMT 203), veya özel liste (`GR_PIN=0,2,4`).
**Düzeltme (16 Ağu 2026 — 10 Ağu'daki düzeltme de yanlıştı):** zamanlayıcı
Zen5/Zen5c ayrımını **BİLİYOR** — `amd_hfi` bağlı, ITMT açık, `sched_core_priority`
Zen5'te 196/203 Zen5c'de 135 (kanıt: `Documentation/aerox16/cpu-hybrid.md`).
`prefcore = disabled` bir eksiklik değil, HFI'li tasarımlarda upstream'in kasıtlı
davranışı. `gamerun` VARSAYILAN olarak `taskset -c 0-15` ile başlar
(`system/kernel/cores.nix`'in Zen5c-only masaüstü maskesini oyun için deler) —
çoğu oyun için bu yeterli, üstelik 0-15 havuzunda ITMT zaten tek-thread'lik işi
Zen5'e yönlendiriyor. `GR_PIN=big` artık "şansa karşı sigorta" değil, ITMT'nin
yalnız bir *tercih* olmasına karşı **garanti**; tek-thread'e bağımlı sim
oyunlarında (HOI4/Stellaris/Factorio) dene, ama önce GR_PIN'siz ölç. Proton sürümü olarak
**GE-Proton** veya **Proton Experimental / Proton 11** seç (ntsync + güncel dxvk-nvapi).

## Minecraft (Prism Launcher)

*Kurulum: 2026-07-15 · `home/apps/minecraft.nix` (HM katmanı)*

Steam zincirinin native-Java karşılığı — Prism her instance'ı **Wrapper Command**
üzerinden başlatır:

```
Prism Launcher (iGPU'da açılır)
  └─ WrapperCommand=mc-run → __GL_THREADED_OPTIMIZATIONS=0 export → exec gamerun
       └─ gamerun java -Xmx8192m <G1 bayrakları> ...
            ├─ dGPU PRIME offload (RTX 5060) — MC OpenGL, GLX vendor=nvidia ŞART
            │  (2 Eyl 2026'ya kadar __GLX_VENDOR_LIBRARY_NAME opt-in'in arkasındaydı →
            │   "NVIDIA'ya offload et" deniyor ama GLX hâlâ mesa'ya gidiyordu; MC gibi
            │   OpenGL oyunları tam bundan etkilenir. Artık varsayılan.)
            ├─ taskset -c 0-15 (Zen5c masaüstü maskesini del)
            └─ systemctl start game-perf.service   ← DOĞRUDAN (gamemode yok, 2 Eyl 2026)
                 └─ scx_lavd + AC.deyse turbo fan + PPD balanced + 0xED profil 2 (PPD.den SONRA)
                    (Steam'dekiyle aynı; GR_CPUMAX=1 ile performance)
```

**FPS düzeltmesi — `__GL_THREADED_OPTIMIZATIONS=0` (17 Tem 2026):** NVIDIA sürücüsü
Prism ile başlatılan MC'yi tanıyamadığından threaded-GL optimizasyonu yanlış devreye
girip FPS'i düşürüyordu (Windows'a göre belirgin fark — Sodium wiki Driver-Compatibility
+ issue #1830). `mc-run` sarmalayıcısı bu değişkeni **yalnız MC'ye** verir (global veya
Steam oyunlarına sızmaz — bazı OpenGL oyunlarında ters etki yapar), sonra `gamerun`'a
devreder (PRIME offload zinciri aynen miras kalır).

**Java:** ayrı paket yok — nixpkgs sarmalayıcısı jdk8/17/21/25'i
`PRISMLAUNCHER_JAVA_PATHS` ile sunar, `AutomaticJavaSwitch=true` instance'ın MC
sürümüne uygun olanı seçer (1.8→jdk8, 1.17+→17, 1.20.5+→21). Prism'in kendi
Java indirmesi KAPALI (`AutomaticJavaDownload=false`): generic binary NixOS'ta
çalışmaz (dinamik linker yolu yok).

**JVM bayrakları — Aikar seti (global `JvmArgs`, `prismlauncher.cfg`; 18 Tem 2026):**
`-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch
-XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M
-XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem
-XX:MaxTenuringThreshold=1` — modlu-MC'nin standart GC seti; Java 8→25 hepsinde
geçerli (ZGC 21+ olduğundan global konamaz).

**Neden değişti (periyodik hitch fix):** hem VulkanMod hem Sodium modpack'lerinde
periyodik kısa hitch görülüyordu → render motoruna özel değil, **GC kaynaklı**. Eski
set iki sorunluydu: (1) `MinMemAlloc=512`/`MaxMemAlloc=8192` uçurumu → JVM heap'i
sürekli resize edip duraklıyordu; (2) `MaxGCPauseMillis=50` çok agresif → daha SIK,
küçük GC yapıp overhead/hitch ekliyordu. Yeni set: **sabit heap** (Min=Max=8192 →
resize duraklaması biter) + `+AlwaysPreTouch` (tüm heap başta commit; kısa açılış
gecikmesi, oyun-içi commit hitch'i yok) + `MaxGCPauseMillis=200` (Aikar felsefesi:
az sayıda iyi-yönetilen GC). Heap 8192 MiB (32 GB RAM'de güvenli); çok ağır modpack
instance ayarları → Java sekmesinden instance-başına yükseltilebilir. **Not:**
VulkanMod'un ilk-render pipeline derleme hitch'i JVM'den bağımsızdır ve tam
gitmeyebilir (Vulkan'a özel); bu düzeltme her iki motordaki ORTAK GC hitch'ini kaldırır.

**Shader + Distant Horizons:** DH LOD arazisi yalnız **DH-uyumlu shader**'da
gölgelenir (Complementary Reimagined/Unbound, Bliss 2.1+, Photon, Shrimple). Uyumsuz
shader (ör. Voyager) + DH = yakın/uzak dikişi + flicker + bozulma. Shader seçimi/kurulumu
kullanıcı tarafında (launcher); autoexec (env/wrapper/bellek) bu modülde.

**Ölçüm:** MangoHud kaldırıldı. MC (OpenGL veya VulkanMod) için oyun-içi overlay yok;
ölçümü ikinci terminalden yap: `nvtop` (java sürecinin dGPU'da + watt/util) ya da
`nvidia-smi dmon`. FPS için VulkanMod/Sodium'un F3 debug ekranı da kullanılabilir.

**Yapılandırma deklaratif:** `prismlauncher.cfg` her `hms`'te store kopyasıyla
tazelenir (vesktop'taki mutable-copy deseni) → GUI'den yapılan *global* ayar
değişiklikleri kalıcı olsun istiyorsan `home/apps/minecraft.nix`'e işle.
Hesaplar (`accounts.json`) ve instance'lar ayrı dosyalarda, etkilenmez.

Doğrulama (instance açıkken, AC'de):
```bash
systemctl is-active game-perf scx   # active / active
nvidia-smi                          # java süreci dGPU'da, yükte watt artar
```

## Oyun-içi ölçüm (MangoHud kaldırıldı, 22 Tem 2026)

MangoHud, oyun ile Vulkan sürücüsü arasına giren bir katmandı (burada segfault geçmişi var:
gamescope `--mangoapp` coredump) → DXVK/VKD3D iletişimini sadeleştirmek için kaldırıldı.
Ölçüm artık **dış araçla**, oyunun render yoluna hiç dokunmadan:

- **`nvtop`** (2. terminal) — AMD iGPU + NVIDIA dGPU birlikte: watt, clock, util, VRAM,
  hangi süreç hangi GPU'da. Oyun sürecinin dGPU'da + yükte watt arttığını burada gör.
- **`nvidia-smi dmon`** — dGPU'ya özel saniyelik telemetri (sm/mem util, power, temp, clock).
- **`nvidia-smi`** — anlık tam durum; Dynamic Boost watt tavanı doğrulaması.
- **FPS/frametime** için oyunun kendi sayacı (VulkanMod/Sodium F3, motor overlay'leri) veya
  `PROTON_LOG=1` + `~/steam-<appid>.log` içindeki dxvk/vkd3d init satırları.

## RTX 5060 özellik durumu (DLSS 4.5, Linux/Proton)

| Özellik | Destek | Nasıl |
|---|---|---|
**GÜNCELLENDİ 2 Eyl 2026** — bu satırların hiçbiri artık `gamerun` varsayılanı
değil. Hepsi oyun-başına launch options'a yazılır (yukarıdaki "Oyuna özgü
env'ler" tablosu); gamerun onlara dokunmaz, dolayısıyla ezmez.

| Özellik | Destek | Nasıl |
|---|---|---|
| DLSS SR (2. nesil transformer) | ✔ tüm RTX | `DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE=on` (ya da oyun menüsü) |
| DLSS Ray Reconstruction | ✔ | `DXVK_NVAPI_DRS_NGX_DLSS_RR_OVERRIDE=on` |
| DLSS render preset (en yeni) | ✔ | `DXVK_NVAPI_DRS_NGX_DLSS_SR_OVERRIDE_RENDER_PRESET_SELECTION=render_preset_latest` |
| DLSS Frame Generation | ✔ (oyun desteği şart) | `DXVK_NVAPI_DRS_NGX_DLSS_FG_OVERRIDE=on`; oyun menüsünden de aç |
| Multi Frame Gen 2x–6x | ✔ RTX 50'ye özel | `DXVK_NVAPI_DRS_NGX_DLSSG_MODE=on` + `..._MULTI_FRAME_COUNT=<N-1>` |
| Dynamic MFG (hedef FPS) | ✔ RTX 50'ye özel | `DXVK_NVAPI_DRS_NGX_DLSSG_MODE=dynamic` + `..._DYNAMIC_TARGET_FRAME_RATE=165` |
| Reflex (VK_NV_low_latency2) | ✔ | **hiçbir şey yazma** — sürücü uzantıyı yerlisinden veriyor (`vulkaninfo`: revision 2). `DXVK_NVAPI_VKREFLEX=1` YAZMA: o, eski rev-1 uyumluluk KATMANINI açar ve donmalara sebep oldu |
| ntsync (Proton NT senkron) | ✔ | `PROTON_USE_NTSYNC=1` / `=0` (varsayılan: Proton karar verir) |
| Smooth Motion (sürücü framegen) | ✔ RTX 50 | `NVPRESENT_ENABLE_SMOOTH_MOTION=1` — yalnız FG'siz oyunlarda |
| NGX güncelleyici (DLL OTA) | ✔ | `PROTON_ENABLE_NGX_UPDATER=1` → prefix `ProgramData/NVIDIA/NGX/` |

**Kurallar:**
- **Smooth Motion ile oyun-içi FG/MFG asla birlikte kullanılmaz** (resmî uyarı:
  artefakt + daha düşük performans). Eskiden `gamerun` bunu zorluyordu; artık
  **zorlayan yok** — ikisini aynı launch options'a yazmamak sende.
- FG/MFG yalnız DLSS-FG içeren oyunlarda çalışır; içermeyenlerde Smooth Motion.
- DLSS override'ları **OptiScaler ile çakışır** (ikisi de aynı NGX/nvapi
  katmanına oynar) — OptiScaler kullanan oyunda DLSS satırlarını yazma.
- Frame gen çıktısı VRR ile en iyi sonucu verir (AC'de otomatik açık).

## 860M (iGPU) FSR4 durumu — 30 Tem 2026 araştırması

AMD'nin kendi resmi tutumu RDNA 3.5 entegre grafiklere (890M/880M/**860M**/840M) FSR 4.1
için "planlamıyoruz" iken, pratikte Valve'in Proton-CachyOS'u (protonfixes'in
`upscalers.py` + AMD'nin **kendi indirme sunucusundan** çektiği gerçek `amdxcffx64.dll`
4.1.1) bunu zaten fiilen çalıştırıyor. Doğrulanan mekanizma:

- **Native FSR4 oyunlar** (Resident Evil Requiem, PRAGMATA, KCD2 — `amd_fidelityfx_loader_dx12.dll`
  + `amd_fidelityfx_upscaler_dx12.dll`'i kendi kurulum klasöründe taşıyanlar): hiçbir ek
  ayar gerekmez, menüde "FSR 3.1.x" yazsa bile driver'ın FSR4 modeli sessizce araya giriyor
  (AMD'nin "sessiz arka uç yükseltmesi" tasarımı — oyun kodu değişmeden).
- **Native olmayan oyunlar** (KCD1, Ghost of Tsushima, Hogwarts Legacy — hiç FSR4 dosyası
  yok ya da yalnız eski FSR 3.1 var): **OptiScaler** enjeksiyonuyla zorlanabiliyor —
  `dxgi.dll` kılığına girip present zincirine giriyor, FSR4 paketini (`amdxcffx64.dll` ya
  da `amd_fidelityfx_*_dx12.dll` üçlüsü) `umu/` altına indirip kullanıyor.

**Çalışan tarif (yalnız upscale, FG olmadan) — hem native hem native-olmayan oyunda aynı:**
```
PROTON_USE_OPTISCALER=1 PROTON_FSR4_UPGRADE=1 PROTON_OPTISCALER_CONFIG="Spoofing.Dxgi=false" %command%
```
`Spoofing.Dxgi=false` şart — kapatılmazsa OptiScaler oyuna sahte bir GPU kimliği
(gördüğümüz örnek: "AMD Radeon RX 6700 XT / 7.96GB VRAM") bildiriyor, oyun buna göre
kaynak/doku yükleyip gerçek donanımla (860M, 512MB dedike VRAM carveout) uyuşmuyor.

**`hidenvgpu` (STEAM_COMPAT_CONFIG) yanıltıcı — TAM gizlemiyor:** Wine seviyesinde
`WINE_HIDE_NVIDIA_GPU=1` yalnızca DXGI/D3D cihaz listelemesini etkiliyor; oyunun kendisi
NVAPI/Streamline üzerinden gerçek dGPU'yu doğrudan bulup **gerçekten kullanabiliyor**
(kanıt: `nvidia-smi` bir "hidenvgpu" oturumunda `re9.exe`'nin RTX 5060'ta 5.8GB tuttuğunu
gösterdi). Bu yüzden ilk FSR4 testlerindeki "harika" sonuçlar (RE Requiem 90 FPS, Tsushima
60 FPS) **NVIDIA kirliliğiyle şişmişti**. dGPU'yu gerçekten devre dışı bırakmak için kernel
modülü blacklist'i de yetmiyor (bazı servisler `modprobe`'u açıkça çağırıyor, blacklist
yalnız udev'in otomatik yüklemesini engelliyor) — gereken: `boot.extraModprobeConfig`'de
`install nvidia /bin/false` (+ diğer 3 modül) ve `nvidia-powerd.service`'i kapatmak, artı
reboot (Hyprland oturum başında NVIDIA DRM cihazını açıp elinde tuttuğundan canlı sistemde
`modprobe -r` hiç düşmüyor).

**Doğrulanmış gerçek 860M performansı (NVIDIA çekirdekten tamamen kaldırılmış, temiz
ölçüm, max ayarlar):** RE Requiem ve Tsushima **30-45 FPS** bandında — ilk (kirli) 90/60
FPS değil. 12 CU'luk saf entegre grafikte AAA oyun için makul/oynanabilir ama dGPU'yla
kıyaslanamaz; en baştaki teorik tahminle (3-6× çıplak güç farkı, FSR4 bunu kapatmaz yalnız
oynanabilir kılar) tutarlı.

**Frame Generation — ÇALIŞMIYOR, denenip vazgeçildi:** Aşağıdakilerin HİÇBİRİ FG'yi
860M'de kararlı hale getirmedi (sırayla denendi, her biri farklı şekilde bozdu):
- `Spoofing.StreamlineSpoofing=false` → hâlâ yanlış GPU + parlama (yalnız FG açıkken)
- `FrameGen.fginput=fsrfg` (nukems/DLSSG-taklit yolundan kaçış) → ana menüden itibaren
  parlama + oyuna girince tam çökme (Wine SEH/unwind, gerçek unhandled exception)
- Wine prefix `Version=win11` + `PROTON_MLFG_UPGRADE=1` (OptiScaler wiki'nin resmi
  gereksinimi) → çökme yerine 14-15 FPS'e çöküş
- `FSR.Fsr4ForceEnableInt8=true` (RDNA3/3.5 mobil için FP8→INT8 zorlaması, OptiScaler'ın
  kendi APU notu) → yine düzelmedi
**Sonuç:** Bu donanım/yazılım yığınında (RDNA 3.5 iGPU + OptiScaler + Linux) FG şu an
güvenilir değil — daha fazla ini ayarı denemek yerine yalnız upscale ile kalınıyor.

## Düşük gecikme kare tempolama (31 Tem 2026 · anahtar değişti 2 Eyl 2026)

> **2 Eyl 2026:** `GR_LL=1` takma adı kaldırıldı. Artık üç env doğrudan yazılır:
> `PROTON_DXVK_LOWLATENCY=1 PROTON_VKD3D_LOWLATENCY=1 DXVK_FRAME_PACE=low-latency-vrr-165 gamerun %command%`
> Aşağıdaki metin aynen geçerli; yalnız `GR_LL=1` yerine bu üçlüyü oku.

Proton-CachyOS **11.0-20260703** (bizim pinlediğimiz sürüm, 22 Tem 2026'da yayınlandı)
netborg-afps'in iki eklentisini getirdi. Store'daki `version` dosyalarından
doğrulandı — tahmin değil:

```
files/lib/wine/dxvk/version              dxvk (v3.0.2-2)                 ← D3D11 tabanı
files/lib/wine/dxvk-low-latency/version  low-latency-framepacing-2.7.1   ← PROTON_DXVK_LOWLATENCY
files/lib/wine/vkd3d-low-latency/version vkd3d-low-latency initial-rel.  ← PROTON_VKD3D_LOWLATENCY
files/lib/wine/vkd3d-proton/version      vkd3d-proton (vkd3d-1.1-5438)
```

**GE-Proton11-1'de bu env'lerin ikisi de YOK** (`grep PROTON_.*LOWLATENCY proton` boş
döner) → Steam'de o oyuna **Proton-CachyOS seçilmezse bu env'ler sessizce no-op**.

**Ne yapıyor:** NVIDIA Reflex API'sini çeviri katmanının *içinde* uyguluyor —
`VK_NV_low_latency2`'ye dönüştürmeden. Ayrıca Waitable DXGI Swapchain ile kare
tempoluyor. `DXVK_FRAME_PACE=low-latency-vrr-165` seçilir: bu mod v-blank'i
hesaba katıp fazladan v-sync tamponlama gecikmesini kesiyor. Bu makinede uyum tam —
165 Hz panel + Hyprland `misc.vrr = 2` (tam ekranda VRR açık) + oyunların tam ekran
varsayılanı. Başka hedef istenirse doğrudan değiştir:
`DXVK_FRAME_PACE=low-latency-vrr-120 PROTON_DXVK_LOWLATENCY=1 gamerun %command%`.

**Neden varsayılan DEĞİL de opt-in (üstakım README'sindeki sınırlar):**

| Sınır | Sonuç |
|---|---|
| Frame Generation **desteklenmiyor** | DLSSG (FG/MFG) env'leriyle birleşmez. **Eskiden `gamerun` uyarıp yok sayardı; artık zorlayan yok** — ikisini aynı satıra yazma |
| Oyun Reflex marker'ı (Simulation Start + Present Begin) göndermeli, ya da Waitable Swapchain kullanmalı | Desteklemeyen oyunda **hiçbir etkisi yok** |
| Kareler `dxgi.present()` öncesi CPU'da örtüşmüyor | CPU-bound sahnede **tavan FPS düşebilir** |
| D3D12 tarafı "initial-release" | VRR pacing modu D3D12'de henüz yok (planlı) |
| Intel GPU / AMD Anti-Lag 2 | Desteklenmiyor — bizde ilgisiz (NVIDIA offload) |

**Ölçüm nasıl yapılır:** FPS değil **gecikme** ölçülmeli — bu bir FPS özelliği değil.
Aynı sahnede bu env'lerle ve onlarsız input→ekran hissini karşılaştır; `nvidia-smi dmon`
ile GPU kullanımının düşmediğini teyit et (düşüyorsa CPU-bound sınırına takıldın demektir,
o oyunda kapat).

Kaynaklar: [vkd3d-low-latency](https://github.com/netborg-afps/vkd3d-low-latency) ·
[dxvk-low-latency](https://github.com/netborg-afps/dxvk-low-latency) ·
[proton-cachyos 11.0-20260703](https://github.com/CachyOS/proton-cachyos/releases/tag/cachyos-11.0-20260703-slr) ·
[GamingOnLinux duyurusu](https://www.gamingonlinux.com/2026/07/proton-cachyos-adds-support-for-vkd3d-low-latency-upgrades-d7vk-and-more/)

**DXVK 3.0.2 zaten aktif** (25 Haz 2026): dxbc-spirv derleyicisi eski shader çeviri
kodunun yerini aldı — üretilen SPIR-V daha kompakt, bazı oyunlarda ~1 GiB daha az sistem
belleği, shader derlemesi tamamen worker thread'lere taşındı (açılış süresi + stutter).
Aksiyon gerekmiyor, Proton güncellemesiyle geldi.
[DXVK 3.0 duyurusu](https://www.phoronix.com/news/DXVK-3.0-Release)

## 31 Tem 2026 — donanım-performans denetimi (CPU/iGPU/dGPU/RAM/SSD/NPU)

Kapsamlı "her parça maksimum potansiyelini kullanıyor mu" denetimi — araştırma + canlı
doğrulama, spekülasyon değil. Sonuç: sistem parça başına zaten iyi ayarlanmış; aşağıda
parça parça bulgular.

**Kod temizliği:** `deadnix`/`statix` beklenen taban çizgisinde (tek deadnix hit'i
hardware-configuration.nix, statix sıfır); grep ile GNOME/Sway kalıntısı arandı —
bulunan HER referans ya tarihsel açıklama yorumu ya da hâlâ gerçekten kullanılan bileşen
(`gnome-keyring` servisi, `swaync` bildirim daemonu — isimlerinde "gnome"/"sway" geçiyor
ama masaüstü ortamlarıyla ilgisiz, bağımsız araçlar). 30 Tem'deki GNOME+Sway kaldırma işi
temizmiş — silinecek gereksiz kod yok.
(Sonradan not: `swaync` o gün gerçekten kullanılıyordu, 9 Ağu 2026'da Caelestia
geçişiyle kaldırıldı — bugün depoda yalnız tarihsel yorumlarda geçiyor. `gnome-keyring`
duruyor.)

**Radeon 860M / Mesa:** canlı sürücü **Mesa 26.1.5** (RADV KRACKAN1 — Krackan Point'i
isimle tanıyor, olgun destek işareti). Mesa 26.0 (11 Şub 2026) RDNA3/3.5/4 ray-tracing
performansına Wave32 shader yolu getirdi (RADV) — 860M'nin asıl darboğazı zaten RT değil
ham CU sayısı (yukarıdaki FSR4 bulgusuyla birlikte okunmalı. 26.1.6 (29 Tem, 2 gün önce)
yalnız bakım sürümü — kaçırılan bir şey yok, nixpkgs güncellemesiyle otomatik gelir.

**RTX 5060 / Dynamic Boost — `gpu.nix`'teki eski açık soru kapandı:** nvidia-powerd
canlıda sağlıklı (D-Bus bağlı, çökmüyor); tek yinelenen log satırı SBIOS'un "DC
controller"ı (pil modu) kapatması — bu repo zaten tüm boost mantığını AC'ye kilitlediği
için muhtemelen zararsız. Asıl kanıt versiyon numarası değil: ACBT WMI yazımı (0x4C,
aero-power-profile) → nvidia-powerd okuması → GPU tavanı zinciri KCD'de **38W→70-83W**
ölçüldü (`gaming-performance-project` belleği) — bu, jenerik "Dynamic Boost AMD CPU'da
çalışmıyor" sınırlamasından (NVIDIA/open-gpu-kernel-modules **#392**, 2022'den beri açık,
"Feature Pending/NV-Triaged") bağımsız çalışıyor; bu makinedeki kazanç WMI yan-kanalından
geliyor, nvidia-powerd'in kendi jenerik mekanizmasından değil. Sürüm avcılığına (latest
vs pin) gerek yok.

**CPU / amd-pstate prefcore — GÜNCELLENDİ 16 Ağu 2026; 10 Ağu'daki güncelleme DE YANLIŞTI:**
`amd_pstate=active` doğru, `prefcore` = **disabled** hâlâ geçerli — ama bu bir eksiklik
değil, HFI'li tasarımlarda upstream'in kasıtlı davranışı (yama: *"cpufreq/amd-pstate:
Disable preferred cores on designs with workload classification"*). Sıralamayı HFI veriyor:
`amd_hfi` sürücüsü `AMDI0104:00`'e **bağlı**, ITMT **açık** (`sched_itmt_enabled = Y`),
`sched_core_priority` Zen5'te 196/203 Zen5c'de 135. 10 Ağu'daki "zamanlayıcıya hiç
ulaşmıyor" sonucu, KALDIRILMIŞ `/proc/sys/kernel/sched_itmt_enabled` yoluna ve yanlış
platform düğümüne bakmaktan doğdu — arayüz `/sys/kernel/debug/x86/` altında, root ister.
"scx_lavd zaten telafi ediyor" varsayımı yine de yanlış: scx_lavd latency-aware ama
Zen5/Zen5c kapasite farkından habersiz. Sonuç: bu iş
"bilgi amaçlı" değilmiş — `system/kernel/cores.nix` (elle Zen5c maskesi) ve
`gamerun`'ın `taskset -c 0-15`/`GR_PIN` kolu bu yüzden eklendi. Tam kanıt
zinciri: `Documentation/aerox16/cpu-hybrid.md`.

**NPU (XDNA2):** `amdxdna` sürücüsü tamamen AI/ML inference (kernel accel API) için;
gaming/upscaling bağlamında (FSR4/DLSS gibi) hiçbir kullanım YOK — ikisi de shader/
tensor-core üzerinden çalışıyor, NPU'ya hiç uğramıyor. `power.nix`'teki mevcut
`boot.blacklistedKernelModules = [ "amdxdna" ]` **doğru karar**, değiştirilmedi.

**DDR5 — doğrulandı, zaten optimal:** `sudo dmidecode` çıktısı (kullanıcı tarafından
paylaşıldı): 2× 16GB Micron/Crucial `CT16G56C46S5` SODIMM, gerçek dual-channel (Kanal A +
Kanal B, tek DIMM'de değil). **5600 MT/s @ 1.1V — bu parçanın kendi JEDEC anma hızı**,
EXPO'yla açılan bir üst profil değil (laptop SODIMM'de EXPO/XMP pratik olarak hiç
bulunmaz, masaüstü DIMM'e özgü bir kategori; bu Crucial serisi zaten JEDEC-only). OS'tan
kolu yok (undervolt kilidiyle aynı kategori: donanım/firmware sınırı) ama burada zaten
kapanacak bir şey de yok — RAM olabileceği en hızlı noktada. Fiziksel dizi 64GiB'a kadar
büyüyebilir (32GiB kurulu) — donanım yükseltmesi isteği olursa headroom var, yazılım
tarafında yapılacak bir şey değil. BIOS FB0A (28 May 2026)/EC 3.10 — bu makinede EC hand-
reverse-engineered olduğundan (`Documentation/aerox16/wmi-ec.md`) BIOS güncellemesi önerilmiyor.

**NVMe:** `/sys/block/nvme0n1/queue/scheduler` = **none** (aktif) — NVMe için zaten doğru
seçim (donanım kendi çoklu kuyruğunu yönetiyor, mq-deadline/kyber üstüne binen ek yalnız
gecikme ekler). APST `power/control` = **auto**. İkisi de zaten optimal, değişiklik yok.

**scx_lavd / GameMode (bilgi amaçlı, UYGULANMADI):** 2026'da bir topluluk kalıbı
(blog.foulkes.cloud) GameMode kancalarıyla scx_lavd↔scx_rusty (oyun↔masaüstü) arasında
otomatik geçiş yapıyor — bu repo zaten scx_lavd'ı yalnız oyunda çalıştırıyor (aynı
felsefe), fark: oyun bitince EEVDF'e dönüyor, scx_rusty gibi ikinci bir "masaüstü"
zamanlayıcıya geçmiyor. **Bilinçli olarak eklenmedi**: sürekli koşan (boşta bile) ikinci
bir sched_ext daemon'ı 4.28W idle bütçesine yeni, ölçülmemiş bir risk ekler (`gaming.nix`
tepesindeki "pil/idle tabanı GERİLEMEZ" kısıtı). İstenirse ayrı ölçümle (idle watt A/B)
değerlendirilebilir — şu an öneri, karar kullanıcıda.

## Doğrulama komutları

```bash
# Kurulum sonrası (bir kez):
ls -l /dev/ntsync                 # crw-rw-rw-
swapon --show                     # zram0 prio 5 + nvme prio -1
sysctl vm.max_map_count           # 2147483642
hyprctl getoption misc:vrr                            # int: 2

# gamerun'ı Steam'siz, 5 saniyede sına (2 Eyl 2026 — her şey bunun üstünde duruyor):
gamerun                            # rc=2 + "%command% EKSİK" uyarısı
gamerun sh -c 'grep Cpus_allowed_list /proc/self/status'   # 0-15 (maske delindi)
gamerun sh -c 'env | grep ^__NV'   # PRIME offload üçlüsü
gamerun sleep 5 &                  # koşarken: aşağıdaki "oyun sırasında" bloğu
                                   # bitince: game-perf inactive + fan_mode 1'e döner
GR_NOPERF=1 gamerun <oyun>         # arıza ikilemesi: perf zinciri olmadan aç

# gamerun artık Steam'in kum havuzunda bulunuyor mu (10 Ağu 2026 düzeltmesi):
rg 'command not found' ~/.local/share/Steam/logs/console-linux.txt | tail   # yeni satır OLMAMALI
rg 'gamerun: başlıyor' ~/.local/share/Steam/logs/console-linux.txt | tail   # 2 Eyl'den sonra HER launch'ta OLMALI
rg 'gamemodeauto: dlopen failed' ~/steam-*.log | tail                       # yeni satır OLMAMALI (gamemode zincirden çıktı)
taskset -pc <oyun pid>                                                      # 0-15 (GR_PIN yoksa)

# Oyun sırasında (AC'de):
cat /sys/kernel/sched_ext/state /sys/kernel/sched_ext/root/ops   # enabled + scx_lavd
systemctl is-active game-perf scx                                # active / active
cat /sys/devices/platform/aorus_laptop/fan_mode                  # 5 (turbo)
nvidia-smi                                                       # yükte ≥75W
nvtop                                                            # (2. terminal) dGPU'da oyun süreci + watt/util
# fişi çek/tak veya uykudan dön → fan_mode turbo'da KALMALI (10 Ağu düzeltmesi öncesi 0'a düşerdi)

# DLSS init şüphesinde:
PROTON_LOG=1 gamerun %command%    # ~/steam-<appid>.log içinde nvapi/ngx satırları
ls ~/.local/share/Steam/steamapps/compatdata/<appid>/pfx/drive_c/ProgramData/NVIDIA/NGX/

# Oyun kapandıktan sonra:
systemctl is-active scx           # inactive; sched_ext/state → disabled
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor     # PPD yönetiminde (amd-pstate active → powersave+EPP)
```

## Bilinen sınırlar

- `PROTON_ENABLE_WAYLAND=1` (Proton Wayland) Steam Overlay ve Steam Input'u bozar — yalnız test için.
- ntsync artık varsayılanda zorlanmıyor (Proton/GE kendi per-game blocklist'iyle
  karar verir); bir oyunda faydası varsa `PROTON_USE_NTSYNC=1`, sorun çıkarırsa `=0`.
- NVIDIA sürücü `nvidiaPackages.latest` (`system/drivers/gpu.nix`; şu an 610.43.03) —
  `nix flake update` nixpkgs'i tazeleyince sürücü de oynayabilir. Belirli sürüme geri
  pinlemek: `mkDriver { version + hash }` (Dynamic Boost gerekçesi gpu.nix'te).
- Kernel 7.x + Blackwell'de bilinen s2idle resume hang riski (open-gpu issue #1117);
  dGPU suspend'de D3cold'da olduğundan pratikte atlanıyor — uyandırma takılırsa ilk şüpheli.
- Tearing: bu not GNOME/mutter döneminden kalma (mutter tearing sunmuyordu, VRR
  tek çıkış yoluydu) — GNOME 30 Tem'de kaldırıldı, tek oturum artık Hyprland ve
  `allow_tearing` doğrudan mevcut, ama şu an set edilmiyor. Test edilmedi;
  düşük gecikme öncelikli bir başlıkta gerekirse Hyprland pencere kuralına
  `immediate` eklenmesi denenebilir.
- **Renice (-20) artık UYGULANMIYOR** (2 Eyl 2026): gamemode zincirden çıktı.
  Steam yolunda zaten hiç uygulanmamıştı. Gecikme kolu scx_lavd `--performance`.
- gamescope + MangoHud KALDIRILDI (22 Tem 2026): gamescope bu hibritte çöküyordu, MangoHud
  fazladan bir Vulkan katmanıydı. Ölçüm dış araçla (nvtop/nvidia-smi).
  **Aynı gerekçe 2 Eyl 2026'da `DXVK_NVAPI_VKREFLEX` katmanını da düşürdü** —
  "araya katman koyma" bu makinede tekrar eden bir arıza sınıfı, tek seferlik
  bir olay değil. Yeni bir Vulkan katmanı eklemeden önce bu iki vakayı oku.

## Faz E — Deneysel EC kolları (0xED, 0xF1–F3) · KOŞU BAŞINA ONAY

Amaç: GCC'nin Windows'ta kullandığı iki denenmemiş kolu ölçümle keşfetmek:
`0xED` (muhtemel bütünleşik performans profili 0–3) ve `0xF1/0xF2/0xF3`
(SPL/SPPT/FPPT, mW). Ayrıntılı protokol ve log tablosu: `Documentation/aerox16/wmi-ec.md`
"Deneysel 0xED / 0xF1–F3 logu" bölümü.

Yeni kol (2026-07-12): SSDT9 PC00→PCI0 düzeltmesiyle **`0x4B` (dGPU TGP set,
75–87 W)** artık canlı — ACBT'nin (0x4C) yanına ince sustained-TGP ayarı;
ayrıntı `Documentation/aerox16/wmi-ec.md` "SSDT9 PC00→PCI0 düzeltmesi". game-perf
entegrasyonu ölçüm ister, henüz bağlanmadı.

**SONUÇ (31 Tem 2026) — 0x4B ve 0xF1-F3 KAPANDI, bir daha denenmeyecek:**
SSDT9 tablosu initrd'den sağlıklı yükleniyor (dmesg doğrulandı) ve beklenen
faydalardan biri kanıtlandı: NVRM PSHAREPARAMS spam'i bitti (0 kayıt, eski
baseline 32/boot). Ama kullanıcı hem `0x4B` (dGPU TGP) hem `0xF1/0xF2/0xF3`
(CPU SPL/SPPT/FPPT) için şunu doğruladı: **EC yazılan değeri kendi otomatik
geri alıyor** — kalıcı değil, bu ikisi çalışmıyor. Fark: `0xED`/`0x4C` (ACBT)
EC'nin TANIDIĞI, kendi önceden tanımlı modları arasından seçim — EC bunu
benimseyip tutuyor (KCD 38W→70-83W ölçümüyle kanıtlı). `0x4B`/`0xF1-F3` ham,
EC'nin sürekli yeniden hesapladığı limit alanları — dışarıdan tek seferlik yazım
tutmuyor. CPU'nun 21W sürdürülebilir kıskacının kaynağı hâlâ bilinmiyor ama bu
selector'lar üzerinden açılamıyor; undervolt/CO kilidiyle (`Documentation/aerox16/undervolt.md`) aynı tema — bu board'da OS'tan alınabilecek daha fazla güç-limiti
kontrolü yok, mevcut 0xED/ACBT zinciri zaten en iyi kanıtlanmış kol. Ayrıntı:
bellek `ec-power-limit-self-revert`.

**Güvenlik kartı:**
- EC bu makinede **uçucu**: şarj limiti/fan/ACBT her boot yeniden uygulanıyor →
  kötü değerde **reboot = temiz sayfa**; ACBT için `systemctl start aero-power-profile`.
- Donma/anomali → güç tuşu 15 sn (sert kapanış), gerekirse AC çek.
- SMU korumaları EC isteklerinden bağımsız (CPU zaten 95°C tavanında kıskaçlı) —
  donanım hasarı gerçekçi değil; en kötü bedel kaydedilmemiş iş kaybı.
- **YASAK:** `0x51` (3 = dGPU eject!) ve CMOS/NVRAM'a yazan `0x63, 0x87, 0x88,
  0xA3, 0xE6` (reboot ile SIFIRLANMAZ — uçuculuk güvencesi geçersiz).

**Protokol özeti** (AC + fan_mode 2 + işler kayıtlı):
1. Taban ölç: RAPL 10 sn delta (`/sys/class/powercap/*/energy_uj`), `nvidia-smi dmon`,
   sabit yük (aynı oyun sahnesi 2 dk veya stress-ng) + frametime (oyun-içi sayaç / nvidia-smi dmon).
2. **Tek yazım**, sonra ölç, sonra logla:
   `echo '\_SB.PCI0.AMW0.WMBD 0 0xED 1' > /proc/acpi/call` (profil 1'den başla).
   0xF1 için GCC değer uzayında kal: `0xF1 25000` (SPL 25W) → RAPL tepkisi var mı?
3. Geri-okuma: 0xED sonrası NPCF alanları (`ACBT`/`AMAT`, Faz D yöntemi); 0xF1–F3
   geri-okuması RAPL davranışından (Get metodu yok).
4. Geri dönüş: tam temizlik = **reboot**; ACBT restorasyonu = `aero-power-profile`.
5. Abort: RAPL 2 denemede tepkisiz → faz kapat · sürekli >95°C / termal gariplik →
   derhal reboot · input/ekran anomalisi → güç 15 sn.
6. Kanıtlanan kazanç `game-perf.service`'e kalıcı eklenir (oyun-anı kapsamı korunur).
