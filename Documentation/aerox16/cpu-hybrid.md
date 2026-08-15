# CPU — hibrit Zen5/Zen5c çekirdek politikası

**Bulgu (10 Ağu 2026): çekirdek zamanlayıcı bu CPU'nun hibrit olduğunu bilmiyor.**
Firmware Zen5/Zen5c ayrımını gösteriyor, ama zamanlayıcıya hiçbir kanaldan ulaşmıyor —
sonuç, tek-thread'lik kısa işlerin yazı-tura ihtimalle hızlı çekirdeğe düşüp 5GHz'e
zıplaması. `system/kernel/cores.nix` bunu elle düzeltir (systemd manager `CPUAffinity`
ile masaüstünü Zen5c'ye kilitler). Bu dosya o kararın kanıtını tutar.

---

## Donanım: AMD Ryzen AI 7 350 "Krackan Point"

`lscpu` + `model name`: family 26 (0x1A), 8 çekirdek / 16 thread, hibrit Zen5 + Zen5c.

| Sınıf | CPU listesi (mantıksal) | `cpuinfo_max_freq` |
|---|---|---|
| Zen5 ("büyük") | `0,2,4,6` + SMT `8,10,12,14` | **5090910 kHz** (~5.09 GHz) |
| Zen5c ("verimlilik") | `1,3,5,7` + SMT `9,11,13,15` | **3506494 kHz** (~3.51 GHz) |

`amd_pstate_prefcore_ranking` (firmware'in kendi sıralaması, yüksek=hızlı):
Zen5 çekirdekleri 196/202/208, Zen5c çekirdekleri hepsi 135. `4,6,12,14` (Zen5'in
en yüksek rütbeli 4'ü) `gamerun`'ın `GR_PIN=fast` listesiyle birebir örtüşüyor.

## Kanıt: zamanlayıcı hibrit-farkındalığı YOK

| Kontrol | Değer | Anlamı |
|---|---|---|
| `amd_pstate/prefcore` | `disabled` | global anahtar kapalı |
| `cpuN/cpufreq/amd_pstate_hw_prefcore` | her CPU'da `disabled` | çekirdek başına da kapalı |
| `/proc/sys/kernel/sched_itmt_enabled` | **dosya yok** | ITMT (Intel Turbo Boost Max 3.0 tarzı sıralama) bu sistemde hiç oluşmamış |
| `cpuN/cpu_capacity` | 16 CPU'da da `1024` | EEVDF hepsini eşit kapasiteli sanıyor |
| `/sys/bus/platform/devices/amd_hfi/driver` | **symlink yok** | AMD HFI (Hardware Feedback Interface) sürücüsü cihaza bağlanmamış |
| `ACPI` tabloları | `SSDT ... AMD Hetero` mevcut | firmware hibrit topolojiyi BEYAN EDİYOR |
| `amd_pstate_prefcore_ranking` | Zen5 196-208 / Zen5c 135 | firmware sıralamayı da VERİYOR |

Yani firmware tarafı tam: ACPI hibrit tabloyu taşıyor, `amd_hfi` platform cihazı
mevcut, prefcore ranking'i her çekirdek doğru bildiriyor. Ama üç bağlayıcı halka
(`amd_hfi` sürücü bağlanması, `prefcore` etkinleşmesi, `sched_itmt_enabled`) hiçbiri
tamamlanmamış — kernel 7.1.7 + `amd_pstate=active` bu makinede zamanlayıcıyı hibrit
farkında yapmıyor.

## Sonuç zinciri (neden "bazen 5GHz'e zıplıyor" hissi doğru)

1. EEVDF 16 CPU'yu ayrım gözetmeden dolduruyor — bir tarayıcı sekmesi, bir Electron
   zamanlayıcısı, compositor repaint'i eşit ihtimalle Zen5 veya Zen5c'ye gidiyor.
2. `system/kernel/power-display.nix` AC'de her `ACAD` olayında tüm CPU'ların
   `scaling_max_freq`'ini `cpuinfo_max_freq`'e (Zen5'te 5090910) geri açıyor + boost'u
   açıyor (power-saver'ın 2GHz kilidini geri almak için — bkz. o dosyadaki yorum).
3. EPP `balance_performance` (PPD `balanced`) — talep gelince klok hızla yükseliyor.
4. Sonuç: iş Zen5'e düştüğünde, kısa bir tek-thread patlaması bile o çekirdeği
   5GHz tavanına götürüyor. **Zorlayan bir "işlem" yok — zamanlayıcı kör, donanım
   izin veriyor.** Tasarım gereği böyle, arıza değil.

## Politika: `system/kernel/cores.nix` (10 Ağu 2026)

Kernel kendi karar veremediği için manager'ı elle Zen5c'ye sabitledik:

```
systemd.settings.Manager.CPUAffinity = "1,3,5,7,9,11,13,15";   # yalnız Zen5c
systemd.services.nix-daemon.serviceConfig.CPUAffinity = "0-15"; # derleme muaf
```

- **Mekanizma:** systemd PID1'in `CPUAffinity`'si `sched_setaffinity` ile ayarlanır ve
  fork/exec zinciriyle tüm alt süreçlere miras kalır — masaüstü, tarayıcı, compositor
  dahil her şey fiziksel olarak Zen5c'de kalır. Zen5'ler talep gelmeyince C-state'e
  düşer, 5GHz o çekirdeklerde yapısal olarak imkânsız hale gelir.
- **YUMUŞAK maske:** bu `sched_setaffinity`, cgroup `AllowedCPUs` DEĞİL — `taskset`
  ile her zaman geri açılabilir. `AllowedCPUs` bilinçli seçilmedi: cgroup düzeyinde
  kısıtlama çocuk süreçlerin `taskset` ile bile kaçmasını engeller, `gamerun`'ın oyunu
  16 CPU'ya açması imkânsız olurdu.
- **Delme yolları:**
  - Oyun: `gamerun` varsayılan olarak `taskset -c 0-15` ile başlatır (`lib/gamerun.nix`);
    `GR_PIN=big`/`fast`/özel liste ile Zen5'e daha dar pinleme de yapılabilir.
  - Kaçış alias'ı: fish `aia` (`home/shell/fish.nix`) → `taskset -c 0-15` öneki.
  - Derleme: `nix-daemon.service` muaf (`cores.nix`'in kendisinde).
- **Kapatma:** `CPUAffinity` satırını yorum satırı yap + rebuild.

## İzlenecek riskler (switch sonrası)

- **PipeWire xrun / ses çıtırtısı** — pipewire `user@.service` altında, o da maskeli;
  RT thread'ler 8 mantıksal Zen5c'de yarışıyor. Şüpheli buysa çözüm
  `pipewire.service`'e `CPUAffinity=0-15` muafiyeti eklemek.
- **Compositor tepkiselliği** — Hyprland/Caelestia 165Hz'de Zen5c'de koşuyor
  (bilinçli — compositor'a muafiyet verilmedi). Takılma gözlenirse ilk gözden
  geçirilecek nokta burası.
- **Boot/login süresi** — systemd de maskeli; birkaç yüz ms yavaşlama olası, ölçülmedi.

## Yeniden değerlendirme koşulu

Bu dosyadaki tüm kanıt 10 Ağu 2026 tarihli tek bir kernel sürümüne (7.1.7) aittir.
Eğer ileride bir kernel güncellemesi `amd_hfi`'yi bu cihazda gerçekten bağlarsa
(`/sys/bus/platform/devices/amd_hfi/driver` symlink'i oluşursa) ve/veya
`amd_pstate/prefcore` kendiliğinden `enabled` olursa, zamanlayıcı kendi kararını
verebilir hale gelir — `cores.nix`'in elle maskesi o noktada gereksiz, hatta
zamanlayıcının kendi optimizasyonuyla çakışan bir kısıt haline gelebilir. Yükseltme
sonrası yukarıdaki "Kanıt" tablosunu tekrar çalıştır, sonuç değiştiyse bu dosyayı
ve `cores.nix`'i güncelle.

## İlgili

- Idle güç bütçesi (4.28W) ve gaming kısıtları: `CLAUDE.md` güç yönetimi bölümü,
  `Documentation/aerox16/power.md`.
- Oyun sırasında maskeyi delme + fan turbo zinciri: `Documentation/gaming.md`.
- CPU undervolt/Curve Optimizer (ayrı, ilgisiz alt sistem — platform kilidi):
  `Documentation/aerox16/undervolt.md`.
