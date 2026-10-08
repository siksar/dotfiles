# nixos-zixar

Flake tabanlı NixOS: **Gigabyte AERO X16 (EG61H)**, kullanıcı `zixar`, host `nixos`.
Masaüstü: GNOME (varsayılan) + COSMIC + Hyprland (UWSM).

```bash
nh os switch                                               # günlük
nixos-rebuild build --flake /home/zixar/nixos-zixar#nixos  # aktivasyonsuz kontrol
hms                                                        # yalnız HM (nh home switch -b hm-backup)
bash scripts/verify-context.sh                             # iki eval + statix + deadnix
```

`/etc/nixos` bu repoya symlink. Pil watt'ı: `current_now × voltage_now / 1e12`
(firmware `power_now` bildirmez).

## Ağaç

```
flake.nix  configuration.nix  home.nix   girdiler/çıktılar, iki katmanın import listeleri
system/    NixOS modülleri (arch/aerox16 = bu donanıma özgü EC/WMI/ACPI)
usr/       sistem geneli programlar
home/      Home Manager modülleri
lib/       iki katmanın ortak verisi/fonksiyonları (theme, gamerun)
scripts/   doğrulama ve ölçüm betikleri
Documentation/  ölçüm defterleri (tarihçe); upstream/ = gönderilecek raporlar
```

## Donanım

| Bileşen | Ayrıntı |
|---|---|
| CPU | AMD Ryzen AI 7 350 (Zen 5, 8C/16T; Zen5c = 1,3,5,7 + SMT) |
| iGPU | Radeon 860M (gfx1152), PCI `65:00.0`, `1002:1114` |
| dGPU | RTX 5060 Max-Q (Blackwell), PCI `64:00.0`, `10de:2d19`; HDMI bu karta bağlı |
| RAM | 32 GB DDR5 5600 |
| Depolama | Kingston OM8PGP4 NVMe 1 TB |
| WiFi | Realtek RTL8852CE (rtw89) |
| Ekran | eDP-1 2560×1600 @ 165 Hz, VRR |
| BIOS | AMI FB0A |
