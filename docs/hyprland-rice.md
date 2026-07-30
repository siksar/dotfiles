# Hyprland + Matugen dinamik tema rice'ı

Kaynak istem: "SaneAspect tasarımı — Hyprland 0.55+ (`hyprland.lua`), Matugen
tema motoru, `enes-less/theme-switcher` referanslı, Waybar/Rofi/SwayNC/Swww/Cava".
Bu doküman hem kurulumun **nasıl** çalıştığını hem de **neden** böyle kurulduğunu
anlatır. Modüller: `modules/desktop/hyprland-rice/`.

## Önce gerçeklik kontrolü (istemdeki iddialar)

| İddia | Durum |
|---|---|
| Hyprland 0.55+ `hyprland.lua` ile yapılandırılıyor | **Doğru.** 0.55 (Haz 2026) hyprlang'i deprecate etti; Lua artık resmî config. Kilitli nixpkgs'te 0.55.4 var — flake input eklemek gerekmedi. |
| HM Lua config destekliyor | **Doğru.** `configType = "lua"` + `extraLuaFiles` (HM 26.05+). |
| `enes-less/theme-switcher` deposu | **Var.** JSON palet + `.tpl` şablon motoru; `dynamic` teması matugen'le duvar kağıdından renk üretiyor. SUPER+T/SUPER+W kısayol deseni oradan alındı. |
| Swww paketi | **Var ama yeniden adlandı.** Kilitli nixpkgs'te `swww` → `awww` (binary'ler `awww`/`awww-daemon`, sürüm aynı 0.12.1). Modül `pkgs.awww` kullanır; betikler `awww img`/`awww query` çağırır. |
| Matugen "Oklab renk uzayı" kullanır | **Yanlış.** Matugen, Material You standardı gereği **HCT** (Hue-Chroma-Tone, CAM16 tabanlı) kullanır; changelog'unda Oklab yok. HCT de Oklab gibi algısal-düzgün bir uzaydır — pratik sonuç (duvar kağıdından tutarlı, algısal dengeli palet) aynıdır. Oklab şart olsaydı matugen yerine başka araç gerekirdi. |

## Mimari — zincir

```
SUPER+T → wallpaper-picker (rofi ikon grid'i, ~/Pictures/Wallpapers)
             └→ theme-apply <resim>
                  ├→ awww img  (animasyonlu geçiş — kullanıcı hemen görür; awww = eski swww)
                  └→ matugen image -m dark -t scheme-tonal-spot
                       ├→ ~/.config/hypr/colors.lua    → post_hook: hyprctl reload
                       ├→ ~/.config/waybar/colors.css  → post_hook: waybar restart
                       ├→ ~/.config/rofi/colors.rasi   → (hook yok; her açılışta okunur)
                       ├→ ~/.config/swaync/colors.css  → post_hook: swaync-client --reload-css
                       ├→ ~/.config/cava/config        → post_hook: pkill -USR2 cava
                       └→ ~/.config/theme-switcher/sequences
                            → post_hook: theme-sequences-apply --all (tüm PTY'ler)
```

- **Neden önce awww (swww), sonra matugen?** Algılanan gecikme: duvar kağıdı anında
  değişir, renkler ~yarım saniye sonra oturur (referans repo da böyle yapar).
- **Neden referans repodaki bash+jq+sed şablon katmanı yok?** Orada statik JSON
  temaları (catppuccin, gruvbox…) da aynı motordan geçiyor; bizde tek "dinamik"
  tema var — matugen'in kendi şablon motoru (`{{colors.X.default.hex}}`) yeterli.
  İkinci şablon katmanı = ikinci hata yüzeyi.
- **Kalıcı durum:** son duvar kağıdı `~/.local/state/theme-switcher/current-wallpaper`.
  Girişte `autostart.lua` → `theme-apply --restore` (yoksa Stylix duvar kağıdına düşer).
- **Kaynak renk adayı seçimi (miasma bug'ı, 16 Tem):** matugen bir resimden birden
  çok aday kaynak renk çıkarır; `--source-color-index 0` (baskın renk) koyu/soluk
  duvar kağıtlarında hep nötr koyu gri-mavi çıkıyordu → miasma/kanagawa/tsushima
  hepsi AYNI maviye çalan paleti veriyordu. Ölçüm (miasma): index0 `#383c43`
  (kroma 11, mavi), index1 `#8c9373` (kroma 32, zeytin — doğrusu). theme-apply
  artık adayları `--dry-run -j hex` ile gezip **en kromatik** olanı
  (max−min RGB) seçer; sonuç: miasma→zeytin `#bbcf81`, gruvbox-material→altın
  `#d8c770`, tsushima→mavi `#88d0ec` (her resim kendi paleti). Activation
  tohumu index 0'da kaldı (tek seferlik, ilk SUPER+T düzeltir).
- **Terminal ANSI paleti de dinamik (16 Tem, pywal deseni):** matugen
  `templates/terminal-sequences` şablonundan OSC escape dizileri üretir
  (`\033]4;N;#hex\a` paleti, `]10/]11/]12` fg/bg/imleç); `theme-sequences-apply`
  bunları tema değişince `--all` ile TÜM açık PTY'lere basar, yeni terminaller
  bash başlangıcında (yalnız Hyprland oturumunda, `HYPRLAND_INSTANCE_SIGNATURE`
  bekçisi) kendine uygular. starship/fastfetch zaten ANSI İSİMLİ renk kullanır
  (shell.nix) → otomatik uyar. Eşleme: 1/9=error (hep kırmızı), 2/10=yeşil
  4/12=**primary** (starship "bold blue" dizini tema aksanı olur), 3/11/5/13/6/14
  = primary'nin hue-döndürülmüş halleri (`| set_hue:` filtresi — tema kromalı
  semantik renkler). Ghostty'nin statik Stylix teması taban/fallback kalır
  (GNOME oturumu + ilk açılış); OSC yalnız runtime'da üzerine boyar.
  **Tuzak:** OSC ST sonlandırıcısı `\033\\` KULLANILAMAZ — matugen şablon motoru
  `\\`'ı `\`'a indirger; BEL (`\a`) kullanılır. Şablonda kaçışlar metin olarak
  durur, `printf %b` uygulama anında çözer (`grep -v '^#' | tr -d '\n'` sonrası).
- **gruvbox-material.jpg** (`modules/desktop/wallpapers/`): elde üretilmiş sisli
  katmanlı çam ormanı — miasma tarzında, gruvbox-material paletiyle (zemin
  #32302f→#7d7450 sis, katmanlar #5e5c42→#222619, sis #d8c07a). SVG+awk üretimi;
  seçilince matugen ~gruvbox-material paleti türetir (primary ~#d8c770).
  Kullanıcı tercihi: bundan sonra duvar kağıtları hep bu "miasma tarzı"
  (sisli, koyu, katmanlı doğa, desatüre) olacak.

## Lua config nasıl HM'ye entegre edildi

`wayland.windowManager.hyprland` şunlarla:

- `configType = "lua"` → HM `~/.config/hypr/hyprland.lua` üretir.
- `extraLuaFiles = { main, theme, binds, rules, autostart }` → her biri
  `hypr/<ad>.lua` olarak yazılır ve `hyprland.lua` bunları otomatik `require`
  eder. `settings` attrset'i bilinçli kullanılmadı: attrset→Lua çevirisi taze
  (HM issue #9468) ve gerçek Lua dosyası hem kaynak hem dokümantasyon.
- `package = null; portalPackage = null` → paket **sistemden**
  (`programs.hyprland.enable`, system.nix) gelir; çifte kurulum/portal
  çakışması olmaz.

Kritik incelik — `theme.lua` renkleri `require` ile değil **`dofile`** ile okur:
`require` sonucu önbelleğe alır (`package.loaded`); `hyprctl reload` sonrası
eski renkler dönebilirdi. `dofile` her reload'da diskten taze okur.

## GNOME ile birlikte yaşama (bu repo için kritik)

- `programs.hyprland.enable` GNOME'u **değiştirmez**; GDM'de "Hyprland" ikinci
  oturum olur. GNOME + tüm dconf ayarları aynen kalır.
- Waybar/SwayNC/awww **systemd user servisleri** olarak
  `hyprland-session.target`'a bağlı — `graphical-session.target`'a değil.
  Neden: graphical-session GNOME oturumunda da aktifleşir; yanlış target
  seçilirse waybar GNOME'un içinde belirir.
- **Stylix çakışması:** Stylix bu repoda renklerin tek kaynağı; ama rice
  bileşenlerinde renk sahibi matugen olmalı. Bu yüzden yalnız
  `stylix.targets.{hyprland,waybar,rofi,swaync,cava}.enable = false` — GTK,
  ghostty, starship vb. Stylix'te kalır. İki sistem yan yana: Stylix "statik
  taban", matugen "dinamik rice katmanı".

## Animasyon + görünüm (Anto98765/My-Hyprland-Rice portu)

`main.lua`'nın LOOK AND FEEL + ANIMATIONS bölümleri aynı repodan porte edildi
(`.config/hypr/modules/{animations,look_and_feel}.conf`): pencereler slide ile
açılır / popin 80% ile kapanır, fareyle sürükleme `windowsMove` ile animasyonlu,
workspace geçişi slide, layer'lar (rofi/waybar) animasyonlu; gaps 7/10,
border 1px, rounding 12 (power 4), gölge range 15, blur size 2 × 2 pass +
contrast 1.6 + popups. Bilinçli sapmalar (main.lua yorumlarında):

- **`borderangle loop` ATLANDI** — gradyan kenarlığı sürekli döndürmek idle'da
  bile her karede repaint demek; 4.28W bütçesini doğrudan ihlal ederdi.
- Süreler kaynaktan ~%25 kısa (kullanıcı: "biraz daha hızlı") — kaynak değerler
  main.lua satır-sonu yorumlarında.
- İmleç: apple-cursor **macOS-White** (stylix-base.nix cursor.name — Stylix tüm
  oturumlara uygular, GNOME dahil).
- Saydamlık kaynakta 1/1 (opak); bizde 0.92/0.86 korunur (Stylix senkron kararı).
- `resize_on_border=true` ve `allow_tearing=false` bizde kaldı (alışkanlık/VRR).

## Waybar tasarımı (Anto98765/My-Hyprland-Rice portu)

Kaynak: <https://github.com/Anto98765/My-Hyprland-Rice> (`.config/waybar/`) —
16 Tem 2026'da porte edildi; önceki bölünmüş-saat/sekme tasarımının yerini aldı.
Transparan tam genişlik bar, koyu pill gruplar; renkler matugen'in TÜM Material
You token'ları olarak `colors.css`'e basılır (şablon: `templates/waybar-colors.css`,
kaynak repoyla aynı `<* for name, value in colors *>` döngüsü).

Düzen: solda `group/start` (Nix menü → rofi drun, RAM → tık `ghostty -e btop`) +
tepsi; ortada 5 kalıcı NUMARASIZ workspace kapsülü (kaynakta numaralıydı —
kullanıcı isteğiyle boş pill); sağda `group/control` (ağ · ses · pil,
tık → swaync paneli) + fan profili + saat (12h, tık → tarih). Ağ modülü
IP/gateway GÖSTERMEZ (kullanıcı isteği; kaynakta ethernet formatı
`{ipaddr}/{cidr}` idi).

Kaynağa göre bilinçli sapmalar (`hm.nix` yorumlarında da işaretli):

- `power-profiles-daemon` modülü → **`custom/fan`**: waybar'da güç profili yerine
  fan modu gösterilir (PPD sistemde açık ama bu modül fan_mode'u izler).
  `fan-status` scripti `aorus_laptop/fan_mode` sysfs'ini
  okur; modül `interval="once"` + `signal=8` — idle'da poll YOK,
  `fan-mode-cycle.service` (SUPER+M ile aynı) mod değişiminde `SIGRTMIN+8`
  yollar (gigabyte-wmi.nix). Tıklama da aynı servisi tetikler (polkit şifresiz).
- `interface="wlo1"` hardcode'u atıldı (bizde wlan0); `networkmanager_dmenu`
  ve `kitty` kurulu değil → rofi/ghostty eşlenikleri.
- Upstream bug düzeltildi: battery state `mid` tanımlı ama CSS `.med` arıyordu.
- `clock` interval 1 sn → 60 sn (format zaten dakika çözünürlüklü).
- `rimouski` fontu nixpkgs'te yok → JetBrainsMono Nerd Font Propo.
- cava kaynak tasarımda da yok — bardan çıktı, idle bütçesi geri kazanıldı
  (paket duruyor, tema motorunun cava şablonu terminal kullanımı için sürüyor).

## Waybar çoklu tema sistemi (28 Tem 2026)

Yukarıdaki tasarım artık **16 seçenekten biri** ("current" adıyla), yanına
`atif-1402/minimal-waybar-themes` reposundaki 15 varyant (V1 … V7 ve alt
sürümleri) porte edildi. Amaç: hepsini yan yana deneyip birini seçmek, hepsini
**tek bir monokrom paletten** boyamak. Kod: `waybar-themes.nix`,
`waybar-mono.css`, `waybar-mono-overrides.css`, `waybar-omarchy-compat.nix`,
vendor'lanmış temalar `waybar-themes/<V>/`.

**Çakışma çözümü — store'dan çalıştırma.** HM'in ürettiği
`~/.config/waybar/{config,style.css}` symlink'lerine hiç dokunulmadı. Her tema
store'da kendi dizininde durur; `waybar-launch` (hm.nix) state dosyasına göre
`waybar -c <dizin>/config.jsonc -s <dizin>/style.css` ile başlatır — `"current"`
(veya bilinmeyen bir değer) argümansız `waybar`'a düşer, yani HM modülünün
ürettiği bar. `systemd.user.services.waybar.Service.ExecStart` bu script'e
`lib.mkForce` ile yönlendirilir; `programs.waybar`'ın `systemd.targets` ayarı
(GNOME'a sızmama koruması) buna dokunulmadan aynı kalır.

**Palet tek kaynak.** `waybar-mono.css` (`@background #0d0e10` … `@bright
#eceff2` — saf siyah/beyaz değil, halation/banding'den kaçınmak için) her
temanın import hedefi olur. `waybar-mono-overrides.css` (aktif workspace =
kontrast+kalın+alt kenarlık, kritik durum = ters kontrast) her temanın
`style.css`'inin **sonuna** eklenir — CSS'te sonda olmak import'un başta olması
kadar önemli, yoksa temanın kendi kuralları kazanır. Palet dosyasına ASLA
tema-özel renk eklenmez; bir override bir temada tutmuyorsa (farklı sınıf adı)
düzeltme override dosyasına eklenir, palet dokunulmaz.

**mkTheme (waybar-themes.nix) build-time'da üç şey yapar:**
1. `@import "../omarchy/current/theme/waybar.css";` → mutlak palet yolu
   (13/15 tema bunu kullanıyor; 2'si — V1, V1.5 — hiç `@import` etmiyor,
   literal hex/keyword renk kullanıyordu, o ikisinde renkler elle `@değişken`
   referanslarına çevrildi, bkz. aşağıda).
2. `~/.config/waybar/` → temanın kendi `$out/` yolu (config'lerdeki VE
   script'lerdeki hardcode).
3. `patchShebangs` + `chmod +x` — hepsi `#!/bin/bash` veya
   `#!/usr/bin/env bash` ile geliyor, NixOS'ta `/bin/bash` yok.

**omarchy uyumluluk katmanı** (`waybar-omarchy-compat.nix`): ~180 `omarchy-*`
çağrısını tema başına elle düzeltmek yerine, aynı isimlerde ince shim'ler
üretilip **yalnız `waybar-launch`'ın PATH'ine** eklendi (`home.packages`'a
sızmaz). Karşılıklar: `omarchy-menu` → rofi drun / rofi tabanlı güç menüsü
(`hyprland-rice`'ta lock screen yok, o yüzden "Kilitle" seçeneği eklenmedi),
`omarchy-launch-wifi/-bluetooth` → `ghostty -e nmtui`/`bluetuith`,
`omarchy-cmd-screenrecord` → `gpu-screen-recorder` toggle (sway-rice'ın
`sway-screenrecord`'unun portu; bu yüzden `programs.gpu-screen-recorder.enable`
artık hyprland-rice'ın `system.nix`'inde de açık), `omarchy-update-available`
→ her zaman boş çıkış (waybar modülü otomatik gizler). `$OMARCHY_PATH/default/
waybar/indicators/*.sh` üç gösterge de aynı katmanda.

**Elle düzenlemeler** (jq ile 15 farklı şekilli JSON'a modül enjekte etmek
yerine, vendor'lanmış dosyalarda doğrudan):
- Battery hiçbir temada `bat` alanı belirtmiyordu (waybar ilk bulduğu BATn'i
  kullanır — bu makinede yine BAT1 olurdu ama explicit yapıldı) ve birçoğunda
  hiç referans edilmiyordu (tanımlı ama modül listesinde yok — upstream'in
  "batarya test edilmemiş" durumunun somut hali). Hepsine `"bat": "BAT1"`,
  `interval: 30`, gerekiyorsa `states.warning/critical` eklendi.
- Backlight hiçbir temada yoktu → hepsine `device: "amdgpu_bl1"` ile eklendi.
- Interval normalizasyonu: upstream'in `cpu`/`memory` modülleri çoğunlukla
  `interval: 2` kullanıyordu → 30'a çekildi (4.28W idle bütçesi).
- Ölü/yanlış ikili çağrılar düzeltildi: `xdg-terminal-exec` → `ghostty`,
  `pamixer -t` → `pactl set-sink-mute @DEFAULT_SINK@ toggle`, `alacritty` →
  `ghostty` (V3).
- **V1**: `sway/mode` modülü kaldırıldı (Sway IPC'siz hyprland'da anlamsız);
  yazarın "bu dosyayı `~/.config/hypr/scripts/`'e taşı" notuyla bıraktığı
  tuhaf-isimli dizinden `volume.sh` doğru adla vendor'landı (kullanılmıyor,
  referanssız — dokunulmadı).
- **V1, V1.5**: `@import` hiç yoktu, literal `white`/`#121212`/`aliceblue`
  gibi renkler `@foreground`/`@surface`/`@bright` referanslarına çevrildi —
  palet dosyası değişmeden bu iki temanın da monokroma girmesi bu sayede oldu.
- **V3.Ω/V3.Ωx dizin adları `V3.Omega`/`V3.Omegax`** — Nix store path'i ASCII
  dışı karakter kabul etmiyor.
- **V3.Omegax**: üst bar (`top`) + alt bar (`bottom/config`) waybar'ın
  çoklu-bar desteğiyle **tek `config.jsonc`'te JSON dizisi** olarak birleşti
  (`[ {üst-bar}, {alt-bar} ]`, tek `waybar` süreci, tek paylaşılan `style.css`).
  Üst bardaki `custom/secbar` (ikinci barı ayrı bir `waybar -c` süreciyle
  açıp/kapatan toggle) bu yüzden anlamsızlaştı ve kaldırıldı — iki bar artık
  hep birlikte açılıyor. **cava.sh sürekli çalışıyor** (pactl+cava boru hattı) —
  bu, bu tema seçiliyken idle bütçesine ek yük demek; karar öncesi ölçülmeli.
- **V4.y**: `configs/bar.jsonc`+`configs/dock.jsonc` planda "diziye alınır"
  deniyordu, ama dosyaları okuyunca ikisinin neredeyse birebir aynı olduğu
  (sadece yükseklik/kenar farkı) ve ikisinin de `position: top` olduğu ortaya
  çıktı — diziye alınsalar aynı kenarda iki neredeyse-özdeş bar üst üste
  binerdi. Bunun yerine daha dolgun `dock.jsonc`/`dock.css` çifti tek tema
  olarak seçildi, `mode.sh` (ikisi arasında dosya kopyalayarak geçiş yapan
  script — store'un salt-okunur olmasıyla zaten uyumsuzdu) ve `custom/mode`
  modülü kaldırıldı.

**Geçiş — rebuild'siz.** `waybar-theme` (`home.packages`, `hm.nix`):
`--list` (16 isim), `<ad>` (state dosyasına yaz + `systemctl --user restart
waybar.service`), `--pick` (rofi seçici), `--reset` (Nix varsayılanına dön).
Kısayol **SUPER+W** (`lua/binds.lua`). Temiz kurulumdaki varsayılan
`rice.hyprland.waybarTheme` (`system.nix`, varsayılan `"current"`) — normal
`enable` seçeneğiyle aynı `osConfig` izleme deseni.

**Bilinçli bırakılanlar:** her temadaki `custom/omarchy`, `mpris`, `custom/lock`
gibi modüllerin bir kısmı upstream'de zaten hiçbir `modules-left/center/right`
listesinde referans edilmiyor (V7'nin `"group/right1"` yazım hatası dahil, ki
bu yüzden `pulseaudio` de hiç görünmüyordu — düzeltildi). Referanssız olanlar
(ör. V1'in `mpris`+`volume.sh`'i) dokunulmadan bırakıldı; çalışmıyor olmaları
zaten hiçbir şeyi bozmuyor.

## Rofi launcher teması — adi1090x type-5/style-4 (29 Tem 2026)

**İstek:** `adi1090x/rofi`'nin type-5 / style-4 launcher'ı kurulsun, renkleri
**aktif waybar temasıyla** uyumlu olsun.

**Neden mono, neden matugen değil.** İstek anında aktif waybar teması `V5`'ti ve
V-temalarının **hepsi** `waybar-mono.css`'ten besleniyor — statik, tek renk
ailesi. Rofi ise matugen'den besleniyordu, yani duvar kağıdıyla renk
değiştiriyordu. İkisi bu yüzden zaten uyumsuzdu. Kullanıcı çatalı **saf
monokrom** yönünde çözdü: rofi artık `waybar-mono.css`'i okuyor, bedeli rofi'nin
duvar kağıdını takip etmemesi.

**Tek renk kaynağı.** `rofi-themes.nix`, `waybar-mono.css`'teki
`@define-color ad #hex;` satırlarını Nix tarafında ayrıştırıp attrset'e çevirir.
Paleti Nix'e kopyalamak yerine CSS'i okumasının nedeni: waybar o dosyayı
`@import` ile okumak **zorunda**, iki kopya kaçınılmaz olarak ayrışırdı. Sonuç:
`waybar-mono.css`'teki bir hex'i değiştirmek 15 waybar temasını **ve** rofi'yi
birlikte döndürür.

**Katman düzeni — waybar'la birebir aynı desen.** Üst kaynak dosya
(`rofi-themes/type-5/style-4.rasi`) bit-bit vendor'lanır; renge ve ölçüye dair
her sapma `rofi-mono-overrides.rasi`'de durur ve build-time'da dosyanın **sonuna**
eklenir. rasi'de de CSS'te olduğu gibi son kural kazanır — sıra ters çevrilirse
üst kaynağın turuncu/yeşil/kırmızısı geri gelir. Doğrulandı: birleştirme
**özellik bazında** oluyor, yani `window`'un üst kaynaktan gelen
`border-radius: 20px` / `transparency: "real"` değerleri, biz yalnız `width` ve
`background-color` ezsek de korunuyor.

**rofi 2.0'ın gradient tuzağı (ölçüldü).** `linear-gradient(...)` **içinde**
`@değişken` kullanılamıyor: rofi ayrıştıramıyor ve o tek satır yüzünden tema
dosyasının **tamamını** sessizce reddedip dahili Solarized **light** temasına
düşüyor (`rofi -theme … -dump-theme` → "Failed to parse theme", çıktıda
`#fdf6e3`). Aynı `@değişken` gradient dışında sorunsuz çalışıyor. style-4'ün
seçim şeridi gradient olduğu için tüm renkler build-time'da literal hex'e
çevriliyor — yer tutucular (`rofi-mono-overrides.rasi`) bu yüzden var.

**Solarized mirası — bugün ısırmıyor, yine de yazıldı.** Üst kaynak dokuz
`element` durumundan yalnız üçünü boyuyor. rofi 2.0'da bu sorun değil: ölçüldü,
`@theme` dahili temayı **birleştirmiyor**, tamamen değiştiriyor — boyanmamış
durum genel `element` kuralına düşüyor, beyaz satır üretmiyor. Yine de dokuzu da
açıkça yazıldı; rofi birleştirme davranışına dönerse tema sessizce okunmaz
hale gelirdi.

**Renk eşlemesi.** Üst kaynak zaten neredeyse monokromdu; yalnız üç vurgu rengi
paletin gri basamaklarına indirildi: `#FF9030` (seçili satır, aktif sekme) →
`bright`, `#19B466` (çalışan uygulama) → `color6`, `#EA5553` (seçili+çalışan) →
`bright`. Zeminler: `#22272C` → `background`, `#2E343B` → `surface`, gradient
sol durağı `#4C4F52` → `overlay`.

**HiDPI sapması.** Panel 2560x1600 @ scale 1 (~189 dpi), üst kaynak ~96 dpi
varsayıyor. Oranlar korunarak büyütüldü: pencere 800→1100px, yazı Iosevka 10 →
JetBrainsMono Nerd Font 12 (rice'ın geri kalanıyla tek yüz), ikon 24→28px,
inputbar/mode-switcher yan boşluğu pencerenin %25'i kalsın diye 200→275px.

**Kapsam.** `programs.rofi.theme` bu temayı gösterdiği için SUPER+D (drun),
`waybar-theme --pick` ve tema belirtmeyen her `rofi -dmenu` çağrısı bu görünümü
alır. SUPER+T'nin duvar kağıdı grid'i (`wallpaper-grid.rasi`) kendi ikon-grid
düzenini korur ama aynı paleti kullanır — `rofi/mono-colors.rasi`'yi `@import`
eder. O dosya matugen'in `colors.rasi`'siyle **aynı değişken adlarını** taşır:
grid'i (ya da yeni bir menüyü) dinamik renklere döndürmek tek satırlık import
değişikliği. Eski `zixar-rice.rasi` teması kaldırıldı; matugen'in rofi şablonu
kaçış kapısı olarak duruyor (çalışmaya devam ediyor, sadece artık okunmuyor).

## Saydamlık (uygulama CSS'i + Hyprland senkron)

İstek: "zen/codium/steam/deezer... hepsinin saydamlığı Hyprland'le senkron
olsun, CSS'i Stylix yönetsin." İki ayrı mekanizma, iki farklı kapsam — ikisi
birlikte kullanılıyor:

**1. Compositor saydamlığı (Hyprland `active_opacity` + blur) — HER pencere.**
`main.lua`'da `active_opacity = 0.92`, `inactive_opacity = 0.86`, blur açık.
Bu compositor seviyesinde uygulanır → **steam, deezer, vscodium dahil istisnasız
her pencere** camsı olur, arkasında blur. Stylix hedefi olsun olmasın fark etmez;
"hepsi için saydamlık" isteğini karşılayan budur. Tam ekran pencereler (oyunlar)
bunu baypas eder → oyunlar opak, idle/perf bütçesi güvende.

**2. Uygulama CSS opacity'si (Stylix) — yalnız destekleyen uygulamalar.**
`stylix.opacity` (stylix-base.nix, TEK KAYNAK): `terminal = 0.85` (ghostty),
`applications = 0.92` (zen-browser, mangohud). Stylix bunu uygulamanın kendi
CSS'ine hex alpha olarak enjekte eder — yalnız pencerenin arka planı/chrome'u
şeffaf olur, içerik okunur kalır. Doğrulandı: ghostty config'inde
`background-opacity = 0.85`, zen userChrome'da renkler `#RRGGBBEB` (EB=0.92).

**Senkron:** `stylix.opacity.applications` (0.92) ile Hyprland `active_opacity`
(0.92) ELLE eşitlenir — birini değiştirirsen ötekini de (her iki dosyada da
çapraz-referans yorumu var). Programatik tek-kaynak yapılmadı çünkü nested
`hl.config` merge semantiği (decoration'ı ikinci dosyadan parçalamak blur'ü
silebilir) doğrulanamadı; eşit literal + yorum güvenli yol.

**Uygulama bazında durum:**

| Uygulama | Stylix renk teması | Saydamlık kaynağı |
|---|---|---|
| ghostty | ✅ | Stylix `opacity.terminal` (0.85) + Hyprland blur |
| vscodium | ✅ (renk) | Hyprland — **kendi kuralı** `opacity = 0.94` (bkz. aşağı) |
| vesktop | ✅ | Hyprland `active_opacity` |
| zen-browser | ⏸️ ertelendi (bkz. aşağı) | Hyprland `active_opacity` |
| steam | ❌ (Stylix hedefi yok) | Hyprland `active_opacity` |
| deezer | ❌ (electron, hedef yok) | Hyprland `active_opacity` |

**Zen renk teması neden ertelendi:** Stylix zen hedefi CSS'i yalnız HM-yönetimli
bir profile yazabiliyor; kullanıcının zaten verili bir runtime profili var
(`~/.config/zen/r1lawe90.Default Profile`). HM'ye almak profiles.ini'yi
symlink'leyip mutable-copy çakışması/boş-profil riski doğuruyor. Güvenli reçete
`modules/apps/zen.nix` içinde yorumlu — kullanıcı onayı + switch sonrası
doğrulama gerektiren bilinçli adım. Saydamlık zaten Hyprland'den geliyor;
ertelenen yalnız zen'in *renk* teması.

**GNOME oturumu notu:** `stylix.opacity` GNOME'da da uygulanır ama GNOME pencere
blur'ü yapmaz → orada şeffaf terminal blur yerine düz duvar kağıdını gösterir.
Camsı görünüm Hyprland oturumuna özgü (blur orada).

## Pencere süslemesi politikası (30 Tem 2026)

İstek: "tüm uygulamaların başlık çubuğunu Hyprland'a bırak." Araştırma sonucu:
istek olduğu gibi karşılanamaz, çünkü "başlık çubuğu" üç ayrı şeyin adı ve
yalnız ikisi kontrol edilebilir. Sonuçlar aşağıda; bir daha araştırılmasın.

**Hyprland zaten sunucu-taraflı süsleme talep ediyor.** Binary'de
`zxdg_decoration_manager_v1` var ve `unsetMode. Sending MODE_SERVER_SIDE.`
string'i geçiyor → xdg-decoration protokolünü konuşan **her** uygulamaya
"sunucu dekore edecek" cevabı veriliyor. Hyprland'ın sunucu-taraflı süslemesi
ise yalnız **border + rounding**; başlık çubuğu hiç çizmiyor. Yani protokolü
konuşan uygulama otomatik olarak çubuksuz kalıyor (ghostty, zen böyle).

**Kategori 1 — Electron/Chromium: ÇÖZÜLDÜ, tek satır.** nixpkgs'in Electron
sarmalayıcıları şu kalıbı taşır:
```
${NIXOS_OZONE_WL:+ --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}
```
Değişken tanımsızken flag hiç eklenmiyordu → VSCodium/Vesktop/1Password/
claude-desktop **XWayland'de** koşuyordu (bulgu 30 Tem; `codium` sarmalayıcısında
teyit edildi). `configuration.nix`'te `environment.sessionVariables.NIXOS_OZONE_WL
= "1"` bunu çevirir: native Wayland + xdg-decoration → yukarıdaki SERVER_SIDE
cevabı → uygulama kendi süslemesini çizmez. Bonus: HiDPI'de net render, kesirli
ölçekleme. `claude-desktop-pkg.nix` bu değişkeni zaten koşul olarak kullanıyordu,
yani o paket de ancak şimdi Wayland'e geçti.

**Kategori 2 — Qt: pratikte gereksiz.** `QT_WAYLAND_DISABLE_WINDOWDECORATION=1`
diye bir kaçış var, ama Hyprland zaten SERVER_SIDE dediği için Qt uyuyor.
Ayrıca bu sistemde kayda değer Qt GUI'si yok (pavucontrol GTK). **Ayarlanmadı.**

**Kategori 3 — GTK/libadwaita: MÜMKÜN DEĞİL, üstelik istenmez.** Nautilus vb.
uygulamaların üst çubuğu bir `GtkHeaderBar`: içinde yol çubuğu, arama ve menü
taşıyan **uygulama arayüzü**, bir süsleme değil. Kaldıran ayar yok — `GTK_CSD=0`
GTK'dan yıllar önce söküldü. Tek knob `gtk-decoration-layout` (düğmelerin yeri),
çubuğu kaldırmaz. Bir daha denenmesin.

**Kategori 4 — uygulamanın kendi tasarladığı chrome ≠ süsleme.** VSCodium'un
sekme/başlık çubuğu, Vesktop'un başlığı, zen'in sekme şeridi `WaylandWindow-`
`Decorations` ile GİTMEZ; her biri uygulama-içi ayar gerektirir. VSCodium için
o ayar aşağıda.

**Kapsam uyarısı:** `sessionVariables` sistem geneli → **GNOME oturumunu da**
etkiler (orada mutter gerçek başlık çubuğu çizer; normal davranış). İzlenecek
regresyonlar: ibus (`GTK_IM_MODULE=ibus`) Wayland'de text-input-v3'e geçer →
Electron uygulamalarında Türkçe/emoji girişi teyit edilmeli; ekran paylaşımı
xdg-desktop-portal'a düşer. Bozarsa o tek satırı silmek yeter.

## VSCodium minimalist görünüm (30 Tem 2026)

Kullanıcının referans ekran görüntülerinden çıkarılan hedef: activity bar yok,
durum çubuğu yok, sekmeler var, breadcrumb/minimap yok, girinti kılavuzları
duruyor, yuvarlak köşe + soluk kenarlık. İki dosyaya bölünüyor:

**Uygulama tarafı — `modules/apps/vscodium.nix` (`userSettings`).** Yalnız
yerleşim/chrome anahtarları; renk ve font Stylix'in (dosya başındaki kural).
Doğrulandı: üretilen `settings.json`'da Stylix'in font anahtarları + `colorTheme
= "Stylix"` ile bu anahtarlar **çakışmadan** birleşiyor. Anahtar adlarının
hepsi VSCodium 1.126'nın workbench bundle'ında teyit edildi (bazıları editör
çekirdeğinde `editor.` öneksiz kayıtlı — orada ayrıca arandı).

Kritik olan üçlü:
- `workbench.activityBar.location = "hidden"` — sol dikey şerit gider.
  **Bedeli:** panellere yalnız klavyeden (`Ctrl+Shift+E/F/G/X`, `Ctrl+B`).
  Fare erişimi geri istenirse `"top"`, tek satır.
- `window.titleBarStyle = "custom"` + `window.customTitleBarVisibility = "never"`
  — VSCodium kendi başlık çubuğunu çizmez. `"native"` **kullanılmadı**: Wayland'de
  native, menü çubuğunu pencerenin içine ayrı satır olarak koyuyor.
- `window.menuBarVisibility = "toggle"` — menü gizli, `Alt` ile gelir
  (`"hidden"` menüyü klavyeden de erişilemez kılar).

**Compositor tarafı — `lua/rules.lua`, `vscodium-chrome` kuralı.**
- `border_size = 2` — global `border_size` 0 olduğu için (main.lua, 29 Tem
  kararı) elle açılır; global'e dokunulmaz. Yan etkisi: `theme.lua`'nın matugen
  gradient'i (`general.col.active_border`) şimdiye kadar hiçbir yerde
  çizilmiyordu, artık **görünür** → kenarlık duvar kağıdıyla birlikte değişir.
- `opacity = 0.94` — Hyprland'da tek sayı active/inactive/fullscreen'in üçünü
  birlikte set eder, yani odak kaybında global `inactive_opacity`'ye (0.86)
  **sönmez**; kod okurken kritik. Global active (0.92) yerine bir tık opak,
  blur açık kaldığı için buzlu cam hissi korunur. Alan adlarının (`opacity`,
  `border_size`) 0.56'da var olduğu binary'den teyit edildi (`SOpacityRule`).
- Sınıf eşleşmesi `^(vscodium|codium|VSCodium)$` — `codium.desktop`'ta
  `StartupWMClass=vscodium`; NIXOS_OZONE_WL öncesi XWayland `WM_CLASS`, sonrası
  Wayland `app_id` olduğundan üç varyant birlikte kapsandı.

**GNOME'da** yalnız uygulama tarafı geçerli; kenarlık/opaklık compositor işi ve
mutter per-window opacity sunmuyor. **Sway rice'a kural eklenmedi** — istek
Hyprland içindi ve riceler bilinçli olarak kod paylaşmıyor.

**Denenmeyen yol:** VSCodium'un *içinde* gerçek şeffaflık. Stylix'in vscode
teması opak hex üretiyor (`"editor.background":"#181616"` — alpha yok), Electron
penceresi şeffaf oluşturulmadığı için 8 haneli hex masaüstüne değil uygulamanın
kendi opak yüzeyine karışır, ve bunu yapan eklentiler (Custom UI Style, APC)
kurulum dizinindeki `workbench.desktop.main.js`'i yamalıyor — o dosya
`/nix/store`'da, salt-okunur. Tek gerçek kol compositor; yukarıdaki kural o.

## Güç bütçesi (4.28W GERİLEMEZ kuralı)

- `main.lua` → `AQ_DRM_DEVICES=/dev/dri/by-path/pci-0000:65:00.0-card`:
  aquamarine NVIDIA node'unu hiç açmaz. Bu, `gnome.nix`'teki
  `mutter-device-ignore` udev kuralının Hyprland eşleniğidir; açık fd RTD3
  D3cold'u bloke ederdi. by-path çünkü `cardN` numarası boot sırasına göre
  değişiyor (ölçüldü: card0=nvidia, card1=amdgpu). PRIME offload (`gamerun`)
  etkilenmez.
- Tema motoru **olay güdümlü**: yalnız kısayolla tetiklenir, poll yok.
  matugen/swww geçişi anlık maliyet; idle'da hiçbir şey koşmaz.
- Waybar aralıkları: pil 30 sn, RAM 30 sn, saat 60 sn; fan modülü sinyal
  tabanlı (poll yok), ağ modülü waybar varsayılanında (60 sn).
- Cava **barda yok ve autostart edilmez** — sürekli ses örnekler; istenince
  terminalden.
- `misc.vrr = 2` (yalnız tam ekran) — GNOME'daki mutter VRR deneysel
  özelliğinin karşılığı.
- **Yapılacak ölçüm:** Hyprland oturumunda pilde idle W (`current_now ×
  voltage_now / 1e12`, BAT1) + `/sys/bus/pci/devices/0000:64:00.0/power_state`
  ile D3cold teyidi. 4.28W tabanı GNOME'da ölçüldü; burada yeniden doğrulanmalı.

## Kısayollar (GNOME kas hafızasıyla hizalı)

| Kısayol | İş | GNOME eşleniği |
|---|---|---|
| SUPER+Enter | ghostty | aynı |
| SUPER+Q | pencere kapat | aynı |
| SUPER+1..9 (+SHIFT) | çalışma alanı (taşı) | aynı |
| SUPER+M | fan modu döngüsü | aynı |
| SUPER+V | bildirim paneli (swaync) | aynı |
| Copilot (Meta+Shift+F23) | Claude Desktop | aynı |
| **SUPER+T** | **duvar kağıdı seç → tema** | — (referans repo: Super+T/W) |
| **SUPER+SHIFT+T** | **rastgele duvar kağıdı + tema** | — |
| SUPER+D | rofi drun | — |
| SUPER+F / SHIFT+F | yüzer / maximize (16 Tem'de yer değişti) | — |
| SUPER+SHIFT+E | oturumu kapat (GDM) | — |

## Açma / doğrulama

1. `configuration.nix` → `rice.hyprland.enable = true;` satırının yorumunu kaldır
   (HM tarafı gömülü HM'de `osConfig` üzerinden otomatik izler; standalone
   `hms` yolunda gerekirse `home.nix`'e aynı satır yazılır).
2. `nixos-rebuild build --flake /home/zixar/nixos-zixar#nixos` → hatasızsa
   `sudo nixos-rebuild switch --flake /home/zixar/nixos-zixar#nixos`.
3. Çıkış yap → GDM'de dişli menüsünden **Hyprland** seç.
4. İlk giriş: Stylix duvar kağıdı + ondan üretilmiş renklerle açılır
   (aktivasyon tohumu). SUPER+T ile değiştir; `hyprctl reload` sonrası
   kenarlık renklerinin değiştiğini gör.
5. Güç ölçümü (yukarıdaki bölüm) — sonucu bu dosyaya işle.

## Bilinçli eksikler (istemde yoktu)

- Kilit ekranı / idle yönetimi (hyprlock+hypridle) — GNOME oturumu dururken
  öncelik değil; eklenirse matugen'e `hyprlock` şablonu da bağlanmalı.
- Ekran görüntüsü (grim+slurp) — GNOME'da PrintScreen var; Hyprland
  oturumuna eklenecekse `hl.permission` (screencopy) notuna dikkat.
- Tema önizleme küçük resimleri (referans repodaki `thumb-gen.sh`) — rofi
  ikonları orijinal dosyayı okuyor; büyük PNG'lerde seçici ilk açılışta
  yavaşlarsa eklenebilir.
