# AERO X16 — Oyun Kurulumu ve Kullanımı

*Kurulum: 2026-07-05 · Sürücü: NVIDIA 610.43.02 (open) · Kernel 7.1.1 · DLSS 4.5 dönemi*

## Mimari özet

```
Steam (iGPU'da açılır)
  └─ launch options: gamerun %command%
       ├─ dGPU PRIME offload (RTX 5060)
       ├─ DLSS 4.5 zinciri: NGX updater + SR/RR/FG override (render_preset_latest)
       ├─ Reflex (DXVK_NVAPI_VKREFLEX) + ntsync (PROTON_USE_NTSYNC)
       ├─ MangoHud (gizli; F12 aç/kapa)
       └─ exec gamemoderun
            ├─ renice -10 + ioprio 0 (oyun süreci)
            └─ start kancası → game-perf.service
                 ├─ scx_lavd --performance
                 └─ AC'deyse WMBD 0xED profil 2: ACBT 160 + agresif fan eğrisi
                    (KCD ölçümü: GPU 38W→~70W sustained; fan %32-35→%46-49)
               oyun bitince: stop → scx durur (EEVDF döner) + 0xED profil 0 +
               gigabyte-power-profile (ACBT 80/fan modu geri) + tlp start
```

Donanım tarafı zaten AC'ye bağlı otomatik: fiş takılıyken fan modu 2 ("oyun") +
NPCF.ACBT 80W → nvidia-powerd dGPU'yu 75–85W bandına çıkarır
(`modules/hardware/gigabyte-wmi.nix`). VRR AC'de otomatik açılır (yalnız tam ekran,
`misc:vrr 2`), pilde kapanır (PSR çakışması).

**Pilde oyun:** tasarım gereği kısıtlı — CPU 2GHz tavan + boost kapalı + ACBT 0.
Tam performans için fişe tak. Pil/idle tabanı (4.28W) bu kurulumdan etkilenmez:
boşta scx inactive, zram pasif, gamemoded uykuda.

## Launch options matrisi

| Amaç | Launch options |
|---|---|
| **Taban** (DLSS 4.5 SR/RR latest + Reflex + ntsync + HUD) | `gamerun %command%` |
| MFG 4x (oyun menüsünden FG'yi aç) | `GR_MFG=4 gamerun %command%` |
| Dinamik MFG — 165 FPS hedef, otomatik çarpan | `GR_DYNFG=165 gamerun %command%` |
| Smooth Motion (DLSS'i OLMAYAN oyuna sürücü framegen) | `GR_SMOOTH=1 gamerun %command%` |
| FSR upscale (eski/DLSS'siz oyun, gamescope) | `gamerun gamescope -W 2560 -H 1600 -w 1920 -h 1200 -F fsr -f -- %command%` |
| Tek-çekirdek sim oyunu (HOI4/Stellaris/Factorio) | `GR_PIN=big gamerun %command%` |
| ntsync kapat (sorunlu oyun) | `PROTON_USE_NTSYNC=0 gamerun %command%` |
| HUD tamamen kapalı | `GR_NOHUD=1 gamerun %command%` |
| Proton Wayland (deneysel) | `GR_WL=1 gamerun %command%` |

Tüm varsayılanlar `VAR=değer gamerun %command%` ile oyun başına ezilebilir
(sarmalayıcı `:-` deseni kullanır). `GR_PIN`: `big` = 4× Zen5 5.09GHz
(Zen5c 3.5GHz dışarıda), `fast` = yalnız cpu4/6+SMT (prefcore 208),
veya özel liste (`GR_PIN=0,2,4`). Normal oyunlarda gerekmez — amd-pstate
prefcore + scx_lavd zaten big çekirdekleri önceler; bu, tek-thread'i
sabitleme garantisi isteyen sim oyunları için. Proton sürümü olarak **GE-Proton** veya
**Proton Experimental / Proton 11** seç (ntsync + güncel dxvk-nvapi).

## MangoHud (F12)

- Oyun içinde **F12** → HUD açılır/kapanır. Varsayılan **gizli** başlar.
- Kritik metrikler: **FPS ort + %1 low + %0.1 low** (`fps_metrics`), **CPU paket watt**, **dGPU watt**; ayrıca frametime grafiği, sıcaklıklar, saatler, VRAM/RAM, ntsync (WSYNC) ve GAMEMODE aktiflik göstergeleri.
- ⚠ Steam'in varsayılan screenshot tuşu da F12: **Steam → Ayarlar → Oyun İçi →
  ekran görüntüsü kısayolunu** F11 gibi bir tuşa taşı; yoksa F12 ikisini birden yapar.
- Ayarlar: `modules/apps/gaming.nix` (`~/.config/MangoHud/MangoHud.conf`'a yazılır;
  Steam Linux Runtime konteyneri host'taki bu dosyayı okur).

## RTX 5060 özellik durumu (DLSS 4.5, Linux/Proton)

| Özellik | Destek | Nasıl |
|---|---|---|
| DLSS SR (2. nesil transformer) | ✔ tüm RTX | `gamerun` varsayılan (override + preset latest) |
| DLSS Ray Reconstruction | ✔ | `gamerun` varsayılan |
| DLSS Frame Generation | ✔ (oyun desteği şart) | oyun menüsünden aç; `gamerun` FG override'ı açık |
| Multi Frame Gen 2x–6x | ✔ RTX 50'ye özel | `GR_MFG=2..6` |
| Dynamic MFG (hedef FPS) | ✔ RTX 50'ye özel | `GR_DYNFG=165` |
| Reflex (VK_NV_low_latency2) | ✔ | `gamerun` varsayılan (`DXVK_NVAPI_VKREFLEX=1`) |
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
hyprctl getoption misc:vrr        # AC'de 2, pilde 0

# Oyun sırasında (AC'de):
cat /sys/kernel/sched_ext/state /sys/kernel/sched_ext/root/ops   # enabled + scx_lavd
systemctl is-active game-perf scx                                # active / active
nvidia-smi                                                       # yükte ≥75W
# F12 → HUD: %1/%0.1 low + watt + GAMEMODE + WSYNC satırları

# DLSS init şüphesinde:
PROTON_LOG=1 gamerun %command%    # ~/steam-<appid>.log içinde nvapi/ngx satırları
ls ~/.local/share/Steam/steamapps/compatdata/<appid>/pfx/drive_c/ProgramData/NVIDIA/NGX/

# Oyun kapandıktan sonra:
systemctl is-active scx           # inactive; sched_ext/state → disabled
cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor     # TLP profiline döndü
```

## Bilinen sınırlar

- `GR_WL=1` (Proton Wayland) Steam Overlay ve Steam Input'u bozar — yalnız test için.
- GE-Proton bazı oyunlarda ntsync'i bilinçli kapatır (per-game blocklist);
  `gamerun` `PROTON_USE_NTSYNC=1`'i zorlar → sorun görürsen `PROTON_USE_NTSYNC=0`.
- Tearing (en düşük gecikme, VRR yerine): `modules/desktop/hyprland/rules.nix`
  içindeki `steam-tearing` bloğunun yorumunu kaldır + `settings.nix`'te
  `general:allow_tearing = true`. Görsel yırtılma pahasına ~yarım kare gecikme kazancı.
- gamescope `capSysNice` NVIDIA'da kapalı tutuluyor (bilinen sorunlar).
- Renice (-10) ilk kurulumdan sonra **re-login** ister (gamemode grubu).

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
   sabit yük (aynı oyun sahnesi 2 dk veya stress-ng) + MangoHud frametime.
2. **Tek yazım**, sonra ölç, sonra logla:
   `echo '\_SB.PCI0.AMW0.WMBD 0 0xED 1' > /proc/acpi/call` (profil 1'den başla).
   0xF1 için GCC değer uzayında kal: `0xF1 25000` (SPL 25W) → RAPL tepkisi var mı?
3. Geri-okuma: 0xED sonrası NPCF alanları (`ACBT`/`AMAT`, Faz D yöntemi); 0xF1–F3
   geri-okuması RAPL davranışından (Get metodu yok).
4. Geri dönüş: tam temizlik = **reboot**; ACBT restorasyonu = `gigabyte-power-profile`.
5. Abort: RAPL 2 denemede tepkisiz → faz kapat · sürekli >95°C / termal gariplik →
   derhal reboot · input/ekran anomalisi → güç 15 sn.
6. Kanıtlanan kazanç `game-perf.service`'e kalıcı eklenir (oyun-anı kapsamı korunur).
