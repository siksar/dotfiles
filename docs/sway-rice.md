# Sway + noctalia-shell rice

Kaynak istem: vyrx-dev'in `dotfiles`/`symphony`/`toofan`/`Wallpapers` depolarındaki
Sway kurulumunun NixOS'a deklaratif bir benzerini kurmak, tüm kısayolları
Mod+G'ye bağlı bir cheatsheet'te toplamak. Modüller: `modules/desktop/sway-rice/`,
`modules/desktop/fish.nix`, `modules/apps/{tui,music}.nix`.

Bu rice **GNOME'un ve Hyprland rice'ının (`hyprland-rice/`) yerine geçmez** —
ly'de üçüncü, tamamen bağımsız bir oturum. Kullanıcı isteği gereği Hyprland
rice'ıyla kod paylaşmaz (iki rice birbirine bağlanmaz, kasıtlı kod tekrarı var).

## Kaynak depoların rolü

| Depo | Ne | Bizim için |
|---|---|---|
| `vyrx-dev/dotfiles` | Asıl Sway kurulumu: sway + noctalia + ghostty + fish + ~40 script | Ana kaynak |
| `vyrx-dev/symphony` | Arşivlenmiş Arch+Hyprland eye-candy (matugen, rofi menüleri) | Sadece fikir, kod alınmadı |
| `vyrx-dev/toofan` | Yazma pratiği TUI'si — nixpkgs'te yok, kendi flake'inden `packages.default` | Flake input |
| `vyrx-dev/Wallpapers` | Duvar kağıdı koleksiyonu — 1.05 GB | Flake input OLAMAZ; `noctalia`'nın `wallpaper.directory`'si `~/Pictures/Wallpapers`'a bakar, depo elle/opsiyonel klonlanır |

## Neden noctalia-shell (waybar+mako+fuzzel değil)

vyrx'in güncel sway config'i **noctalia** kullanıyor (waybar/mako satırları
yorumda duruyor, legacy yol). noctalia bar+bildirim+kontrol merkezi+launcher+
pano+OSD+kilit ekranı+idle+duvar kağıdını **tek pakette** verir — 8 ayrı
bileşen + 8 ayrı tema dosyası kurmak yerine tek bir deklaratif ayar yüzeyi.

**Deklaratiflik endişesi (araştırmayla çözüldü):** noctalia'nın config'i
**iki katmanlı**:

| Katman | Yol | Kim yazar |
|---|---|---|
| 1 — elle yazılan | `~/.config/noctalia/*.toml` | Nix (salt-okunur symlink) |
| 2 — GUI override | `~/.local/state/noctalia/settings.toml` | Ayarlar GUI'si + IPC (yazılabilir) |

Yükleme sırası: dahili varsayılanlar → katman 1 → katman 2. Upstream'in resmi
Home Manager modülü (`programs.noctalia.settings`, `noctalia.nix`) build
sırasında `noctalia config validate` çalıştırıyor — hatalı ayar rebuild'i
patlatır. `hm.nix`'te `inputs.noctalia.homeModules.default` `flake.nix`'te
`home-manager.sharedModules`'a (gömülü yol) ve standalone `homeConfigurations`
modül listesine eklendi.

## Stylix sınırı

```
Stylix (build-time, kanagawa-dragon, TÜM oturumlarda aynı)
  └─ ghostty, kitty, fish, tmux, yazi, zathura, bat, fzf, btop, gtk, qt, starship
     → GNOME'da da Hyprland'da da Sway'de de AYNI görünür

noctalia dahili Material You motoru (runtime, duvar kağıdından, SADECE sway)
  └─ noctalia UI + sway kenarlıkları + fuzzel + cava
     → stylix.targets.{sway,fuzzel,cava,noctalia}.enable = false ile devredilir
```

`stylix.targets.noctalia` **şartsız tetiklenir** (`programs.noctalia` var
olduğu anda `options.programs ? noctalia` true olur) ve `theme.source`'u
`"custom"` yapıp kendi paletini zorlar — kapatılmazsa `hm.nix`'teki
`theme.source = "wallpaper"` ile **build hatası** verir (conflicting
definition). İlk build'de gerçekten böyle patladı; `stylix.targets.noctalia.enable
= false` ekleyince çözüldü.

fuzzel de aynı nedenle Stylix'ten çekildi: `fuzzel.ini(5)`'in `include=`
direktifi sadece `[main]` bölümünün İÇİNDE geçerli (üst seviyede değil), bu
yüzden `programs.fuzzel.settings.main.include` kullanıldı; Stylix'in fuzzel
hedefi açık kalsaydı kendi `[colors]` bölümünü include'dan SONRA yazıp
noctalia'nın dinamik rengini ezerdi.

Terminal renkleri diskte Stylix'in kalır; duvar kağıdı değişince canlı sway
PTY'lerine (`/dev/pts/*`) OSC kaçış dizisi yazılır — kalıcı değil, oturum
kapsamlı (`sway-theme-sequences` scripti, hyprland rice'daki
`theme-sequences-apply`'ın sway kopyası).

İlk açılışta renk dosyaları henüz yokken oturum çıplak kalmasın diye
`home.activation.swayRiceSeedColors` Stylix paletinden bir kez seed yazar
(`hyprRiceSeedColors` ile aynı desen).

## Güç bütçesi — D3cold ve idle

- `WLR_DRM_DEVICES=/dev/dri/sway-igpu` (`programs.sway.extraSessionCommands`,
  **`sessionVariables`'ta DEĞİL** — GNOME/Hyprland'a sızmasın): wlroots
  sadece AMD iGPU'yu açar, NVIDIA dGPU node'una dokunmaz → RTD3 D3cold korunur.
  GNOME'daki `mutter-device-ignore` udev kuralı ve Hyprland rice'ındaki
  `AQ_DRM_DEVICES`'in aynı gerekçesi. Kendi udev symlink'i (`dri/sway-igpu`)
  kullanılıyor — hyprland-rice'ınkiyle çakışmasın diye.
- v4l2loopback (`run-scrcpy` webcam modu) `boot.extraModulePackages`'ta ama
  `boot.kernelModules`'a EKLENMEDİ — boot'ta otomatik yüklenip idle'da
  durmasın, script çalıştığında elle `modprobe` eder.
- mpd `services.mpd.network.startWhenNeeded = true` (systemd socket
  activation): ilk bağlantıya kadar sıfır maliyet, GNOME oturumunda hiç
  tetiklenmez.
- cava **otomatik başlamaz** (hyprland rice'taki aynı gerekçe) — `Alt+c` ile
  elle açılır.
- noctalia `[system.monitor]` poll aralıkları varsayılan (muhafazakâr)
  bırakıldı; ölçümde 4.28W tabanı gerilerse burası ilk kapatılacak yer.

**Doğrulanmadı, switch sonrası ölçülmeli:** pilde sway oturumunda boşta 5 dk
`current_now × voltage_now / 1e12` ile W hesabı, GNOME tabanıyla karşılaştır.

## Mod+G — kısayol cheatsheet'i

`keybinds.nix` **tek kaynak**: `binds` listesi (grup/tuş/eylem/açıklama)
buradan hem sway'in `keybindings` attrset'i hem `sway-cheatsheet` scriptinin
görüntü/eylem dosyaları üretilir. Bir kısayol eklendiğinde/değiştiğinde ikisi
ASLA ayrışamaz (bu dosya elle senkron tutulmalı — aşağıdaki tablo).

`sway-cheatsheet` `fuzzel --dmenu --index` kullanır: seçilen SATIRIN metnini
değil SIRASINI döndürür, böylece `--locked XF86AudioMute` gibi boşluk içeren
tuş kombinasyonlarını parse etmeye gerek kalmaz — index'ten paralel bir eylem
dizisine bakılır.

## Tam kısayol tablosu ($mod = Mod4/Super)

### Pencere & düzen
| Kısayol | Eylem |
|---|---|
| Mod+Return | Terminal (ghostty) |
| Mod+q | Pencereyi kapat |
| Mod+f | Tam ekran |
| Mod+w | Sekmeli düzen |
| Mod+v / Mod+Shift+v | Bölme yönü / kayan pencere |
| Mod+h / Mod+l | Sola / sağa odaklan |
| Mod+j / Mod+k | Önceki / sonraki çalışma alanı |
| Mod+←↑↓→ | 4 yöne odaklan |
| Mod+Shift+hl / Mod+Shift+←↑↓→ | Pencereyi taşı |
| Mod+1..0 / Mod+Shift+1..0 | Çalışma alanına git / pencereyi taşı |
| Mod+minus / Mod+Shift+minus | Scratchpad göster / gönder |
| Mod+Shift+z | Boyutlandırma modu (hjkl/oklar, Enter/Esc çıkar) |
| Mod+Shift+c | Sway config'ini yeniden yükle |
| Mod+Shift+e | Sway oturumunu kapat (swaynag onayı) |

### Uygulamalar
| Kısayol | Eylem | vyrx'ten sapma |
|---|---|---|
| Mod+b | Tarayıcı (zen) | ≠ brave/helium — zen zaten repoda |
| Mod+e | Dosya yöneticisi (nautilus) | ≠ thunar |
| Mod+c | VSCodium | ≠ code |
| Mod+o | Obsidian | — |
| Mod+d | Vesktop | — |
| Mod+m | Deezer | ≠ spotify — `apps/media.nix` deezer veriyor |
| Mod+Shift+t | toofan (yazma pratiği) | — |

### Terminal uygulamaları
`Alt+/` btop · `Alt+n` neovim · `Alt+m` rmpc · `Alt+q` yazi ·
`Alt+Escape` `tmux a` · `Alt+g` `gh dash` · `Alt+i` kanshi profil seçici ·
`Alt+c` cava (elle, idle bütçesi)

### Web uygulamaları (`launch-webapp` → chromium `--app`)
`Mod+a` ChatGPT · `Mod+Alt+a` Claude · `Mod+Shift+a` Gemini · `Mod+t` Todoist
· `Mod+y` YouTube · `Mod+Shift+g` GitHub (≠ vyrx: `Mod+g` — **Mod+g cheatsheet'e
verildi**) · `Mod+x` X · `Mod+Shift+w` WhatsApp · `Mod+\` DevHints

### Yardım
| **Mod+g** | **Kısayol cheatsheet'i** (aranabilir, Enter çalıştırır) |

### noctalia panelleri
`Mod+Space` launcher · `Mod+n` bildirimler · `Mod+Shift+n` aktifi temizle ·
`Mod+Ctrl+n` DND · `Mod+s` ses paneli · `Mod+.` ağ · `Mod+,` sistem ·
`Mod+i` caffeine · `Mod+Alt+n` gece ışığı · `Mod+Shift+Space` bar gizle/göster
· `Mod+Escape` oturum paneli · `Mod+Alt+l` kilitle · `Ctrl+Alt+Space` rastgele
duvar kağıdı · `Mod+Ctrl+Shift+Space` duvar kağıdı paneli · `Alt+,` pano
geçmişi (≠ vyrx: cliphist+fuzzel) · `Alt+.` emoji (≠ vyrx: 1900 satırlık
`fuzzel-emoji` scripti — noctalia launcher `/emo` sağlayıcısı düştü)

### Ekran görüntüsü / kayıt
`Mod+p` bölge (satty ile düzenle) · `Mod+Shift+p` tam ekran ·
`Alt+p` renk seçici (≠ vyrx: hyprpicker — Hyprland aracı, `grim|slurp -d` ile
değiştirildi) · `Mod+r` kayıt (masaüstü sesi) · `Mod+Alt+r` bölge kaydı ·
`Mod+Shift+r` mikrofonlu kayıt

Bu üç kayıt bind'i de `sway-screenrecord` scriptiyle `gpu-screen-recorder -w screen`
(doğrudan wlroots yakalama) kullanıyor — **portal'a hiç uğramıyor**, dolayısıyla
aşağıdaki not onları etkilemiyor.

**Portal tabanlı ekran paylaşımı (tarayıcı sekmesi paylaşımı, Discord/vesktop vb.)
27 Tem 2026'dan beri bilerek KAPALI** — `xdg.portal.wlr.enable` global bir opsiyon
olduğundan Hyprland/GNOME oturumlarına sızıp `xdg-desktop-portal-hyprland`'de bir
epoll busy-loop'a yol açıyordu (bkz. `docs/xdp-hyprland-busyloop.md`). Kaybedilen
işlevsellik pratikte muhtemelen sıfır: `xdg-desktop-portal-wlr`'ın kendi çıktı
seçicisi (hardcoded `wofi`/`bemenu`/`mew` fallback'i) sistemde hiç kurulu değildi,
yani bu yol muhtemelen daha önce de hiç çalışmıyordu. Geri açmak istenirse:
`modules/desktop/sway-rice/system.nix`'te `xdg.portal.wlr.enable = true;` eklemek
YETMEZ — önce bir `ConditionEnvironment=XDG_CURRENT_DESKTOP=sway` drop-in'iyle
Sway'e scoped edilmeli (aksi halde sorun geri döner) ve `~/.config/xdg-desktop-portal-wlr/config`
içine `chooser_type=none` + `output_name=…` yazılmalı (picker'ı bypass etmek için).

### Donanım tuşları
`XF86Audio{Mute,Raise,Lower,MicMute}` → noctalia (OSD dahil) ·
`XF86MonBrightness{Up,Down}` → noctalia · `Mod+XF86AudioRaise/Lower` →
`ddcutil setvcp 10 ±10` (harici monitör) · `Mod+F10/11/12` → önceki/oynat-
duraklat/sonraki (≠ vyrx: `mpc` — **playerctl**, tüm MPRIS oynatıcılarında
çalışır) · `XF86PowerOff` → uyku

### Diğer
`Ctrl+Shift+1/2` dahili/harici ekran aç-kapa · `Mod+Shift+BackSpace` scrcpy
ayna · `Mod+Ctrl+BackSpace` scrcpy webcam · `Mod+Shift+m` beats (radyo/YouTube
ses) · `Mod+Alt+space` oyun menüsü

**Düşen bind'ler:** `Mod+Alt+p` (Android emülatörü — SDK kurulu değil),
`Mod+BackSpace` (terminal saydamlık toggle'ı — `sed -i` ile config
dosyası düzenliyor, Nix symlink'iyle uyumsuz), `Mod+Alt+m` (dual-dac —
bizde olmayan bir DAC'a özel), `Alt+Space` (vyrx.dev).

## Nix-native karşılığı olduğu için düşen scriptler

`powermenu` (noctalia session paneli), `fuzzel-emoji` (noctalia launcher),
`battery-monitor` (noctalia `hooks.battery_under_threshold`), `set-wallpaper`
(noctalia duvar kağıdı paneli), `webapp-install`/`webapp-remove`/`webapps`,
`switch-waybar`, `switch-niri-mode`, `setup-portals.sh`, `setup-greetd`,
`setup-dns`, `ignore-power-button`, `choose-shell`, `dual-dac`, `audio-switch`
(`hyprctl` çağırıyordu — Hyprland'a özel), `toggle-terminal-transparency`,
`toggle-wlsunset` (noctalia nightlight).

## Doğrulanmadı / ilk girişte kontrol edilmeli

Bu liste bilinçli — build'i bloklamayan ama runtime'da yanlış çıkabilecek
varsayımlar:

- **`brightness.monitor."eDP-1".backlight_device = "amdgpu_bl1"`**
  (`noctalia.nix`) — `ls /sys/class/backlight/` ile doğrula (AMD iGPU,
  Intel'in `intel_backlight`'ı DEĞİL).
- **`window-rules.nix`'teki `app_id`ler** (`codium`, `vesktop`, `obsidian`,
  `deezer-enhanced`, `org.gnome.Nautilus`, `com.gabm.satty`) —
  `swaymsg -t get_tree` ile doğrula; yanlış eşleşme sessizce no-op'tur.
- **`services.kanshi` profilleri** — `laptop-harici` profili `criteria = "*"`
  ile genel geçer yazıldı, gerçek harici monitör adı/modu
  `swaymsg -t get_outputs` ile öğrenilip profil güncellenmeli.
- **noctalia'nın kilit ekranı PAM entegrasyonu** — `system.nix`'te
  `security.pam.services.noctalia` YAZILMADI (noctalia'nın hangi PAM servis
  adını beklediği doğrulanmadı); ilk `Mod+Alt+l` denemesi kilitten çıkamama
  riski taşıyor — TTY'den `loginctl unlock-session` kaçış yolu.
- **`fetch-lyrics` hook argümanları** (`apps/music.nix`) — rmpc'nin
  `on_song_change`'i argv mi env mi geçiyor, doğrulanmadı.
- **noctalia template token sözdizimi** (`{{ colors.<rol>.default.hex }}`) —
  dokümantasyondan alındı, ilk gerçek duvar kağıdı geçişinde çıktı
  dosyalarını (`~/.config/sway/colors` vb.) kontrol et.

## Geri alma

`configuration.nix`'te `rice.sway.enable = false;` — HM tarafı osConfig
üzerinden otomatik kapanır, `fish.nix`/`tui.nix`/`music.nix` da aynı bayrağı
okuduğundan hepsi birlikte devre dışı kalır. `users.users.zixar.shell` fish'te
kalır (login shell), geri almak için `system.nix`'teki
`users.users.zixar.shell = pkgs.fish;` satırını da silmek gerekir.
