# AERO X16 1VH — CPU/iGPU/dGPU Undervolt & Curve Optimizer araştırması

**Durum:** KAPANDI (2026-07-12) — **CPU/iGPU Curve Optimizer bu makinede platform
(Gigabyte BIOS/PSP) kilidi altında.** Araç zinciri tam ve doğrulandı; her CO yazma
yolu SMU tarafından bilinçli reddediliyor, `enable-oc` önkoşulu hiçbir kanalla
açılamıyor. Kanıt ve yeniden açma koşulları: "Kampanya logu" → "FAZ 0 KARARI".
Denenen yazmaların hepsi volatil'di ve hiçbiri kabul edilmedi — sistem stok durumda.

Fan/WMI (`wmi-ec.md`, ACPI ERCD/WMBD) ile ortak noktası yok: CPU/iGPU undervolt
**AMD SMU mailbox**'ı üzerinden gider.

---

## Üç katman

| Katman | Yöntem | Bu makinede durum |
|---|---|---|
| CPU Curve Optimizer | SMU mailbox (ryzenadj / ryzen_smu) | ❌ **platform kilitli** (2026-07-12) |
| iGPU (Radeon 860M) CO | Aynı SMU | ❌ aynı kilit; ayrıca ryzenadj `set_cogfx` family 0x1A'yı hiç kapsamıyor |
| dGPU (RTX 5060) VF eğrisi | NVAPI (Windows) / Coolbits (Linux, sınırlı) | Gerçek eğri **Linux'ta mimari kapalı** |

### CPU / iGPU

- **CPU:** AMD Ryzen AI 7 350 "Krackan Point", Zen5, **family 26 (0x1A), model
  0x60**, w/ Radeon 860M.
- Başlangıç hipotezi "kilit yok, araç tamlığı eksik" idi (kullanıcının arkadaşının
  aynı sınıf laptopunda CO çalışıyordu). Araç tarafı tam çıktı (ryzenadj 0.19.0
  Krackan'ı tanıyor, komut/adres/encoding G-Helper+UXTU ile birebir); kilit
  **platformda**. Arkadaş laptopu kanıtı silikon için geçerli, OEM firmware'i için
  değil.
- `ryzen_smu` nixpkgs'te yok; repoda ağaç-dışı modül olarak var
  (`system/kernel/ryzen-smu.nix`) — aynı mailbox'a konuşur, kilidi aşmaz.
- Risk notu: yanlış tablo sürümüyle CO yazmak kararsızlık/donma verebilir; kurtarma
  **reboot** (CO ofseti kalıcı değil). Denemelerde donma/MCE görülmedi.

### dGPU (RTX 5060)

- **Nokta-nokta VF eğrisi** (`NvAPI_GPU_ClientVFAdjustSet`) yalnız Windows NVAPI'de;
  Linux sürücüsü (`nvidia` / `nvidia-open`) bunu userspace'e açmıyor.
- **Güç limiti:** `nvidia-smi -pl <watt>` — bu GPU'da **5-85W aralığı doğrulandı**
  (ACBT/Dynamic Boost ile tavan 50→75W+ zaten entegre; `wmi-ec.md`).
- **Blok saat ofseti:** `nvidia-settings` `GPUGraphicsClockOffset` /
  `GPUMemoryTransferRateOffset` — tüm boost tablosuna sabit kaydırma. **`Coolbits`
  repoda ayarlı DEĞİL**; denemek için `hardware.nvidia` X-config'ine eklemek gerekir.
  Negatif ofset + güç limiti pratikte "poor man's undervolt" verir.

---

## amd-pmf etkileşimi

**`amd_pmf` YÜKLÜ ve AKTİF** (doğrulandı, 2026-07-12): `AMDI0107:00`'a bağlı
(`tee` + `amd_sfh` + `button` bağımlı), `platform_profile`'ı
(`performance / balanced / low-power`) O sağlıyor. 2026-07-18'den beri profili PPD
yazıyor (eskiden TLP `PLATFORM_PROFILE_ON_AC/BAT`).

- dmesg: **"No Smart PC policy present"** → yalnız Static Slider; TEE politika
  jokeri yok.
- **Risk:** Static Slider her `platform_profile` değişiminde (PPD profil değişimi,
  AC↔BAT) STAPM/SPPT/FPPT'yi kendi preset'ine basar → ryzenadj ile elle yazılan
  güç limitleri **sessizce geri döner**. CO ofseti ayrı register sınıfı olduğu
  için etkilenmeyecekti, ama CO zaten yazılamıyor.
- Kurtarma her durumda: reboot → PPD+pmf boot preset'lerini yeniden uygular.

---

## Risk / kanıt matrisi

| İşlem | Araç | Kanıt/Uyum | Risk | pmf reverti |
|---|---|---|---|---|
| dGPU güç limiti | `nvidia-smi -pl` | ✅ doğrulandı (5-85W) | Düşük | Hayır (nvidia ayrı) |
| CPU/iGPU watt limiti (STAPM/PPT) | ryzenadj / EC 0xF1-F3 | Kısmi (EC yolu ECPT ile kanıtlı) | Düşük | **EVET (yüksek)** |
| dGPU saat ofseti | Coolbits + nvidia-settings | Mümkün, config gerekli | Orta | Hayır |
| CPU/iGPU Curve Optimizer | ryzenadj `set_coall/coper/cogfx` | ❌ **PLATFORM KİLİTLİ (2026-07-12)** — SMU tüm CO yazmalarını reddediyor | — (yazılamıyor) | — |
| dGPU gerçek VF eğrisi | — | Linux'ta mimari kapalı | — | — |

## Açık kalan CO-dışı kollar

- [ ] Coolbits + nvidia-settings Wayland altında çalışıyor mu?
- [ ] EC `0xF1-F3` (ECPT) CPU watt limiti — Gigabyte'ın kendi ACPI kanalı;
  ryzenadj'a tercih edilebilir, pmf dayanıklılığı incelenmeli.
- [ ] 21W kıskacının kendisi (`amd_pmf` debugfs incelemesi).
- [ ] Windows'ta (UXTU/GCC) CO bu laptopta çalışıyor mu? Tahmin: hayır.
  Çalışırsa CO araştırması yeniden açılır.

## Pratik sonuç: CO kilitli → oyunda "balanced" kolu (18 Tem 2026)

CPU'yu doğrudan soğutamadığımız için oyunda CPU'nun **güç iştahını** kısıyoruz:
`game-perf` PPD'yi `performance` yerine **`balanced`** yapıyor (amd-pmf'in balanced
STAPM preset'i daha düşük → CPU paylaşımlı Dynamic Boost bütçesini daha az yer →
dGPU beslenir). Bu, CPU-güç limiti kolunun PPD/amd-pmf üzerinden kanıtlanmış hâli;
kesin watt-cap (ECPT) hâlâ açık. CPU-bound oyun için `GR_CPUMAX=1` performance'a
döner. Ayrıntı: `Documentation/gaming.md` "GPU-öncelik" + `system/kernel/sched.nix`.

---

## Kampanya logu (2026-07-12)

**Sonuç:** Faz 0 gate FAIL (platform kilidi) — kampanya kapandı. Uygulanan ofset:
**0 (stok)**. Yeniden açma koşulu: Windows çapraz testi pozitif çıkarsa VEYA BIOS
güncellemesi OC/CBS seçeneği getirirse.

Ön bulgular:
- RyzenAdj family 0x1A: **v0.17.0 "Add support for krackan"** (PR #343, Framework)
  → nixpkgs 0.19.0 içeriyor.
- Kernel: `CONFIG_STRICT_DEVMEM=y` + `IO_STRICT_DEVMEM=y`, cmdline'da
  `iomem=relaxed` YOK → `ryzenadj -i` PM tablo okuması engelli (yalnız izleme için;
  ayarlamaları etkilemiyor). CO kilitli çıkınca `iomem=relaxed` eklenmedi.
- cogfx: topluluk raporuna göre family 0x1A'da desteklenmiyor.

### Olay günlüğü
- 16:18 — ryzenadj 0.19.0 flake nixpkgs'ten derlendi (`jg6irv4b…`).
- 16:20 — `-i` → **"CPU Family: Krackan Point", SMU BIOS Interface Version: 21**,
  PM tablo `Unable to get memory access` (strict devmem, beklenen).
  `--set-coall=0` → **"rejected by SMU"** (exit 255) — temiz hata, donma yok.
- 16:25 — Teşhis (kaynak + issue #398): coall Krackan'da MP1 0x4C gönderiyor
  (Strix Halo'da sahada çalışan komutla aynı; #398'de −30 başarılı, −50 crash).
  Kod: `UnknownCmd → "unsupported"`, bizde `"rejected"` → **komut SMU'da VAR, red =
  değer/durum validasyonu.** AC + platform_profile=performance teyitli.
  `set_cogfx`: family 0x1A kaynakta hiç yok → iGPU CO araç tarafında kapalı
  (ADJ_ERR_FAM_UNSUPPORTED).
- 17:03 — `--set-coall=0xFFFFB` (−5) de **"rejected by SMU"** (donma yok, MCE yok).
  0-değeri hipotezi düştü.
- 17:10 — G-Helper + UXTU kaynak karşılaştırması: G-Helper Krackan'ı StrixPoint
  ailesine koyup **aynı MP1 0x4C + aynı encoding** (`0x100000−N`) gönderiyor;
  adresler ryzenadj'la birebir (MSG 0x3b10928 / RSP 0x3b10978 / ARG 0x3b10998 =
  UXTU FP8). **UXTU FP8 komut listesi:** `enable-oc`=PSMU 0x17, `set-coall`=MP1
  0x4C **ve PSMU 0x5D**, `set-coper`=MP1 0x4B / PSMU 0x53. ryzenadj `set_enable_oc`
  family 0x1A'yı kapsamıyor (Rembrandt'ta bitiyor).
- 17:14 — strace ile ham REP: MP1 0x4C coall → **REP=0xFF (REP_MSG_Failed)** —
  komut biliniyor (0xFE değil), önkoşul/busy değil (0xFD/0xFC değil), bilinçli red.
  arg0'da 0xFFFFB yankısı var.
- 17:20 — setpci SMN prosedürü (B8/BC index-data) zararsız SMU_TEST_MSG ile
  doğrulandı: **PSMU TEST REP=0x1 OK.**
- 17:25 — PSMU 0x5D coall −5 → **REP=0xFF (Failed)**. UXTU akışında `--enable-oc`
  yalnız manuel OC toggle'ında gönderiliyor, CO-only akışta değil.
- 17:31 — PSMU 0x17 enable-oc → **REP=0xFD (CmdRejectedPrereq)** — komut var,
  platform OC-izin bayrağı kapalı (desktop Zen'de "OC BIOS/PSP kilidi" imzası).
  OC modu açılmadı → disable-oc (0x18) gereksiz.
- 17:40 — Kapanış süpürmesi: get-pbo-scalar (PSMU 0x0F) → **REP=OK, arg0=0x3f800000
  (float 1.0, stok)**; get-coper-options (PSMU 0xE1) → **REP=OK, arg0=0 — "CO
  seçeneği yok"**; coper core0 −5 (MP1 0x4B, encoding `(core<<20)|(val&0xFFFF)` =
  0xFFFB) → rejected; **WMBD 0xED profil 2 (GCC Windows-init) altında enable-oc
  yine 0xFD, coall yine rejected**. platform_profile + aero-power-profile restore
  temiz. MCE yok, donma yok.

### FAZ 0 KARARI (2026-07-12): CPU/iGPU Curve Optimizer bu makinede PLATFORM KİLİTLİ

Kanıt zinciri (hepsi aynı oturumda, AC + platform_profile=performance):

| Deney | Kanal | Sonuç |
|---|---|---|
| SMU_TEST_MSG | PSMU 0x1 | ✅ REP=OK — mailbox prosedürü doğru |
| get-pbo-scalar | PSMU 0x0F | ✅ REP=OK, 1.0 — getter'lar çalışıyor |
| get-coper-options | PSMU 0xE1 | ✅ REP=OK, **arg0=0 → CO seçeneği YOK** |
| set-coall 0 / −5 | MP1 0x4C | ❌ REP=0xFF Failed (strace ile ham kod) |
| set-coall −5 | PSMU 0x5D | ❌ REP=0xFF Failed |
| set-coper core0 −5 | MP1 0x4B | ❌ rejected |
| **enable-oc** | PSMU 0x17 | ❌ **REP=0xFD CmdRejectedPrereq — platform OC-izin bayrağı kapalı** |
| Yukarıdakiler 0xED profil 2 altında | WMI+SMU | ❌ değişmedi |

Aynı komutlar Strix Halo'da (#398) ve Framework HX 370'te sahada çalışıyor → red bu
makinenin **Gigabyte BIOS/PSP (APCB) OC kilidinden**. AMD spec sayfasının Ryzen AI
7 350 için "Curve Optimizer: No" beyanı kilitli OEM platformları için fiilen doğru.
Bilinen hiçbir runtime kanal (iki SMU mailbox'ı, WMI 0xED, platform_profile) kilidi
açmıyor.

**Açık kapılar (yapılmadı, kullanıcı kararı):**
1. **Windows çapraz testi** — UXTU/GCC ile CO denemesi. Çalışırsa Windows'ta
   bilinmeyen bir unlock handshake var demektir (en değerli tek veri noktası).
2. **BIOS güncellemeleri** — Gigabyte CBS/OC seçeneği açarsa yeniden dene.
3. smokeless_umaf ile gizli AMD CBS menüsü — UEFI variable seviyesi, brick riski;
   kapsam dışı, önerilmiyor.
