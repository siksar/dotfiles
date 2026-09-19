# nixos-zixar

Tek makine için flake tabanlı NixOS yapılandırması: **Gigabyte AERO X16 (EG61H)**.
Tek kullanıcı (`zixar`), tek host (`nixos`). Masaüstü: COSMIC (varsayılan) +
GNOME (ikinci oturum). Yorumlar ve commit mesajları Türkçe.

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
├── default.nix                `nix repl ./` kapısı (rebuild yolu DEĞİL)
├── MAINTAINERS                konu → dosya haritası
├── CLAUDE.md                  kurallar + tuzaklar (Claude için)
├── AGENTS.md                  codex / GitHub Copilot için — ayrı dosya
│
├── system/                    ── NixOS modülleri: makinenin tesisatı ──
│   ├── arch/aerox16/          YALNIZ bu donanımda anlamlı (EC/WMI, DSDT).
│   │                          Makine değişirse ilk silinecek dizin burası.
│   ├── drivers/               gpu, input/keyboard-rgb, usb-dac (hidraw izni)
│   ├── kernel/                power, power-display, sched, cores (Zen5/Zen5c),
│   │                          ryzen-smu
│   ├── init/                  limine, locale
│   ├── net/                   core, censorship (zapret DPI bypass + DoH),
│   │                          vpn (Mullvad, kapalı), localsend, geoclue
│   ├── security/              users, keyring, askpass, onepassword
│   ├── desktop/               login (COSMIC greeter), cosmic (varsayılan oturum),
│   │                          gnome (ikinci oturum), theme (Stylix),
│   │                          mux (dGPU-only bayrağı, varsayılan KAPALI)
│   ├── sound.nix
│   └── virt.nix
│
├── usr/                       ── sistem geneli kurulan programlar ──
│                              steam, netflix, github-copilot, aero-eg61h
│
├── home/                      ── Home Manager modülleri ──
│   ├── shell/                 fish, starship, ghostty, tmux
│   └── apps/                  zen, helium, vesktop, media, games, minecraft,
│                              emu, opencode, downloads
│
├── lib/                       ── İKİ katmanın da paylaştığı saf veri ──
│                              theme.nix, theme-standalone.nix, schemes/,
│                              wallpapers/, gamerun.nix
│
├── Documentation/             ── yaşayan lab defterleri ──
│   ├── aerox16/               wmi-ec, power, cpu-hybrid, keyboard-rgb,
│   │                          fn-keys, undervolt, test-plan
│   ├── desktop.md (COSMIC+GNOME)   gaming.md  1password.md
│   ├── upstream/              üstakıma gönderilecek raporlar
│   └── archive/               DONMUŞ — yolları ve durumları kasıtlı eski
│
└── scripts/                   verify-context.sh (kapı), power-audit.sh,
                               idle-baseline.sh, diag-game.sh, tclt-probe.sh,
                               fn-probe.pl …
```

**Neden `lib/`:** duvar kağıtlarını ve base16 şemalarını hem sistem katmanı
(Stylix) hem kullanıcı katmanı okuyor; `gamerun` hem Steam'in FHS kabına hem
kullanıcı PATH'ine giriyor. `system/` altında bırakılsalardı `home/` oraya
`../../system/…` ile uzanacaktı. Çekirdekteki anlamıyla aynı: iki dalın da
paylaştığı şey.

### Katmanı nasıl anlarsın

`system/` ve `usr/` NixOS modülü, `home/` Home Manager modülü. İki eval bağlamı
birbirine **import edilemez** — karıştırmak sert hata verir. Bir konu iki
katmana birden dokunuyorsa iki dosyası olur, örneğin:

| Konu | Sistem tarafı | Kullanıcı tarafı |
|---|---|---|
| Oyun | `system/kernel/sched.nix` | `home/apps/games.nix` |
| Emülatör/oyun sarmalayıcı | `usr/steam.nix` (FHS kabı) | `home/apps/emu.nix` (PATH) |

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
bash scripts/verify-context.sh   # kapı: iki eval + statix + deadnix + zemin (~13 s)
deadnix .        # beklenen: 1 bulgu (üretilmiş hardware-configuration.nix)
statix check .   # beklenen: 0 bulgu — herhangi bir çıktı regresyondur
```

`statix.toml` iki kuralı kapatır (`repeated_keys`, `empty_pattern`); gerekçe
dosyanın içinde. **`nixfmt`'i ağaç geneli çalıştırma** — elle hizalanmış yorum
sütunlarını siler.
