# AERO X16 1VH — CPU/iGPU/dGPU Undervolt & Curve Optimizer araştırması

**Durum:** KAPANDI (2026-07-12) — CO kampanyası Faz 0 gate'te bitti: **CPU/iGPU
Curve Optimizer bu makinede platform (Gigabyte BIOS/PSP) kilidi altında.** Araç
zinciri tam ve doğrulandı; her CO yazma yolu SMU tarafından bilinçli reddediliyor,
`enable-oc` önkoşulu hiçbir kanalla açılamıyor. Kanıt zinciri ve yeniden açma
koşulları: en alttaki "Kampanya logu" → "FAZ 0 KARARI". Denenen yazmaların hepsi
volatil'di ve hiçbiri kabul edilmedi — sistem stok durumda.

**Kapsam uyarısı:** Bu iş, fan/WMI araştırmasından (`aerox16-1vh-wmi.md`)
**tamamen ayrı bir alt sistemdir**. Fan kontrolü EC/WMI (ACPI ERCD/WMBD)
üzerindendi; CPU/iGPU undervolt ise **AMD SMU mailbox**'ı üzerinden gider.
İkisini karıştırma — ortak nokta yok.

---

## Üç ayrı katman, üç ayrı gerçeklik

| Katman | Yöntem | Bu makinede durum |
|---|---|---|
| CPU Curve Optimizer (çekirdek voltaj ofseti) | SMU mailbox (ryzenadj/ryzen_smu) | Silikon destekli; **araç uyumu doğrulanmadı** |
| iGPU (Radeon 860M) CO / clock | Aynı SMU tablosu | CPU ile aynı — doğrulanmadı |
| dGPU (RTX 5060) VF eğrisi | NVAPI (Windows) / Coolbits (Linux, sınırlı) | Gerçek eğri **Linux'ta mimari kapalı** |

### 1. CPU Curve Optimizer — mimari olarak AÇIK, araç tarafı belirsiz

> **GÜNCELLEME (2026-07-12):** Araç belirsizliği ÇÖZÜLDÜ (ryzenadj 0.19.0 Krackan'ı
> tam tanıyor, komut/adres/encoding G-Helper+UXTU ile birebir) ama sonuç ters yönde:
> kilit **platformda** (BIOS/PSP OC bayrağı). Ayrıntı: "Kampanya logu → FAZ 0 KARARI".
> Aşağıdaki metin tarihsel kayıt olarak duruyor.

**Önemli düzeltme (kullanıcı geri bildirimi):** CPU CO mimari olarak kapalı
DEĞİL. Curve Optimizer gerçek bir Zen silikon özelliğidir (SMU'nun her çekirdek
için negatif voltaj ofseti uygulaması); kullanıcının arkadaşının aynı sınıf
laptopunda bir uygulama bunu yaptırabiliyor → donanım/firmware engeli yok.
Asıl soru **mimari değil, araç tamlığı**: Linux aracı bu spesifik çipin SMU PM
tablosunu doğru okuyup doğru mailbox komutunu gönderebiliyor mu?

- **CPU:** AMD Ryzen AI 7 350 "Krackan Point", Zen5, **family 26 (0x1A), model
  0x60**, w/ Radeon 860M.
- **Mekanizma:** SMU mailbox — EC/WMI'dan bağımsız. `amd_pstate=active` (EPP
  `performance`) şu an CPU frekans/EPP'yi yönetiyor; CO voltaj ofseti bunun
  ALTINDA, ayrı bir SMU register sınıfı.
- **Araç durumu (nixpkgs):**
  - `ryzenadj` **var (0.19.0)**. Kaynak API'sinde gerçek CO fonksiyonları
    mevcut: `set_coall` (tüm çekirdek ofset), `set_coper` (çekirdek başı),
    `set_cogfx` (iGPU ofset), ayrıca `set_oc_volt`, `set_per_core_oc_clk`.
  - **AMA:** RyzenAdj'ın resmî "Supported Models" listesi Rembrandt/Van Gogh
    (Zen3+/Zen2) düzeyinde bitiyor — **Krackan Point / Strix Point / tüm
    "Ryzen AI 300" serisi listede YOK.** 0.19.0'ın bu family 0x1A çipin PM
    tablo sürümünü tanıyıp tanımadığı doğrulanmadı (release changelog kontrolü
    session limitine takıldı, tamamlanacak).
  - `ryzen_smu` (çekirdek modülü, diğer yaygın CO yolu) ve `zenstates-linux`
    **nixpkgs'te YOK** → out-of-tree flake/derleme gerekir (ek doğrulanmamışlık).
- **Risk profili:** ACPI'nin aksine SMU mailbox, desteklenmeyen komuta her zaman
  temiz hata dönmez; yanlış tablo sürümüyle CO yazmak en kötü halde kararsızlık/
  donma verebilir. Kurtarma: **reboot** (CO ofseti kalıcı değil, SMU sıfırlanır).

### 2. iGPU (Radeon 860M)

`ryzenadj set_cogfx` iGPU voltaj ofseti sunar — ama **CPU ile birebir aynı
belirsizlik** (aynı SMU, aynı çip, aynı doğrulanmamış tablo). CPU CO doğrulanırsa
iGPU de aynı anda çözülür.

### 3. dGPU (RTX 5060) — burada gerçek mimari sınır var

Bu, "henüz bulamadık" değil, **Linux mimarisinde kapalı kapı**:

- **Gerçek nokta-nokta VF eğrisi** (MSI Afterburner tarzı,
  `NvAPI_GPU_ClientVFAdjustSet`): yalnız **Windows NVAPI**'de. NVIDIA'nın Linux
  sürücüsü (kapalı `nvidia` de, `nvidia-open` da) bunu hiçbir nesilde userspace'e
  açmadı. Araştırmayla aşılamaz.
- **Linux'ta gerçekten var olanlar:**
  - **Güç limiti:** `nvidia-smi -pl <watt>` — bu GPU'da **5-85W aralığı
    doğrulandı, çalışıyor** (ayrıca ACBT/Dynamic Boost ile tavan 50→75W+ zaten
    entegre; bkz. `aerox16-1vh-wmi.md`).
  - **Blok saat ofseti:** `nvidia-settings` `GPUGraphicsClockOffset` /
    `GPUMemoryTransferRateOffset` — tam eğri değil, tüm boost tablosuna SABİT
    kaydırma. **`Coolbits` şu an ayarlı DEĞİL** (`/etc/nixos`'ta yok) → denemek
    için önce `hardware.nvidia` X-config'ine `Coolbits` eklemek gerekir. Not:
    negatif offset + güç limiti pratikte "poor man's undervolt" verir
    (aynı watt'ta daha yüksek saat / aynı saatte daha düşük watt).

---

## ⚠️ amd-pmf müdahale riski — kullanıcının özel uyardığı nokta

**Bu makinede `amd_pmf` YÜKLÜ ve AKTİF** (doğrulandı, 2026-07-12):

- `amd_pmf` modülü yüklü, `AMDI0107:00` platform cihazına **bağlı**
  (`tee` + `amd_sfh` + `button` bağımlı). AMD Platform Management Framework.
- **`platform_profile`'ı O sağlıyor** (`performance / balanced / low-power`).
- **TLP bunu aktif sürüyor:** `modules/hardware/tlp.nix` →
  `PLATFORM_PROFILE_ON_AC = performance`, `..._ON_BAT = low-power`.

**Somut risk:** amd-pmf'in "Static Slider" katmanı, seçili platform_profile'a
göre STAPM/fast/slow (SPPT/FPPT) güç limitlerini **kendi preset değerlerine
uygular**. Dolayısıyla ryzenadj ile elle yazılan STAPM/PPT limitleri şu
olaylarda **sessizce eski haline döndürülür**:
- Her AC↔BAT geçişi (TLP profil değiştirir → pmf preset'i basar),
- amd-pmf'in kendi politika motoru (Smart PC / CnQF, TEE üzerinden) termal/güç
  olayında yeniden uygularsa (AMDI0107 nesli bu politikayı destekliyor olabilir;
  aktif olup olmadığı dmesg ile doğrulanacak — root gerekti, bekliyor).

**Curve Optimizer ofseti için durum daha iyi (ama doğrulanmalı):** CO negatif
voltaj ofseti, Static Slider'ın yönettiği güç-limiti register'larından FARKLI
bir SMU register sınıfıdır; platform_profile değişimi normalde CO ofsetine
dokunmaz → CO, STAPM'den daha kalıcı olabilir. Ancak amd-pmf'in TEE tabanlı
Smart PC politikası teorik olarak SMU'ya dokunabilir → **joker bu.** Kesin
cevap ölçümle: CO yaz → AC/BAT geçişi yaptır → CO hâlâ duruyor mu kontrol et.

**Kurtarma her durumda:** reboot → hem CO hem güç limiti sıfırlanır; TLP+pmf
boot preset'lerini yeniden uygular.

---

## Risk / kanıt matrisi

| İşlem | Araç | Kanıt/Uyum | Risk | pmf reverti |
|---|---|---|---|---|
| dGPU güç limiti | `nvidia-smi -pl` | ✅ doğrulandı (5-85W) | Düşük | Hayır (nvidia ayrı) |
| CPU/iGPU watt limiti (STAPM/PPT) | ryzenadj / EC 0xF1-F3 | Kısmi (EC yolu ECPT ile kanıtlı) | Düşük | **EVET (yüksek)** |
| dGPU saat ofseti | Coolbits + nvidia-settings | Mümkün, config gerekli | Orta | Hayır |
| CPU/iGPU Curve Optimizer | ryzenadj `set_coall/coper/cogfx` | ❌ **PLATFORM KİLİTLİ (2026-07-12)** — SMU tüm CO yazmalarını reddediyor | — (yazılamıyor) | — |
| dGPU gerçek VF eğrisi | — | Linux'ta mimari kapalı | — | — |

## Önerilen güvenli sıra (uygulama planlanırsa)

1. **Salt-okuma önce:** `ryzenadj -i` (info) çalıştır → çip PM tablosunu okuyabiliyor
   mu, get değerleri makul mü? Okuyamıyorsa CO/limit yazması riskli, dur.
2. **En düşük risk, en yüksek kanıt:** dGPU güç limiti (zaten çalışıyor) +
   Coolbits saat ofseti (config ekle, X gerektirir — Hyprland/Wayland'da
   nvidia-settings yolu ayrıca doğrulanmalı).
3. **CPU watt limiti** için EC yolu (`0xF1-F3`/ECPT, `aerox16-1vh-wmi.md`) ryzenadj'a
   tercih edilebilir — Gigabyte'ın kendi ACPI kanalı, pmf ile çakışma dinamiği
   ayrıca incelenmeli.
4. **Curve Optimizer** en son: tek düşük ofsetle başla (ör. `-10` all-core), her
   adım gözlem + stabilite testi (stress-ng + mangohud) + AC/BAT geçişiyle pmf
   revert testi. Her yazma onaylı, kurtarma = reboot.
5. **pmf devre dışı bırakma seçeneği** (gerekirse): `platform_profile` kontrolünü
   pmf yerine tamamen TLP'ye/manuel bırakmak, ya da CO'yu her profil değişiminde
   yeniden uygulayan bir servis (fan/power-profile deseniyle udev ACAD tetikli).

## Açık sorular (2026-07-12 kampanyasıyla güncellendi)

- [x] `ryzenadj -i` PM tablosu: çip tanınıyor (SMU BIOS iface v21) ama tablo okuması
  strict devmem'e takılıyor (`iomem=relaxed` gerekirdi; CO kilitli çıkınca eklenmedi).
  ryzenadj notu: tablo yalnız izleme için, ayarlamaları etkilemiyor.
- [x] RyzenAdj family 0x1A: **v0.17.0 "Add support for krackan" (PR #343)**; 0.19.0 içeriyor.
- [x] amd-pmf modu: **"No Smart PC policy present"** (dmesg) — yalnız Static Slider.
- [x] ~~CO ofseti AC/BAT geçişinde hayatta kalıyor mu?~~ Geçersiz: CO yazılamıyor
  (platform kilidi) → test edilecek ofset yok.
- [ ] Coolbits + nvidia-settings Wayland/Hyprland altında çalışıyor mu? (CO-dışı kol, ayrı iş)
- [ ] EC `0xF1-F3` (ECPT) CPU watt limiti vs pmf dayanıklılığı (CO-dışı kol, ayrı iş)
- [ ] YENİ: Windows'ta (UXTU/GCC) CO bu laptopta çalışıyor mu? Tahmin: hayır
  (platform kilidi OS'ten bağımsız). Çalışırsa araştırma yeniden açılır.

## İlgili
- Idle güç bütçesi (4.28W) ve gaming kısıtları: değişiklikler bu tabanı bozmamalı
  (bkz. `CLAUDE.md` güç yönetimi bölümü, `power-optimization-project` memory).
- Fan/WMI/EC araştırması (ayrı alt sistem): `docs/aerox16-1vh-wmi.md`.

---

## Kampanya logu (2026-07-12)

Plan: `~/.claude/plans/curve-optimizer-ile-alakali-expressive-wall.md` (onaylı).
Loop her iterasyonda ÖNCE bu bloğu okur; her CO yazmasından ÖNCE niyet satırı
buraya işlenir (donma forensiği). Kurtarma: reboot → CO sıfırlanır.

**Durum bloğu:**
- Faz: **0 TAMAMLANDI → GATE FAIL (platform kilidi) — KAMPANYA KAPANDI (2026-07-12)**
- Uygulanan ofset ŞU AN: **0 (stok)** — hiçbir CO yazması kabul edilmedi, sistem stok
- Sıradaki adım: yok. Yeniden açma koşulu: Windows çapraz testi pozitif çıkarsa
  VEYA BIOS güncellemesi OC/CBS seçeneği getirirse (aşağıda "FAZ 0 KARARI")

**Planlama aşamasında kapanan açık sorular (2026-07-12):**
- [x] RyzenAdj family 0x1A: **v0.17.0 "Add support for krackan"** (PR #343, Framework) → nixpkgs 0.19.0 içeriyor
- [x] amd-pmf modu: dmesg **"No Smart PC policy present"** → yalnız Static Slider, TEE politika jokeri yok
- [x] cogfx: topluluk raporu family 0x1A'da **desteklenmiyor** (tek deneme Faz 5'te yine yapılacak)
- Kernel: `CONFIG_STRICT_DEVMEM=y` + `IO_STRICT_DEVMEM=y`, cmdline'da `iomem=relaxed` YOK → `-i` engeli bekleniyor

### Olay günlüğü
- 2026-07-12 16:18 — Faz 0 başladı. ryzenadj 0.19.0 flake nixpkgs'ten derlendi
  (`jg6irv4b…`). Sıradaki: `sudo ryzenadj -i` (salt-okuma) + `--set-coall=0`
  no-op mailbox probe'u (yol ayrımı için: PCI mailbox devmem'siz çalışıyor mu).
- 2026-07-12 16:20 — Gate sonuçları: `-i` → **"CPU Family: Krackan Point", SMU BIOS
  Interface Version: 21**, ama PM tablo `Unable to get memory access` (strict devmem,
  beklendiği gibi; ryzenadj notu: "does not affect adjustments"). `--set-coall=0` →
  **"rejected by SMU"** (exit 255) — temiz hata, donma yok.
- 2026-07-12 16:25 — Teşhis (kaynak + issue #398): coall Krackan'da MP1 0x4C
  gönderiyor (Strix Halo'da sahada çalışan komutla aynı; #398'de −30 başarılı,
  −50 crash). Kod: `UnknownCmd → "unsupported"`, bizde `"rejected"` → **komut SMU'da
  VAR, red = değer/durum validasyonu.** AC + platform_profile=performance teyitli
  (enerji tasarrufu modu reddi bize uymuyor). `set_cogfx`: family 0x1A kaynakta hiç
  yok → iGPU CO araç tarafında kapalı (ADJ_ERR_FAM_UNSUPPORTED), Faz 5 beklentisi kesinleşti.
- 2026-07-12 16:26 — **NİYET: `--set-coall=0xFFFFB` (−5) uygulanıyor** — 0-reddi ile
  komut-reddi ayrımı + Faz 2'nin ilk adımı. Donma olursa suçlu bu satırdır; kurtarma
  reboot (CO sıfırlanır).
- 2026-07-12 17:03 — −5 de **"rejected by SMU"** (donma yok, MCE yok). 0-değeri
  hipotezi düştü.
- 2026-07-12 17:10 — Kaynak karşılaştırması (G-Helper + UXTU klonlandı):
  G-Helper Krackan'ı StrixPoint ailesine koyup **aynı MP1 0x4C + aynı encoding**
  (`0x100000−N`) gönderiyor; adresler de ryzenadj'la birebir (MSG 0x3b10928 /
  RSP 0x3b10978 / ARG 0x3b10998 = UXTU FP8). Araç tarafında hata YOK.
  **UXTU FP8 komut listesi:** `enable-oc`=PSMU 0x17, `set-coall`=MP1 0x4C **ve
  PSMU 0x5D** (çift yol; G-Helper StrixHalo'da 0x5D'yi fallback yapıyor),
  `set-coper`=MP1 0x4B / PSMU 0x53. ryzenadj `set_enable_oc` family 0x1A'yı
  kapsamıyor (Rembrandt'ta bitiyor) → araç tamlığı açığı TAM BURADA.
- 2026-07-12 17:14 — strace ile ham REP yakalandı: MP1 0x4C coall →
  **REP=0xFF (REP_MSG_Failed)** — komut biliniyor (0xFE değil), önkoşul/busy değil
  (0xFD/0xFC değil), bilinçli red. arg0'da 0xFFFFB yankısı var.
- 2026-07-12 17:20 — setpci SMN prosedürü (B8/BC index-data, strace'le teyitli)
  zararsız SMU_TEST_MSG ile doğrulandı: **PSMU TEST REP=0x1 OK.**
- 2026-07-12 17:21 — **NİYET: PSMU 0x5D set-coall=0xFFFFB (−5) deneniyor** (UXTU
  FP8 kaynak kanıtlı ikinci yol, setpci ile). Donma olursa suçlu bu satır; kurtarma
  reboot.
- 2026-07-12 17:25 — PSMU 0x5D coall → **REP=0xFF (Failed)**. Her iki CO yolu da
  aynı bilinçli redde düşüyor. UXTU akış analizi: `--enable-oc` yalnız manuel OC
  toggle'ında gönderiliyor, CO-only akışta değil → enable-oc "standart önkoşul"
  değil ama OEM fark noktası hipotezi duruyor (Asus/Framework BIOS'u OC-izin
  bayrağını açık bırakıyor olabilir, Gigabyte kapalı).
- 2026-07-12 17:28 — **NİYET: PSMU 0x17 enable-oc gönderiliyor** (UXTU FP8 komutu;
  volatil, 0x18 disable-oc ile geri alınabilir). Başarılıysa coall tekrar denenecek;
  coall yine reddederse 0x18 ile OC modu kapatılacak. Donma → reboot.
- 2026-07-12 17:31 — **enable-oc → REP=0xFD (CmdRejectedPrereq)!** Komut firmware'de
  var, kendi önkoşulu (platform OC-izin bayrağı) kapalı — desktop Zen'de bu yanıt
  "OC BIOS/PSP kilidi" imzasıdır. coall MP1 tekrarı yine "rejected". OC modu
  AÇILAMADI (0xFD = durum değişmedi) → disable-oc gereksiz.
- 2026-07-12 17:35 — **NİYET: kapanış kanıt süpürmesi** — (1) PSMU 0x0F
  get-pbo-scalar, (2) PSMU 0xE1 get-coper-options (ikisi getter), (3) MP1 0x4B
  coper core0 −5 probe (UXTU encoding `(core<<20)|(val&0xFFFF)` = 0xFFFB),
  (4) WMBD 0xED profil 2 (GCC Windows-init, kanıtlanmış-güvenli) altında enable-oc +
  coall tekrarı, ardından 0xED 0 + gigabyte-power-profile restore. Donma → reboot.
- 2026-07-12 17:40 — Süpürme sonuçları: get-pbo-scalar → **REP=OK, arg0=0x3f800000
  (float 1.0, stok)**; get-coper-options → **REP=OK, arg0=0x00000000 — "CO seçeneği
  yok", kilidin firmware beyanı**; coper core0 −5 → rejected; **0xED profil 2
  altında: enable-oc yine 0xFD, coall yine rejected** (GCC init'i OC bayrağına
  dokunmuyor). 0xED 0 + gigabyte-power-profile restore temiz. MCE yok, donma yok.

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

Araç tarafı TAM: ryzenadj 0.19.0 Krackan'ı tanıyor; adresler/komutlar/encoding
G-Helper ve UXTU ile birebir doğrulandı (kaynak klonlanıp karşılaştırıldı).
Aynı komutlar Strix Halo'da (#398) ve Framework HX 370'te sahada çalışıyor →
red bu makinenin **Gigabyte BIOS/PSP (APCB) OC kilidinden**. AMD spec sayfasının
Ryzen AI 7 350 için "Curve Optimizer: No" beyanı, kilitli OEM platformları için
fiilen doğru çıktı; arkadaş laptopu kanıtı silikon için geçerli, OEM firmware'i
için değil.

**Ne yapılamaz:** Bildiğimiz hiçbir runtime kanal (iki SMU mailbox'ı, WMI 0xED,
platform_profile) kilidi açmıyor. ryzen_smu modülü de aynı mailbox'a konuşur —
kilidi AŞMAZ (yalnız telemetri kolaylığı sağlardı).

**Açık kapılar (yapılMAdı, kullanıcı kararı):**
1. **Windows çapraz testi** — UXTU/GCC ile bu laptopta CO denemesi. Tahmin:
   orada da sessizce başarısız. ÇALIŞIRSA → Windows'ta bilmediğimiz bir unlock
   handshake var demektir, araştırma yeniden açılır (en değerli tek veri noktası).
2. **BIOS güncellemeleri** — Gigabyte ileride CBS/OC seçeneği açarsa yeniden dene.
3. smokeless_umaf ile gizli AMD CBS menüsü açma — UEFI variable seviyesi,
   brick riski sınıfı; kapsam dışı bırakıldı, önerilmiyor.

Kampanyanın asıl hedefleri (21W kıskacında perf/watt, pil verimi) için CO-dışı
kollar hâlâ açık: dGPU güç limiti (kanıtlı), Coolbits saat ofseti, EC 0xF1-F3
CPU watt limitleri, 21W kıskacının kendisi (`amd_pmf` debugfs incelemesi).
Bunlar ayrı iş kalemleridir — bu kampanya CO'ya özeldi ve burada kapanmıştır.

### Ölçüm tablosu (protokol: plan Faz 1; MT=matrixprod 16t 120s, 1T=60s pinli)
| Ofset | MT bogo-ops/s | MT avg MHz | MT pkg W | MT tepe °C | 1T Fmax MHz | 1T pkg W | MCE | Sonuç |
|---|---|---|---|---|---|---|---|---|
