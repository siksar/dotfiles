# nixos-zixar

Tek makine için flake tabanlı NixOS yapılandırması: **Gigabyte AERO X16 (EG61H)**.
Tek kullanıcı (`zixar`), tek host (`nixos`), tek oturum (Hyprland).
Yorumlar ve commit mesajları Türkçe.

| Nereye bakmalı | Dosya |
|---|---|
| "Şunu nerede değiştiririm?" | **`MAINTAINERS`** — konu → dosya haritası |
| Mimari, kural ve tuzaklar | `CLAUDE.md` |
| Ölçüm defterleri | `Documentation/` |

---

## Rebuild

```bash
# Günlük sürücü (nixos-rebuild'i sarar, GC defterini tutar)
nh os switch

# Elle tam yol
sudo nixos-rebuild switch --flake /home/zixar/nixos-zixar#nixos

# Aktivasyonsuz derleme — switch öncesi hızlı akıl sağlığı kontrolü
nixos-rebuild build --flake /home/zixar/nixos-zixar#nixos

# Yalnız HM ağacında geziniyorsan (kabuk, uygulama dotfile'ları).
# Gömülü HM ile AYNI home.nix'i okur → drift yok. Kabukta alias: hms
nh home switch -b hm-backup
```

Test paketi yok. Doğrulama = `build` geçiyor, sonra `switch` + elle kontrol.
Güç/termal/WMI davranışı **ölçümle** doğrulanır, build'in geçmesiyle değil
(`powertop`, `nvtop`, pil draw'ı — firmware `power_now` bildirmez, watt'ı
`current_now × voltage_now / 1e12` ile hesapla).

Repo `/home/zixar/nixos-zixar`'da yaşıyor (root'un `/etc/nixos`'u değil).
`/etc/nixos` oraya bir symlink — `--flake`'siz çıplak `nixos-rebuild switch`
bu symlink üzerinden çözülsün diye.

---

## Ağaç

Dizinler **amaca göre değil konuya göre** adlandırılmış (`gaming/`, `rice/`
değil; `kernel/`, `desktop/`). Sözlük Linux çekirdeğinden alınma.

```
.
├── flake.nix                  Makefile: girdiler + iki çıktı
├── configuration.nix          Kconfig: SİSTEM katmanının tek import listesi
├── home.nix                   Kconfig: KULLANICI katmanının tek import listesi
├── hardware-configuration.nix üretilmiş — elle düzenleme
├── MAINTAINERS                konu → dosya haritası
├── CLAUDE.md                  mimari + kurallar (ajan ve insan için)
│
├── system/                    ── NixOS modülleri: makinenin tesisatı ──
│   ├── arch/aerox16/          YALNIZ bu donanımda anlamlı (EC/WMI, DSDT).
│   │                          Makine değişirse ilk silinecek dizin burası.
│   ├── drivers/               gpu, input/keyboard-rgb
│   ├── kernel/                power, power-display, sched
│   ├── init/                  limine, locale, (plymouth — kullanılmıyor)
│   ├── net/                   core, vpn, localsend
│   ├── security/              users, keyring, onepassword
│   ├── desktop/               session, login (ly), theme (stylix)
│   ├── sound.nix
│   └── virt.nix
│
├── usr/                       ── sistem geneli kurulan programlar ──
│                              steam, netflix, firefox, local-ai
│
├── home/                      ── Home Manager modülleri ──
│   ├── desktop/               Hyprland oturumu: wm/ bar/ launcher/ notify/ theme/
│   ├── shell/                 fish, starship, ghostty, tmux
│   └── apps/                  kullanıcı uygulamaları
│
├── lib/                       ── İKİ katmanın da paylaştığı saf veri ──
│                              theme.nix, schemes/, wallpapers/
│
├── Documentation/             ── yaşayan lab defterleri ──
│   ├── aerox16/               wmi-ec, power, keyboard-rgb, undervolt, test-plan
│   ├── desktop.md  gaming.md  1password.md
│   ├── upstream/              üstakıma gönderilecek raporlar
│   └── archive/               DONMUŞ — yolları ve durumları kasıtlı eski
│
└── scripts/                   power-audit.sh
```

**Neden `lib/`:** duvar kağıtları ve base16 şemalarını hem sistem katmanı
(Stylix) hem kullanıcı katmanı (`home/desktop/session.nix`) okuyor. `system/`
altında bırakılsalardı `home/` oraya `../../system/…` ile uzanacaktı.
Çekirdekteki anlamıyla aynı: iki dalın da paylaştığı şey.

### Katmanı nasıl anlarsın

`system/` ve `usr/` NixOS modülü, `home/` Home Manager modülü. İki eval bağlamı
birbirine **import edilemez** — karıştırmak sert hata verir. Bir konu iki
katmana birden dokunuyorsa iki dosyası olur, örneğin:

| Konu | Sistem tarafı | Kullanıcı tarafı |
|---|---|---|
| Oyun | `system/kernel/sched.nix` | `home/apps/games.nix` |
| Masaüstü | `system/desktop/session.nix` | `home/desktop/session.nix` |

---

## Donanım

| Bileşen | Ayrıntı |
|---|---|
| **Laptop** | Gigabyte AERO X16 (EG61H) |
| **CPU** | AMD Ryzen AI 7 350 (Krackan Point, Zen 5, 8C/16T) |
| **iGPU** | AMD Radeon 860M (gfx1152, RDNA3.5, PCI `65:00.0`, bus ID 101) |
| **dGPU** | NVIDIA GeForce RTX 5060 Max-Q (Blackwell, PCI `64:00.0`, bus ID 100) |
| **RAM** | 32 GB DDR5 5600 MT/s (2× 16 GB Micron CT16G56C46S5.M8D1, çift kanal) |
| **Depolama** | Kingston OM8PGP4 NVMe PCIe SSD (953.9 GB) |
| **WiFi** | Realtek RTL8852CE 802.11ax |
| **Ekran** | eDP-1 2560×1600 @ 165 Hz, VRR destekli |
| **BIOS** | AMI FB0A (28.05.2026) |

**Sert kısıt: 4.28 W temiz idle.** `system/` veya `home/apps/games.nix` altına
eklenen hiçbir şey boşta koşmamalı/yoklamamalı. Tabanın nasıl ölçüldüğü:
`Documentation/aerox16/power.md`.

---

## Lint

`deadnix`, `statix`, `nixfmt` sistem geneli kurulu — doğrudan çağır
(`nix run nixpkgs#…` KULLANMA: o registry'nin nixpkgs'ini çözer, bu flake'in
pin'ini değil).

```bash
deadnix .        # beklenen: 1 bulgu (üretilmiş hardware-configuration.nix)
statix check .   # beklenen: 0 bulgu — herhangi bir çıktı regresyondur
```

`statix.toml` iki kuralı kapatır (`repeated_keys`, `empty_pattern`); gerekçe
dosyanın içinde. **`nixfmt`'i ağaç geneli çalıştırma** — elle hizalanmış yorum
sütunlarını siler.
