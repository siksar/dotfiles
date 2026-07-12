# AERO X16 1VH — CPU/iGPU/dGPU Undervolt & Curve Optimizer araştırması

**Durum:** Araştırma / planlama aşaması (2026-07-12). Henüz HİÇBİR undervolt/CO
yazması yapılmadı — bu belge yalnız salt-okuma keşif + araç/mimari envanteri.

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
| CPU/iGPU Curve Optimizer | ryzenadj `set_coall/coper/cogfx` | **Bu çipte doğrulanmadı** | Orta-yüksek | CO ofseti muhtemel hayır (doğrulanmalı) |
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

## Açık sorular (doğrulanacak)

- [ ] `ryzenadj -i` bu çipin PM tablosunu okuyabiliyor mu? (ilk salt-okuma testi)
- [ ] RyzenAdj 0.19.0 changelog: Krackan/Strix/family 0x1A desteği eklenmiş mi?
- [ ] amd-pmf hangi modda: yalnız Static Slider mı, Smart PC/CnQF politikası aktif mi? (`dmesg | grep pmf`, root)
- [ ] CO ofseti AC/BAT geçişinde/pmf altında hayatta kalıyor mu? (ölçüm)
- [ ] Coolbits + nvidia-settings Wayland/Hyprland altında çalışıyor mu, yoksa X mı gerekiyor?
- [ ] EC `0xF1-F3` (ECPT) CPU watt limiti ile ryzenadj STAPM — hangisi pmf'e karşı daha dayanıklı?

## İlgili
- Idle güç bütçesi (4.28W) ve gaming kısıtları: değişiklikler bu tabanı bozmamalı
  (bkz. `CLAUDE.md` güç yönetimi bölümü, `power-optimization-project` memory).
- Fan/WMI/EC araştırması (ayrı alt sistem): `docs/aerox16-1vh-wmi.md`.
