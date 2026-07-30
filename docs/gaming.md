# AERO X16 — Oyun Kurulumu ve Kullanımı

*Kurulum: 2026-07-05 · Sürücü: NVIDIA 610.43.02 (open) · Kernel 7.1.1 · DLSS 4.5 dönemi*

## Mimari özet

```
Steam (iGPU'da açılır)
  └─ launch options: gamerun %command%
       ├─ dGPU PRIME offload (RTX 5060)
       ├─ DLSS 4.5 zinciri: NGX updater + SR/RR/FG override (render_preset_latest)
       ├─ Reflex (DXVK_NVAPI_VKREFLEX) + ntsync (PROTON_USE_NTSYNC)
       ├─ Blackwell DX12/VKD3D kaçış-flag'leri (opt-in: GR_VKD3DNOCACHE / GR_HEAP / GR_VKD3D)
       └─ exec gamemoderun
            ├─ renice -20 + ioprio 0 (oyun süreci — maksimum normal öncelik)
            └─ start kancası → game-perf.service
                 ├─ scx_lavd --performance
                 ├─ AC'deyse WMBD 0xED profil 2: ACBT 160 + agresif fan eğrisi
                 │  (KCD ölçümü: GPU 38W→~70W sustained; fan %32-35→%46-49)
                 ├─ AC'deyse fan_mode 5 (turbo/max) — "oyunlarda hep soğuk" tercihi
                 └─ AC'deyse PPD → balanced (GPU-öncelik; GR_CPUMAX=1 ise performance)
               oyun bitince: stop → scx durur (EEVDF döner) + 0xED profil 0 +
               gigabyte-power-profile (ACBT 80/fan modu AC→0'a geri) +
               power-display (PPD → balanced, fişte / power-saver, pilde)
```

**Turbo fan (2026-07-17):** oyun süresince (AC'de) fanlar tam güce alınır (fan_mode 5,
~6900 RPM) → dGPU en soğuk + fan tepkisi maksimum. **CPU yine ~95°C** olur (EC/SMU
tavanı; hiçbir fan bunu değiştirmez — bkz. `docs/aerox16-1vh-wmi.md` preset
karakterizasyonu) ve **seslidir** — bilinçli tercih. Pilde uygulanmaz (oyun zaten
güç-limitli). Oyun bitince gigabyte-power-profile fan modunu AC→0'a (dengeli) döndürür.

Donanım tarafı zaten AC'ye bağlı otomatik: fiş takılıyken fan modu 2 ("oyun") +
NPCF.ACBT 80W → nvidia-powerd dGPU'yu 75–85W bandına çıkarır
(`modules/hardware/gigabyte-wmi.nix`). VRR Hyprland'ın `misc.vrr = 2` ayarıyla açık
(`hyprland-rice/lua/main.lua`); yalnız tam ekranda devreye girer. Pilde panel zaten
60Hz'e çekilir (`power-display-user`, power-display.nix).

**GPU-öncelik: oyunda PPD balanced (18 Tem 2026).** CPU ile dGPU, ACBT 80W'lık
NVIDIA Dynamic Boost bütçesini **paylaşır**. Oyunda PPD `performance` yapılırsa
amd-pmf CPU'ya en yüksek STAPM preset'ini basar → CPU 100°C Tjmax'inde bütçeyi yer →
nvidia-powerd dGPU'ya ancak ~30W verir (tavan 85W → **açlık**, güç-limiti değil).
Bu yüzden oyun varsayılanı artık `balanced`: CPU STAPM tavanı düşer, klok yine talep
üzerine yükselir (EPP=balance_performance), bütçe dGPU'ya kayar → GPU-bound oyunda
daha çok watt + FPS. CPU-bound oyun (bazı sim/strateji, KCD kalabalık şehir) için
`GR_CPUMAX=1` ile performance'a dön. **Not:** CPU'yu undervolt ile soğutmak bu
makinede platform-kilitli (`docs/undervolt-curve-optimizer.md`); güç-iştahını kısmak
tek kullanılabilir kol. 100°C by-design'dır (Zen5 mobil Tjmax hedefi), arıza değil.

**Pilde oyun:** tasarım gereği kısıtlı — CPU 2GHz tavan + boost kapalı + ACBT 0.
Tam performans için fişe tak. Pil/idle tabanı (4.28W) bu kurulumdan etkilenmez:
boşta scx inactive, zram pasif, gamemoded uykuda.

## Launch options matrisi

| Amaç | Launch options |
|---|---|
| **Taban** (DLSS 4.5 SR/RR + Reflex, tam ekran) | `gamerun %command%` |
| MFG 4x (FG override'ı da açar; FG'yi oyun menüsünden aç) | `GR_MFG=4 gamerun %command%` |
| Dinamik MFG — 165 FPS hedef, otomatik çarpan | `GR_DYNFG=165 gamerun %command%` |
| DLSS FG override'ı aç (MFG'siz) | `GR_FG=1 gamerun %command%` |
| DLSS render preset'i zorla (en yeni) | `GR_PRESET=latest gamerun %command%` |
| ntsync'i zorla aç / kapat | `GR_NTSYNC=1 gamerun %command%` / `GR_NTSYNC=0 …` |
| Smooth Motion (DLSS'i OLMAYAN oyuna sürücü framegen) | `GR_SMOOTH=1 gamerun %command%` |
| Tek-çekirdek sim oyunu (HOI4/Stellaris/Factorio) | `GR_PIN=big gamerun %command%` |
| CPU tam güç (CPU-bound oyun; varsayılan balanced/GPU-öncelik) | `GR_CPUMAX=1 gamerun %command%` |
| Proton Wayland (deneysel) | `GR_WL=1 gamerun %command%` |
| Windowed aç (verilen boyutta) | `GR_WIN=1920x1200 gamerun %command%` |
| **Blackwell:** DX12 bir süre sonra donarsa → VKD3D cache kapat (#2793) | `GR_VKD3DNOCACHE=1 gamerun %command%` |
| **Blackwell:** Xid 109 sert çökme fix (o oyuna Proton-CachyOS seç) | `GR_HEAP=1 gamerun %command%` |
| **Blackwell:** ham VKD3D_CONFIG (dxr11 / force_raw_va_cbv…) | `GR_VKD3D=dxr11 gamerun %command%` |

**Pencere modu (17 Tem 2026):** `gamerun` artık **varsayılan tam ekran** — hiçbir
pencere argümanı eklemez, oyunlar kendi (genelde tam ekran) davranışını kullanır.
Windowed default eski Hyprland+waybar rice'ı içindi; GNOME'da gereksiz. `GR_WIN=WxH`
verilirse windowed'a geçer: `-w/-h/-freq/-windowed` (Source) + `-screen-*` (Unity —
House Flipper, Phasmophobia, Planet Crafter). Tanımayan motorlar yok sayar; onlarda
çözünürlük config'ten gelir (FromSoft GraphicsConfig.xml, HOI4 settings.txt, Hogwarts
GameUserSettings.ini, KCD user.cfg, RE Engine config.ini). **NOT:** o config'ler daha
önce windowed'a çevrilmişti (`*.bak` yedekleri var) → tam ekran default'a rağmen yine
pencereli açılırlar; tam ekran istenirse `*.bak`'tan geri alınır.

**Öncelik (18 Tem 2026):** oyun süreci artık `renice -20` (maksimum normal öncelik) —
gamemode grubu + `enableRenice`. scx_lavd bunu ağırlık olarak onurlandırır → oyun,
normal-sınıf görevler içinde en yüksek öncelikli. **Gerçek RT (SCHED_FIFO/RR) bilinçli
olarak KULLANILMADI:** RT sınıfı sched_ext'in üstünde koşar → scx_lavd'ı (oyun için
tasarlanan latency-aware zamanlayıcı) bypass eder, ayrıca bir thread busy-loop yaparsa
makineyi kilitleyebilir. nice -20 + scx_lavd, RT davranışını riski olmadan verir
(SteamOS/CachyOS de bu yolu izler).

**Blackwell (RTX 5060) DX12/VKD3D kararlılık — kaçış-flag'leri (opt-in, 22 Tem 2026):**
DXVK (D3D9/10/11→Vulkan) + VKD3D‑Proton (D3D12→Vulkan) + dxvk‑nvapi (DLSS/Reflex) zaten
her Proton oyununu Vulkan'a çevirir. Blackwell'e özgü iki bilinen kararsızlık ve cerrahi
(oyun-başına, VARSAYILAN KAPALI) çözümleri — kullanıcıda şu an sorun yok, gerektiğinde aç:

- **`GR_VKD3DNOCACHE=1`** → `VKD3D_SHADER_CACHE_PATH=0`. NVIDIA'da bazı DX12 oyunları
  dakikalar–saatler sonra donuyor/sessizce çöküyor (vkd3d-proton **#2793**, Ocak 2026;
  RTX 4070 **ve** 5070 doğrulanmış). VKD3D shader cache'i kapatmak donmayı bitirir;
  **bedeli** ilk-render shader stutter'ının artması → yalnız donan o oyunda aç.
- **`GR_HEAP=1`** → `PROTON_VKD3D_HEAP=1` (VK_EXT_descriptor_heap). Blackwell'de bazı DX12
  oyunlarının shader-derleme fazında **Xid 109 sert çökmesi** (vkd3d-proton **#2914** / PR
  #2805; ör. Crimson Desert). Fix yalnız descriptor_heap içeren Proton'da etkin → o oyuna
  **Steam'de Proton-CachyOS** seç (aşağı bak); GE-Proton'da zararsız no-op.
- **`GR_VKD3D=<token>`** → ham `VKD3D_CONFIG` passthrough. İleri per-oyun: `dxr11` (D3D12
  raytracing zorla), `force_raw_va_cbv` (bazı NVAPI/DLSS kurulumları), vb.

**Proton-CachyOS (Blackwell-sertleştirilmiş, 22 Tem 2026):** `modules/apps/default.nix`
artık GE-Proton'un **yanına** Proton-CachyOS'u da kurar (`chaotic-nyx` flake input +
`nyx-cache.chaotic.cx` binary cache). Steam'de oyun-başına seçilir (Özellikler → Uyumluluk).
GE-Proton **varsayılan** kalır; inatçı DX12/Blackwell oyunlarında (Xid 109, #2793 donma)
Proton-CachyOS + `GR_HEAP=1` dene — en güncel dxvk/vkd3d + VK_EXT_descriptor_heap içerir.

**Oyunları Vulkan'a taşıma (launcher tarafı — kullanıcı uygular):**
- **HOI4 (ve diğer Paradox / native-OpenGL oyunları):** Steam → Özellikler → Uyumluluk →
  "Force GE-Proton (veya Proton-CachyOS)". Native Linux OpenGL yerine oyun D3D11→**DXVK→
  Vulkan** koşar (5060'ta daha stabil). Tek-thread sim → `GR_PIN=big gamerun %command%`.
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
(Zen5c 3.5GHz dışarıda), `fast` = yalnız cpu4/6+SMT (prefcore 208),
veya özel liste (`GR_PIN=0,2,4`). Normal oyunlarda gerekmez — amd-pstate
prefcore + scx_lavd zaten big çekirdekleri önceler; bu, tek-thread'i
sabitleme garantisi isteyen sim oyunları için. Proton sürümü olarak **GE-Proton** veya
**Proton Experimental / Proton 11** seç (ntsync + güncel dxvk-nvapi).

## Minecraft (Prism Launcher)

*Kurulum: 2026-07-15 · `modules/apps/minecraft.nix` (HM katmanı)*

Steam zincirinin native-Java karşılığı — Prism her instance'ı **Wrapper Command**
üzerinden başlatır:

```
Prism Launcher (iGPU'da açılır)
  └─ WrapperCommand=mc-run → __GL_THREADED_OPTIMIZATIONS=0 export → exec gamerun
       └─ gamerun java -Xmx8192m <G1 bayrakları> ...
            ├─ dGPU PRIME offload (RTX 5060) — MC OpenGL, GLX vendor=nvidia yeterli
            ├─ DLSS/Reflex/ntsync env'leri native Java'da ETKİSİZ (zararsız)
            └─ exec gamemoderun → renice -20 + game-perf.service
                 └─ scx_lavd + AC'deyse 0xED profil 2 + turbo fan + PPD balanced
                    (Steam'dekiyle aynı; GR_CPUMAX ile performance)
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
değişiklikleri kalıcı olsun istiyorsan `modules/apps/minecraft.nix`'e işle.
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
| DLSS SR (2. nesil transformer) | ✔ tüm RTX | `gamerun` varsayılan (SR override açık) |
| DLSS Ray Reconstruction | ✔ | `gamerun` varsayılan (RR override açık) |
| DLSS render preset (en yeni) | ✔ | opt-in: `GR_PRESET=latest` (varsayılan: sürücü/oyun) |
| DLSS Frame Generation | ✔ (oyun desteği şart) | opt-in: `GR_FG=1` (ya da GR_MFG/GR_DYNFG); oyun menüsünden de aç |
| Multi Frame Gen 2x–6x | ✔ RTX 50'ye özel | `GR_MFG=2..6` (FG override'ı da açar) |
| Dynamic MFG (hedef FPS) | ✔ RTX 50'ye özel | `GR_DYNFG=165` |
| Reflex (VK_NV_low_latency2) | ✔ | `gamerun` varsayılan (`DXVK_NVAPI_VKREFLEX=1`) |
| ntsync (Proton NT senkron) | ✔ | opt-in: `GR_NTSYNC=1` (varsayılan: Proton karar verir) |
| Smooth Motion (sürücü framegen) | ✔ RTX 50 | `GR_SMOOTH=1` — yalnız FG'siz oyunlarda |
| NGX güncelleyici (DLL OTA) | ✔ | `PROTON_ENABLE_NGX_UPDATER=1` → prefix `ProgramData/NVIDIA/NGX/` |

**Kurallar:**
- **Smooth Motion ile oyun-içi FG/MFG asla birlikte kullanılmaz** (resmî uyarı:
  artefakt + daha düşük performans). `gamerun` bunu zorlar: ikisi birden verilirse
  Smooth Motion'ı yok sayıp uyarı basar.
- FG/MFG yalnız DLSS-FG içeren oyunlarda çalışır; içermeyenlerde `GR_SMOOTH=1`.
- Frame gen çıktısı VRR ile en iyi sonucu verir (AC'de otomatik açık).

## Doğrulama komutları

```bash
# Kurulum sonrası (bir kez):
gamemoded -t                      # gamemode öz-testi (Wayland'de gpu testi uyarısı normaldir)
groups                            # "gamemode" görünmeli (yoksa re-login)
ls -l /dev/ntsync                 # crw-rw-rw-
swapon --show                     # zram0 prio 5 + nvme prio -1
sysctl vm.max_map_count           # 2147483642
hyprctl getoption misc:vrr                            # int: 2

# Oyun sırasında (AC'de):
cat /sys/kernel/sched_ext/state /sys/kernel/sched_ext/root/ops   # enabled + scx_lavd
systemctl is-active game-perf scx                                # active / active
nvidia-smi                                                       # yükte ≥75W
nvtop                                                            # (2. terminal) dGPU'da oyun süreci + watt/util

# DLSS init şüphesinde:
PROTON_LOG=1 gamerun %command%    # ~/steam-<appid>.log içinde nvapi/ngx satırları
ls ~/.local/share/Steam/steamapps/compatdata/<appid>/pfx/drive_c/ProgramData/NVIDIA/NGX/

# Oyun kapandıktan sonra:
systemctl is-active scx           # inactive; sched_ext/state → disabled
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor     # PPD yönetiminde (amd-pstate active → powersave+EPP)
```

## Bilinen sınırlar

- `GR_WL=1` (Proton Wayland) Steam Overlay ve Steam Input'u bozar — yalnız test için.
- ntsync artık varsayılanda zorlanmıyor (Proton/GE kendi per-game blocklist'iyle
  karar verir); bir oyunda faydası varsa `GR_NTSYNC=1`, sorun çıkarırsa `GR_NTSYNC=0`.
- NVIDIA sürücü `nvidiaPackages.latest` (`modules/hardware/gpu.nix`; şu an 610.43.03) —
  `nix flake update` nixpkgs'i tazeleyince sürücü de oynayabilir. Belirli sürüme geri
  pinlemek: `mkDriver { version + hash }` (Dynamic Boost gerekçesi gpu.nix'te).
- Kernel 7.x + Blackwell'de bilinen s2idle resume hang riski (open-gpu issue #1117);
  dGPU suspend'de D3cold'da olduğundan pratikte atlanıyor — uyandırma takılırsa ilk şüpheli.
- Tearing: mutter Wayland'de tearing (async page flip) sunmuyor — en düşük gecikme
  yolu VRR (deneysel özellik açık). Hyprland'deki `allow_tearing` seçeneğinin
  karşılığı yok (eski kurulum: rice/caelestia dalı).
- Renice (-20) ilk kurulumdan sonra **re-login** ister (gamemode grubu).
- gamescope + MangoHud KALDIRILDI (22 Tem 2026): gamescope bu hibritte çöküyordu, MangoHud
  fazladan bir Vulkan katmanıydı. Ölçüm dış araçla (nvtop/nvidia-smi).

## Faz E — Deneysel EC kolları (0xED, 0xF1–F3) · KOŞU BAŞINA ONAY

Amaç: GCC'nin Windows'ta kullandığı iki denenmemiş kolu ölçümle keşfetmek:
`0xED` (muhtemel bütünleşik performans profili 0–3) ve `0xF1/0xF2/0xF3`
(SPL/SPPT/FPPT, mW). Ayrıntılı protokol ve log tablosu: `docs/aerox16-1vh-wmi.md`
"Deneysel 0xED / 0xF1–F3 logu" bölümü.

Yeni kol (2026-07-12): SSDT9 PC00→PCI0 düzeltmesiyle **`0x4B` (dGPU TGP set,
75–87 W)** artık canlı — ACBT'nin (0x4C) yanına ince sustained-TGP ayarı;
ayrıntı `docs/aerox16-1vh-wmi.md` "SSDT9 PC00→PCI0 düzeltmesi". game-perf
entegrasyonu ölçüm ister, henüz bağlanmadı.

**Güvenlik kartı:**
- EC bu makinede **uçucu**: şarj limiti/fan/ACBT her boot yeniden uygulanıyor →
  kötü değerde **reboot = temiz sayfa**; ACBT için `systemctl start gigabyte-power-profile`.
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
4. Geri dönüş: tam temizlik = **reboot**; ACBT restorasyonu = `gigabyte-power-profile`.
5. Abort: RAPL 2 denemede tepkisiz → faz kapat · sürekli >95°C / termal gariplik →
   derhal reboot · input/ekran anomalisi → güç 15 sn.
6. Kanıtlanan kazanç `game-perf.service`'e kalıcı eklenir (oyun-anı kapsamı korunur).
