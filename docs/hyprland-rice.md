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
| vscodium | ✅ (renk) | Hyprland `active_opacity` (native CSS opacity YOK) |
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
