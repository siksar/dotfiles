# CLAUDE.md

Tek makinelik flake tabanlı NixOS yapılandırması: **Gigabyte AERO X16 (EG61H)**,
tek kullanıcı `zixar`, tek host `nixos`. Yorumlar ve commit mesajları Türkçe.

Bu dosya **kuralları ve tuzakları** taşır, envanteri değil. Bir gerçeğin ikinci evi
olursa orası eskir — envanter aşağıdaki dosyalarda:

| Ne arıyorsan | Nereye bak |
|---|---|
| konu → dosya haritası | `MAINTAINERS` (`grep -A8 'GÜÇ' MAINTAINERS`) |
| ağaç haritası + donanım tablosu | `README.md` |
| ölçüm defterleri | `Documentation/` |
| codex / GitHub Copilot kuralları | `AGENTS.md` — **ayrı dosya, birleştirme** |

Repo `/home/zixar/nixos-zixar`'da yaşıyor (root'un `/etc/nixos`'u oraya symlink).
Çalışma dalı ve GitHub varsayılanı `zixar`; diğer dört dal (`claude-md-audit`,
`rice/gnome`, `rice/caelestia`, `master`) onun **atası** — eski durumları okumak için
yer imi, birleştirilecek iş değil. **Dal adları içeriği anlatmaz**; güvenmeden önce
`git ls-tree -r --name-only <dal>`.

## Komutlar

```bash
nh os switch                                               # günlük sürücü
nixos-rebuild build --flake /home/zixar/nixos-zixar#nixos  # aktivasyonsuz kontrol
hms                                       # = nh home switch -b hm-backup (yalnız HM)
bash scripts/verify-context.sh            # kapı: iki eval + statix + deadnix (~13 s)
```

Test paketi yok. Doğrulama = `build` geçer, sonra `switch` + elle kontrol.
Güç/termal/WMI davranışı **ölçümle** doğrulanır, build'in geçmesiyle değil.

## Sert kurallar

1. **İki eval bağlamı birbirini import edemez.** `system/` + `usr/` NixOS modülü,
   `home/` Home Manager modülü; karıştırmak lint değil sert hatadır. İki katmanın da
   okuduğu şey `lib/`'e gider — `lib/theme.nix` ve `lib/gamerun.nix` modül değil,
   `{ pkgs }:` fonksiyonudur, iki taraf da çağırabilsin diye.
2. **`${./x}` ve `src = ./x` basename'i store adına çevirir** → o dosya/dizin
   TAŞINABİLİR ama YENİDEN ADLANDIRILAMAZ. Şu an bağlı olanlar:
   `system/arch/aerox16/acpi/patch-ssdt9.py`, `system/drivers/input/keyboard-rgb/src/`,
   `lib/schemes/*.yaml`, `lib/wallpapers/*`. `.nix` modülleri serbestçe adlandırılır
   (yalnız `import` edilirler). `builtins.readFile ./x` içeriği eval anında gömer —
   store kopyası yok, bu kuraldan muaf.
3. **`''…''` içindeki `#` Nix yorumu değil, script metnidir ve hash'e girer.**
   `wmi.nix`'in `postPatch`'inde bir yazım düzeltmesi ağaç-dışı çekirdek modülünü
   yeniden derletir ve initrd'yi yeniden hash'ler. (31 Tem 2026'da pahalıya öğrenildi.)
4. **Lint tabanı sıfır gürültü; sapma regresyondur.** `statix check .` temiz,
   `deadnix .` tam olarak 1 bulgu (üretilmiş `hardware-configuration.nix` — dokunma).
   `nixfmt`'i **ağaç geneli çalıştırma**, elle hizalanmış yorum sütunlarını siler.
   `nix run nixpkgs#…` kullanma: registry'nin nixpkgs'ini çözer, bu flake'in pin'ini
   değil. `statix.toml` iki kuralı kapatır (`repeated_keys` konu gruplamasını yok
   ediyordu, `empty_pattern` kozmetik); gerekçe dosyanın içinde.
5. **Grep/okuma bulgusu, bir şey çalıştırılana kadar bulgu değildir.** 15 Ağu 2026'da
   metin denetimi 31 "kesin" bulgu üretti; canlı eval **hepsini** çürüttü. Önce
   `verify-context.sh`, sonra rapor. (Bu yüzden `scripts/` altında doc-linter yok.)
6. **4.28 W boşta bütçesi geri gitmez.** `system/` veya `home/apps/games.nix` altına
   eklenen hiçbir şey boşta koşmamalı/yoklamamalı. AC/pil'e bağlı davranış
   **udev (`ACAD`) → oneshot servis** ile yapılır; timer ya da poll ile değil.
   Gerekçe: `system/kernel/sched.nix` başındaki tasarım kısıtı notu.
7. **Taşıma/yeniden adlandırma kanıtı** `verifying-a-refactor` skill'i (drvPath
   öncesi/sonrası karşılaştırması). Switch sonrası
   `nix store diff-closures /nix/var/nix/profiles/system-{N,N+1}-link` kapanış
   büyümesini boşta güce dönüşmeden yakalar.

## Mimari

**Tek `home.nix`, iki giriş** (`flake.nix`): `nixosConfigurations.nixos` gerçek
sistemdir (configuration.nix + Stylix + gömülü Home Manager);
`homeConfigurations."zixar"` yalnız HM tarafını hızlı denemek içindir ve Stylix'i
`lib/theme-standalone.nix` ile elle alır. İkisi de **aynı** `home.nix`'i okur —
yalnız birinin görebileceği HM ayarı ekleme.

**Masaüstü: COSMIC varsayılan, KDE Plasma ikinci oturum.** Giriş ekranı COSMIC
greeter (`system/desktop/login.nix`). Hyprland + Caelestia + Serpantinum Eylül
2026'da ağaçtan çıktı — o dönemin defteri
`Documentation/archive/desktop-hyprland-caelestia.md`'de donduruldu; güncel defter
`Documentation/desktop.md`. İki karşı-sezgisel kural: **`~/.config/cosmic` altına Nix'ten hiçbir şey
yazılmaz** (cosmic-config'in kullanıcı katmanı sistem katmanını ezer, ayar GUI'si
sessizce kaydedemez olur — COSMIC ayarları kasıtlı olarak imperatif bırakıldı) ve
COSMIC'in dGPU koruması `COSMIC_DRM_ALLOW_DEVICES` virgülle ayrılır, yani diğer
oturumların "iki nokta yasak" kuralının tersidir.

**Renklerin tek kaynağı Stylix.** Palet, opaklık, font, imleç `lib/theme.nix`'te.
Palet değiştirmek = `palette` satırını değiştir + rebuild; duvar kağıdı aynı
değişkenden türer. Uygulama başına renk ayarlama — hedefler GTK/ghostty/starship
vb.'yi kendiliğinden boyuyor.

**Güç**: `system/kernel/power.nix` power-profiles-daemon kullanır (TLP 18 Tem
2026'da kaldırıldı: governor + EPP + platform_profile'ı aynı anda yazması
amd-pstate=active ile kavga ediyordu). `power-display.nix` udev/ACAD → oneshot
zinciriyle parlaklık, webcam, tazeleme hızı **ve** PPD profilini ayarlar
(AC → balanced, BAT → power-saver; PPD kendi başına AC/pil ayrımı yapmaz).
Defter: `Documentation/aerox16/power.md`.

**CPU — hibrit Zen5/Zen5c**: hızlı çekirdekler `0,2,4,6`+SMT (5.09 GHz), verimli
çekirdekler `1,3,5,7`+SMT (3.5 GHz); zamanlayıcı bu farkı **görüyor** (amd_hfi + ITMT,
kanıt `Documentation/aerox16/cpu-hybrid.md`). `cores.nix` systemd `CPUAffinity`'sini
Zen5c'ye sabitler, yani bütün masaüstü orada koşar. Maske yumuşaktır ve `taskset`
onu deler: `gamerun` koşulsuz deler, tek seferlik ağır iş için fish alias'ı `aia`
(`aia cargo build`). `nix-daemon` muaf — derlemeler 16 CPU'yu da kullanır.

**Oyun**: `system/kernel/sched.nix` (gamemode, scx_lavd, ntsync, zram,
`game-perf.service`) + `lib/gamerun.nix` (sarmalayıcının kendisi). Steam launch
options `gamerun %command%` — **`%command%` zorunlu**, yoksa Steam metni sarmalayıcı
değil argüman sanar ve sessizce yutar. İki kural ölçümle kazanıldı: gamerun
**hiçbir Vulkan katmanı ve `LD_PRELOAD` enjekte etmez**, ve `game-perf.service`'i
doğrudan `systemctl` ile açar (`gamemoderun`'ın `LD_PRELOAD`'u pressure-vessel
kabında hiç çalışmıyordu). Üç çağıranı var — Steam (`usr/steam.nix`'in FHS
`extraPackages`'ı), `home/apps/minecraft.nix`, `home/apps/emu.nix` — env sözleşmesi
üçü için de taşıyıcı. Tablo ve gerekçe: `Documentation/gaming.md`.

**Ağ**: `system/net/core.nix` taban (NetworkManager, resolved, BBR, kablolu→WiFi
hakemi). `censorship.nix` hem zapret'i (nfqws + kendi nftables tablosu) hem
dnscrypt-proxy'yi (DoH → NextDNS) çalıştırır: nfqws trafiği kurtarır, DNS'i
kurtarmaz — ikisi bu yüzden aynı dosyada. **zapret ile Mullvad aynı anda çalışmaz**
(`vpn.nix` kapalı duruyor); ikisi de çıkış paketlerine dokunur.
`services.resolved.settings.Resolve.Domains = [ "~." ]` taşıyıcıdır — kaldırırsan
resolved ISP'nin DHCP DNS'ini tercih eder ve DoH zinciri baypas olur (bedeli:
captive portal'lar açılamaz). Desync stratejisi **ölçülmüştür**, tahmin değil:
`sudo blockcheck <alan>` ile doğrula.

**WMI/EC**: `system/arch/aerox16/wmi.nix` **kendi sürücümüzü** (`aero_eg61h`,
`~/aero-eg61h` deposundan flake input'u olarak) kurar ve `acpi_call` ile ham WMI/EC
yazar (fan eğrisi, NPCF.ACBT dGPU güç bütçesi). Topluluk sürücüsü `aorus-laptop`
7 Eyl 2026'da bırakıldı — üç ölçülmüş hatası vardı (yazılabilir ama etkisiz `pwm`,
sabit-sıfır temp2/temp3, PECM+0x2C'ye eksik yazım). Kırılgan, DSDT/EC sürümüne
bağlı, elle tersine mühendislik edilmiş alan — selektör değerlerini değiştirmeden
önce `Documentation/aerox16/wmi-ec.md`. Ağaç-dışı modül olduğu için çekirdek
değişince **reboot** ister.

## Documentation/

Elle tutulan, kalıcı ölçüm defterleri — kod yorumu değil. Bir ölçüm eklediğinde ya da
belgelenmiş bir davranışı değiştirdiğinde defteri de uzat; kod ile defter ayrışmasın.
`Documentation/archive/` **DONMUŞ**: içindeki yollar ve durumlar kasıtlı olarak eski,
"düzeltme".
