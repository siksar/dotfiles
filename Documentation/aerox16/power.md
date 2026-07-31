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
