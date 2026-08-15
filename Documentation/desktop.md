# Hyprland masaüstü — Caelestia kabuğu (09 Ağu 2026'dan beri)

Modüller: `home/desktop/`. Bu doküman hem kurulumun **nasıl** çalıştığını hem de
**neden** böyle kurulduğunu anlatır.

**09 Ağu 2026: temiz yıkım.** Elle kurulmuş waybar (16 tema) + rofi (adi1090x
type-5/style-4) + swaync + matugen 8-şablonlu tema motoru + awww + hyprlock/hypridle
rice'ı tek seferde söküldü, yerine **Caelestia** — Quickshell tabanlı, bar+launcher+
bildirim+kilit+idle+runtime tema motorunu tek üründe toplayan bir kabuk — geçti.
Geçiş dönemi seçici yok (`desktop.shell` gibi bir enum eklenmedi); eski rice'ın tasarım
kararları (Waybar 16 tema sistemi, rofi 2.0 gradient tuzağı, matugen zinciri) artık bu
dosyada değil, tamamen ayrı bir tarihsel referans olarak yalnız `rice/caelestia`
dalında (eski repo düzeni, pre-reorg) okunabilir — oradan bu depoya birebir taşınan tek
şey 7 özel Material You şeması (`home/desktop/caelestia/schemes/*.txt`).

Bu geçişin tasarım gerekçesi (Caelestia vs Noctalia karşılaştırması, cache/derleme
maliyeti analizi, dGPU/PPD/idle risk değerlendirmesi) bu oturumun plan dosyasında
detaylı işlendi; burada yalnız **kurulu haliyle nasıl çalıştığı** var.

## Caelestia kabuğu — mimari ve tasarım kararları

### IPC yüzeyi

Kabuğun tamamı `qs -c caelestia ipc call <target> <function> [args]` ile konuşulur;
`caelestia` CLI'ı bunun ince bir sarmalayıcısı (`caelestia shell <target> <function>`).
Kullanılan hedefler (`modules/*.qml`'deki `IpcHandler { target: "..." }` bloklarından
doğrulandı):

| Hedef | Fonksiyonlar | Kullanım |
|---|---|---|
| `drawers` | `toggle(ad)`, `list()`, `isOpen(ad)` | launcher/dashboard/sidebar/session panelleri — `ad` değerleri `ShellState`'in boolean anahtarları (`launcher`, `dashboard`, `sidebar`, `session`, `utilities`, `osd`) |
| `lock` | `lock()`, `unlock()`, `isLocked()` | kilit ekranı |
| `picker` | `open()`, `openFreeze()`, `openClip()`, `openFreezeClip()` | ekran bölgesi seçici (screenshot altyapısı) |
| `wallpaper` | `get()`, `set(yol)`, `list()` | duvar kağıdı |
| `nexus` | `open()` | kontrol merkezi (ayarlar GUI'si) |

CLI'ın kendi üst-seviye komutları (`caelestia screenshot`, `caelestia clipboard`,
`caelestia wallpaper`, `caelestia scheme`) bu IPC'leri veya kendi mantığını (fuzzel+
cliphist, grim+swappy) kullanır — `caelestia shell …` yalnız IPC'yi doğrudan çağırmak
gerektiğinde (ör. launcher toggle) tercih edildi, çünkü global Hyprland kısayolları
(`global, caelestia:*`) upstream'de sık değişiyor ve doğrulaması daha zor.

### Tema motoru — dinamik, olay güdümlü

```
SUPER+T → caelestia wallpaper -r (rastgele duvar kağıdı, ~/Pictures/Wallpapers)
             └→ CLI: dynamic şema üretimi (wallpaper → Material You palet)
                  ├→ ~/.config/hypr/scheme/current.lua  (enableHypr, Lua config algılanır)
                  │    → home/desktop/wm/theme.lua dofile ile okur, hyprctl reload otomatik
                  ├→ ~/.local/state/caelestia/theme/kbd-color (kullanıcı template'i)
                  │    → postHook: kbd-rgb set "$(cat …)"
                  ├→ gtk.css + dconf, qt5ct/qt6ct colors, btop.theme, fuzzel.ini,
                  │    vesktop CSS'i, terminal OSC dizileri (enableGtk/Qt/Btop/Fuzzel/
                  │    Discord/Term — hepsi home/desktop/caelestia/default.nix'te açık)
                  └→ shell.json'daki bar/launcher/dashboard kendi Quickshell renklerini
                       aynı anda günceller (aynı süreç içi, ayrı hook gerekmez)
```

- **Neden `dynamic` (matugen'in doğrudan devamı)?** Eski zincirin SUPER+T davranışına
  (duvar kağıdından anlık Material You üretimi) en yakın karşılık. Görsel grid seçici
  (eski `rofi wallpaper-grid.rasi`) yok — launcher'ı (SUPER+SPACE) `>wallpaper <ad>`
  action prefix'iyle açmak en yakın interaktif eşdeğer.
- **Özel şemalar paket-yaması ile geliyor.** `caelestia scheme set -n <ad>` yalnız
  `caelestia-cli` paketinin kendi şema dizinini tarıyor (`utils/paths.py`:
  `cli_data_dir = __file__/../../data`, yani kurulu `site-packages/caelestia/data/schemes`)
  — kullanıcı seviyesinde şema dizini upstream'de yok. 7 özel şema (`schemes/*.txt`,
  eski matugen/Caelestia şemalarından **birebir**, base16'ya çevrilmeden) bir
  `overrideAttrs.postInstall` ile o dizine, `<ad>/main/dark.txt` düzeninde enjekte
  ediliyor (`home/desktop/caelestia/default.nix`). Launcher'ın `>scheme` seçicisi de
  aynı yerden besleniyor — kendi listesi yok, `caelestia scheme list` çağırıyor
  (`modules/launcher/services/Schemes.qml`), yani cli düzelince ikisi birden düzelir.

- **`postPatch` bu pakette ÖLÜDÜR — 7 şema 9 Ağu'dan 15 Ağu 2026'ya kadar pakete hiç
  girmedi.** Enjeksiyon kurulduğu günden beri `overrideAttrs.postPatch` ile yazılıydı ve
  **tek bir kez bile çalışmadı**; hata vermedi, build yeşil geçti. Sebep: upstream kendi
  `default.nix`'inde `patchPhase`'i düz string olarak tanımlıyor ve içinde `runHook`
  çağırmıyor; stdenv fazı `eval "${!curPhase:-$curPhase}"` ile çağırdığı için
  (`stdenv-linux/setup`, "Evaluate the variable named $curPhase if it exists, otherwise
  the function named $curPhase") attribute varsa varsayılan faz fonksiyonu hiç koşmaz —
  ve `prePatch`/`postPatch` o fonksiyonun içindeki hook'lar olduğundan ikisi de ölür.
  Store kanıtı: derlenmiş cli'ın `data/schemes/` dizininde yalnız 14 stok şema vardı
  (`caelestia catppuccin darkgreen dracula everblush everforest gruvbox nord oldworld
  onedark rosepine shadotheme solarized tokyonight`), 7 özelin hiçbiri yoktu — ve bu
  **en az iki `flake.lock` kuşağı** boyunca sürdü (store'daki iki ayrı cli çıktısı,
  `hqdqxj24…` ve `m135aavl…`, aynı eksiği gösteriyordu).
  Aynı build'deki asimetri teşhisi kesinleştirdi: upstream'in kendi `postInstall`'ı
  (`installShellCompletion`) ÇALIŞMIŞTI — `$out/share/fish/vendor_completions.d/caelestia.fish`
  yerindeydi. Yani ölü olan "hook mekanizması" değil, yalnız o **faz**tı. Install fazını
  pypa-install-hook sağlıyor ve `runHook postInstall` çağırıyor; düzeltme bu yüzden
  `postInstall`'a taşındı.

- **Enjeksiyonun bir doğrulama adımı var, ve kasten farklı bir fazda duruyor.**
  Kopyalama `postInstall`, doğrulama `postFixup`: 7 şemanın her biri için kurulu
  `$out`'ta `<ad>/main/dark.txt` aranır, biri eksikse build **sesli** düşer (hangi şema
  ve hangi dizine bakıldığı yazılır). Amaç aynı sınıftan üçüncü bir sessiz kırılmayı
  engellemek — tek bir upstream değişikliğinin (bir fazın string olarak tanımlanması)
  hem kopyayı hem doğrulamayı birden düşürmesi gerekir ki hata yine sessiz kalsın.
  `flavour` adı `main`: kozmetik bir seçim (stok şemalar `mocha`/`medium` gibi anlamlı
  adlar kullanıyor), kullanıcıyı ilgilendirmez — `scheme.py`'nin `_check_flavour`/
  `_check_mode` metotları listenin ilkine düştüğü için `caelestia scheme set -n <ad>`
  yeterlidir. Bu şemaların `light` modu yoktur; `-m light` sessizce `dark`'a düşer.
- **Klavye RGB senkronu korundu, dönüşümsüz.** Eski matugen sözleşmesi
  (`kbd-rgb set "<çıplak hex>"`) ile Caelestia kullanıcı template'lerinin çıktı formatı
  (`{{ primary.hex }}` → çıplak hex, `#` yok) birebir uyuşuyor — `templates/kbd-color`
  tek satır, dönüştürme kodu gerekmedi.
- **Terminal renk zinciri artık OSC değil, Caelestia'nın kendi `enableTerm`
  mekanizması** — aynı fikir (canlı terminal renklendirme), farklı uygulayıcı.

### dGPU güvenliği — iki katman gerekiyor

`AQ_DRM_DEVICES=/dev/dri/hypr-igpu` (`system/desktop/session.nix`) yalnız **compositor**
Aquamarine'i AMD iGPU'ya kilitler — Quickshell'in kendi Qt/EGL süreci bundan
etkilenmez ve NVIDIA node'unu açıp dGPU'yu D3cold'dan uyandırabilir. İkinci katman
`home/desktop/caelestia/default.nix`'te:

```nix
programs.caelestia.systemd.environment = [
  "__GLX_VENDOR_LIBRARY_NAME=mesa"
  "__EGL_VENDOR_LIBRARY_FILENAMES=/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json"
];
```

Ayrıca dashboard'un GPU kartı **kapalı** tutuluyor iki bağımsız anahtarla:
`services.gpuType = "None"` (probe hiç çalışmaz) + `dashboard.performance.showGpu =
false` (ikinci savunma hattı). Gerekçe: kartın `Gpu` servisi açıkken `nvidia-smi`'yi
her tick'te (varsayılan 1000 ms) bir kez fork ediyor — kalıcı süreç değil ama saniyede
bir fork + dGPU uyandırması, 4.28 W bütçesi için kabul edilemez.

### Idle/kilit sahipliği — tek yazar, logind'e devredilen uyku kararı

Caelestia kendi idle yönetimini (`ext-idle-notify-v1`) ve kilidini (`WlSessionLock` +
`PamContext`) sağlıyor — hypridle ve hyprlock **tamamen söküldü**, ikisinin de HM/sistem
tarafındaki tanımları (`programs.hyprlock`, `services.hypridle`,
`security.pam.services.hyprlock`) gitti. `general.idle.timeouts` yalnız `lock` (300 sn)
ve `dpms off/on` (480 sn) tanımlıyor — **suspend/hibernate action'ı YOK**, uyku kararı
tamamen `system/kernel/power.nix`'teki logind zincirine (`suspend-then-hibernate`,
25 dk `HibernateDelaySec`) bırakıldı. Bu kasıtlı: Caelestia'nın oturum menüsü zaten
`systemctl`/`loginctl` çağrılarını logind D-Bus'a alias'lıyor ve `hibernate` komutu
`SessionManager.suspendThenHibernate`'e eşleniyor (`CanHibernate` ön kontrolüyle,
kullanılamazsa düz suspend'e düşüyor) — s2h zincirini bozan bir "düz suspend" çağrısı
menüde hiç yok, ek bir koruma gerekmedi.

### PPD sahipliği — bar'ın `power` girdisi kapalı

`system/kernel/power-display.nix` zaten üç root-taraflı PPD yazarına sahip
(`power-display.service`, `game-perf.service`, ACAD udev tetiklemesi) ve bunlardan
biri set→doğrula→zorla döngüsü çalıştırıyor (PPD 0.30'un no-op bug'ı için). Bar'ın
`power` girdisi (D-Bus üzerinden PPD'ye yazabilen bir seçici) dördüncü, senkronize
olmayan bir yazar olurdu — `bar.entries`'te `enabled = false` ile kapatıldı, tek otorite
`power-display.service` kaldı.

### Bar'ın sınırı — özel modül yok

`bar.entries` tam olarak 8 sabit kimlik kabul ediyor
(`logo/workspaces/spacer/activeWindow/tray/clock/statusIcons/power`) —
`custom`/`exec` tipi yok, plugin sistemi (`caelestia-dots/plugins`) boş repo. Eski
waybar'ın `custom/fan` modülünün (fan_mode göstergesi) doğrudan karşılığı **yok**.
Kabul edilen ödün: `fan-mode-cycle.service` zaten attığı `notify-send` toast'ı
(`system/arch/aerox16/wmi.nix`) tek gösterge — kalıcı bir göz-ucu okuması kayboldu,
SUPER+M sonrası bildirim kalıyor.

## Lua config nasıl HM'ye entegre edildi

`wayland.windowManager.hyprland` şunlarla:

- `configType = "lua"` → HM `~/.config/hypr/hyprland.lua` üretir.
- `extraLuaFiles = { main, theme, binds, rules }` → her biri `hypr/<ad>.lua` olarak
  yazılır ve `hyprland.lua` bunları otomatik `require` eder (alfabetik sıra: binds,
  main, rules, theme — theme son koştuğu için renkte son söz onun). `autostart.lua`
  09 Ağu'da kaldırıldı — yalnız artık gereksiz bir `theme-apply --restore` çağrısı
  taşıyordu; Caelestia son şemayı `~/.local/state/caelestia/` altında kalıcı tutuyor,
  reboot sonrası ayrı bir restore adımına gerek yok.
- `package = null; portalPackage = null` → paket **sistemden**
  (`programs.hyprland.enable`, system.nix) gelir; çifte kurulum/portal
  çakışması olmaz.

**Kritik incelik — `theme.lua` renkleri `require` ile değil `dofile` ile okur** (aynı
neden, artık farklı kaynak dosya): Caelestia'nın `enableHypr` çıktısı, Hyprland'in
Lua config kullandığını (`hyprctl status` üzerinden `configProvider == "lua"`) tespit
edip `~/.config/hypr/scheme/current.lua`'ya **düz, alpha'sız bir tablo** yazıyor
(`return { primary = "3fa9a0", ... }`) — eski matugen'in `active_border`/`shadow`'u
önceden hesaplayıp yazdığı `colors.lua`'dan farklı, alpha'yı (`rgba(...ee)`, gölge için
`0xee...`) artık `theme.lua`'nın kendisi Lua'da hesaplıyor. `require` önbelleğe alırdı
(`package.loaded`), `hyprctl reload` sonrası eski renkler dönerdi; `dofile` her
çalışmada diskten taze okur.

## Servis kapsamlama + Stylix çakışması

- `caelestia.service` (HM `systemd.user.services.caelestia`, Caelestia'nın kendi HM
  modülü tarafından üretilir) `hyprland-session.target`'a bağlı —
  `graphical-session.target`'a değil. Aynı gerekçe hep geçerli: generic target
  Hyprland dışında bir bağlamda da (ör. bir TTY oturumu) tetiklenebilirdi.
  `programs.caelestia.systemd.target = "hyprland-session.target"` bunu açıkça set eder
  (modülün kendi varsayılanı `config.wayland.systemd.target` — HM'de genelde
  `graphical-session.target` — bu yüzden elle üzerine yazmak GEREKİYOR).
- **Stylix çakışması:** Stylix bu repoda renklerin tek kaynağı; ama Caelestia CLI'ın
  `enable*` ile yazdığı yüzeylerde renk sahibi Caelestia olmalı. Bu yüzden
  `stylix.targets.{hyprland,gtk,qt,btop,fuzzel,ghostty}.enable = false` — vscodium,
  vesktop, starship gibi Caelestia'nın dokunmadığı hedefler Stylix'te kalır. İki sistem
  yan yana: Stylix "statik taban" (font/imleç/build-time), Caelestia "dinamik rice
  katmanı".

## Animasyon + görünüm (Anto98765/My-Hyprland-Rice portu)

`main.lua`'nın LOOK AND FEEL + ANIMATIONS bölümleri aynı repodan porte edildi
(`.config/hypr/modules/{animations,look_and_feel}.conf`): pencereler slide ile
açılır / popin 80% ile kapanır, fareyle sürükleme `windowsMove` ile animasyonlu,
workspace geçişi slide, layer'lar (Caelestia bar/launcher dahil) animasyonlu;
gaps 7/10, border 1px, rounding 12 (power 4), gölge range 15, blur size 2 × 2 pass +
contrast 1.6 + popups. Bilinçli sapmalar (main.lua yorumlarında):

- **`borderangle loop` ATLANDI** — gradyan kenarlığı sürekli döndürmek idle'da
  bile her karede repaint demek; 4.28W bütçesini doğrudan ihlal ederdi.
- Süreler kaynaktan ~%25 kısa (kullanıcı: "biraz daha hızlı") — kaynak değerler
  main.lua satır-sonu yorumlarında.
- İmleç: apple-cursor **macOS-White** (stylix-base.nix cursor.name).
- Saydamlık kaynakta 1/1 (opak); bizde 0.92/0.86 korunur (Stylix senkron kararı).
- `resize_on_border=true` ve `allow_tearing=false` bizde kaldı (alışkanlık/VRR).

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
`home/apps/zen.nix` içinde yorumlu — kullanıcı onayı + switch sonrası
doğrulama gerektiren bilinçli adım. Saydamlık zaten Hyprland'den geliyor;
ertelenen yalnız zen'in *renk* teması.

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
diye bir kaçış var, ama Hyprland zaten SERVER_SIDE dediği için Qt uyuyor. **Not:
Caelestia (Qt/QML) buna dahil** — kendi pencere süslemesini çizmiyor, aynı
protokol yeterli. **Ayarlanmadı**, gerek yok.

**Kategori 3 — GTK/libadwaita: MÜMKÜN DEĞİL, üstelik istenmez.** Nautilus vb.
uygulamaların üst çubuğu bir `GtkHeaderBar`: içinde yol çubuğu, arama ve menü
taşıyan **uygulama arayüzü**, bir süsleme değil. Kaldıran ayar yok — `GTK_CSD=0`
GTK'dan yıllar önce söküldü. Tek knob `gtk-decoration-layout` (düğmelerin yeri),
çubuğu kaldırmaz. Bir daha denenmesin.

**Kategori 4 — uygulamanın kendi tasarladığı chrome ≠ süsleme.** VSCodium'un
sekme/başlık çubuğu, Vesktop'un başlığı, zen'in sekme şeridi `WaylandWindow-`
`Decorations` ile GİTMEZ; her biri uygulama-içi ayar gerektirir. VSCodium için
o ayar aşağıda.

**Kapsam uyarısı:** `sessionVariables` sistem geneli. İzlenecek regresyonlar:
ibus (`GTK_IM_MODULE=ibus`) Wayland'de text-input-v3'e geçer → Electron
uygulamalarında Türkçe/emoji girişi teyit edilmeli; ekran paylaşımı
xdg-desktop-portal'a düşer. Bozarsa o tek satırı silmek yeter.

## VSCodium minimalist görünüm (30 Tem 2026)

Kullanıcının referans ekran görüntülerinden çıkarılan hedef: activity bar yok,
durum çubuğu yok, sekmeler var, breadcrumb/minimap yok, girinti kılavuzları
duruyor, yuvarlak köşe + soluk kenarlık. İki dosyaya bölünüyor:

**Uygulama tarafı — `home/apps/vscodium.nix` (`userSettings`).** Yalnız
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
  kararı) elle açılır; global'e dokunulmaz. Yan etkisi: `theme.lua`'nın renkli
  kenarlığı (`general.col.active_border`, artık Caelestia'nın `scheme/current.lua`
  çıktısından besleniyor) şimdiye kadar hiçbir yerde çizilmiyordu, artık
  **görünür** → kenarlık duvar kağıdıyla birlikte değişir.
- `opacity = 0.94` — Hyprland'da tek sayı active/inactive/fullscreen'in üçünü
  birlikte set eder, yani odak kaybında global `inactive_opacity`'ye (0.86)
  **sönmez**; kod okurken kritik. Global active (0.92) yerine bir tık opak,
  blur açık kaldığı için buzlu cam hissi korunur. Alan adlarının (`opacity`,
  `border_size`) 0.56'da var olduğu binary'den teyit edildi (`SOpacityRule`).
- Sınıf eşleşmesi `^(vscodium|codium|VSCodium)$` — `codium.desktop`'ta
  `StartupWMClass=vscodium`; NIXOS_OZONE_WL öncesi XWayland `WM_CLASS`, sonrası
  Wayland `app_id` olduğundan üç varyant birlikte kapsandı.

**Denenmeyen yol:** VSCodium'un *içinde* gerçek şeffaflık. Stylix'in vscode
teması opak hex üretiyor (`"editor.background":"#181616"` — alpha yok), Electron
penceresi şeffaf oluşturulmadığı için 8 haneli hex masaüstüne değil uygulamanın
kendi opak yüzeyine karışır, ve bunu yapan eklentiler (Custom UI Style, APC)
kurulum dizinindeki `workbench.desktop.main.js`'i yamalıyor — o dosya
`/nix/store`'da, salt-okunur. Tek gerçek kol compositor; yukarıdaki kural o.

## Güç bütçesi (4.28W GERİLEMEZ kuralı)

- `system.nix` → `AQ_DRM_DEVICES=/dev/dri/hypr-igpu` (compositor katmanı) +
  Caelestia'nın kendi `__GLX_VENDOR_LIBRARY_NAME`/`__EGL_VENDOR_LIBRARY_FILENAMES`
  env'leri (Qt/QML istemci katmanı) — iki katman birlikte NVIDIA node'unu kapalı
  tutar, yalnız biri yeterli değil (bkz. yukarıdaki "dGPU güvenliği" bölümü).
- `services.gpuType = "None"` + `dashboard.performance.showGpu = false` —
  `nvidia-smi`'nin saniyede bir fork edip dGPU'yu uyandırmasını kökten kesiyor.
- `background.visualiser.enabled = false` (varsayılan zaten böyle, açıkça pekiştirildi)
  — sürekli PipeWire ses yakalaması dashboard kapalıyken hiç çalışmaz.
- `dashboard.showWeather = false` + `services.weatherLocation = ""` — periyodik
  ağ isteği (wttr.in/ipinfo.io) yok.
- Kaynak/medya monitörleri (`TickingService`) yalnız ilgili panel görünürken tick
  atıyor — dashboard kapalıyken idle CPU maliyeti ~0 bekleniyor (upstream kaynak
  kodu bu davranışı doğruluyor, ölçülmedi henüz).
- Tema motoru **olay güdümlü**: yalnız kısayolla/launcher'dan tetiklenir, poll yok.
- `misc.vrr = 2` (yalnız tam ekran) — panel 48-165Hz aralığında değişken tazeleme.
- **Yapılacak ölçüm (switch sonrası, kullanıcıda):** pilde idle W
  (`current_now × voltage_now / 1e12`, BAT1) + `cat /sys/bus/pci/devices/0000:64:00.0/
  power_state` ile D3cold teyidi + `pgrep nvidia-smi` (boş dönmeli) +
  `systemd-cgtop` ile `caelestia.service` CPU/RSS. 4.28W tabanı 2026-07-02'de GNOME
  birincil oturumken ölçülmüştü; GNOME kaldırıldıktan (30 Tem) ve şimdi Caelestia'ya
  geçildikten sonra yeniden doğrulanmalı.

## Kısayollar

Eskiden GNOME'un dconf kısayollarıyla bire bir eşleşecek şekilde seçilenler
(kas hafızası korunuyor) + Caelestia'ya özgü olanlar (09 Ağu'da yeniden atandı):

| Kısayol | İş |
|---|---|
| SUPER+Enter | ghostty |
| SUPER+Q | pencere kapat |
| SUPER+1..9 (+SHIFT) | çalışma alanı (taşı) |
| SUPER+M | fan modu döngüsü (bildirim toast'ı — kalıcı gösterge yok) |
| **SUPER+SPACE** | **uygulama başlatıcı (Caelestia launcher)** — eskiden SUPER+D'deydi |
| **SUPER+D** | **dashboard (performans/medya paneli)** — eskiden bu tuş launcher'dı |
| SUPER+SHIFT+N | bildirim/hızlı-ayarlar paneli (sidebar) |
| SUPER+V | pano geçmişi (`caelestia clipboard`) — eskiden bildirim paneliydi |
| SUPER+L | kilit ekranı (`caelestia shell lock lock`, Caelestia'nın kendi kilidi) |
| Copilot (Meta+Shift+F23) | Claude Desktop |
| **SUPER+T** | **rastgele duvar kağıdı + tema** (`caelestia wallpaper -r`) |
| SUPER+F / SHIFT+F | yüzer / maximize (16 Tem'de yer değişti) |
| Print | bölge seç (dondurulmuş ekran) + swappy ile düzenle |
| SHIFT+Print | tam ekran görüntü |
| SUPER+SHIFT+S | bölge → doğrudan panoya (`picker openClip` IPC'si) |
| SUPER+SHIFT+E | oturumu kapat (ly'ye döner) |

Kaldırılanlar: SUPER+SHIFT+T (rastgele tema — SUPER+T'yle tekilleşti), SUPER+W
(waybar tema seçici — waybar'ın kendisi gitti).

## Açma / doğrulama

1. `configuration.nix` → `desktop.hyprland.enable = true;` (tek oturum kalınca
   her zaman açık; kapatmak sistemi çalışan oturumsuz bırakır).
2. `nixos-rebuild build --flake /home/zixar/nixos-zixar#nixos` → hatasızsa
   **`switch` DEĞİL, `nh os boot`** (= `nixos-rebuild boot`). **Cache yok** —
   quickshell + Qt6 kaynaktan derlenir, ilk build uzun sürer.
   **Neden `switch` değil:** canlı oturumda hyprlock'un PAM'ı + eski rice'ın
   servisleri (swaync vb.) sökülürken Hyprland bellekte hâlâ eski Lua config'i
   tutuyor olur — hem riskli hem "gerçek" boot yolunu temsil etmez. `boot`
   mevcut oturuma dokunmadan yalnız bootloader varsayılanını değiştirir; yeni
   jenerasyon tümüyle bozuksa (Hyprland/Caelestia hiç açılmasa bile) bootloader
   menüsünden önceki jenerasyona dönülebilir — ikinci TTY'den daha güçlü bir
   kurtarma ağı, çünkü yeni oturumun kısmen çalışıyor olmasına bağımlı değil.
3. `reboot` → ly → **Hyprland (uwsm-managed)** seç (`defaultSession` zaten
   bunu işaret ediyor). ly/UWSM/Hyprland/Caelestia hepsi temiz başlar.
4. **Kilit testi ÖNCE** — ikinci bir TTY açık tut (`Ctrl+Alt+F2`),
   `caelestia shell lock lock` ile kilitle/aç. Bu, `boot`+reboot ile de
   ATLANMAZ: `security.pam.services.hyprlock` sökülmüşken PAM bozuksa kilit
   ekranında sıkışılır — TTY'den `systemctl --user stop caelestia` kurtarır
   (ext-session-lock protokolü, kilitleyen istemci ölünce compositor'ı
   otomatik kilit açmaya zorlar); o da olmazsa donanım reset + bootloader'dan
   önceki jenerasyon.
5. İlk giriş: `caelestia scheme set -n dynamic` (ExecStartPre guard'ı bunu bir kez
   otomatik yapar) — SUPER+T ile değiştir, kenarlık renginin değiştiğini gör.
6. Güç ölçümü + dGPU/PPD doğrulaması (yukarıdaki bölüm) — sonucu bu dosyaya işle.

## Ekran görüntüsü, kilit ve idle

Hepsi artık Caelestia'nın kendi altyapısı — hiçbiri ayrı HM modülü/servis değil:

- **Ekran görüntüsü** — `caelestia screenshot` (CLI, grim+swappy) ve
  `caelestia shell picker *` (IPC, bölge seçici) — bkz. Kısayollar tablosu.
- **Kilit ekranı** — Caelestia'nın kendi `WlSessionLock` + `PamContext`'i,
  standart `passwd` PAM zincirini kullanıyor. `security.pam.services.hyprlock`
  09 Ağu'da sökülmüştü (sistem/desktop/session.nix) — ek bir PAM servis adı
  tanımlamaya gerek yok.
- **Idle** — Caelestia'nın kendi `ext-idle-notify-v1` yöneticisi: 5 dk boşta
  `lock`, 8 dk boşta `dpms off/on`. **Suspend/hibernate action'ı YOK** — uyku
  kararı logind'e bırakıldı (`system/kernel/power.nix`, s2h zinciri,
  `HibernateDelaySec=25min`). Caelestia'nın oturum menüsü `hibernate` komutunu
  zaten `SessionManager.suspendThenHibernate`'e eşliyor, ek koruma gerekmedi.
- **AC/BAT refresh-rate** — `power-display.nix`'in kullanıcı servisi
  `hyprctl keyword monitor` kullanıyor (60Hz pilde, 165Hz fişte); mod stringi
  `lua/main.lua`'daki `hl.monitor` ile elle senkron tutulmalı.

## Bilinçli eksikler

- Fan modu göstergesi kalıcı değil (bkz. yukarıdaki "Bar'ın sınırı" bölümü) —
  yalnız SUPER+M sonrası bildirim toast'ı.
- Tema önizleme küçük resimleri — Caelestia'nın kendi launcher'ı bunu zaten
  sağlıyor (`>wallpaper` action'ı), ek iş gerekmedi.

## Serpantinum deneme oturumu

`system/desktop/serpantinum.nix` + `home/desktop/serpantinum/default.nix`,
github.com/ilyamiro/serpantinum'u (Quickshell/Hyprland rice, yazarın kişisel dotfiles'ı —
`flake.nix` YOK, yazarın kendi makinesinde `mkOutOfStoreSymlink "/etc/nixos/…"` + `rsync`
ile store dışında çalışıyor) commit `5d4451f7ab55ddaced9ba350b6dba5dd2932aeb1`'e pinleyip
ly'de **karantinalı üçüncü bir oturum** olarak kurar. Caelestia
(`defaultSession = "hyprland-uwsm"`) tek satır etkilenmez.

### Neden karantina

Aynı ağaçta iki Quickshell kabuğu, aynı Wayland yüzeylerini istiyor: layer-shell
(bar/panel), `ext-session-lock-v1` (kilit ekranı), bildirim D-Bus adı. İkisi de koşulsuz
çalışsa üçü için de çakışırlardı. Bu yüzden serpantinum'un HM tarafı **hiçbir global HM
seçeneğine dokunmuyor** — hangi oturum aktifse aktif olsun sızacak her şey ya patch'lenip
silindi ya da hiç eklenmedi (tam liste ve gerekçe: `home/desktop/CLAUDE.md`'nin
"Serpantinum — karantinalı ikinci oturum" bölümündeki tablo). Yalnız oturuma özel
dosyalar (`~/.config/hypr/serpantinum.conf`, `~/.config/hypr/scripts`,
`~/.config/matugen/*`) ve oturum sarmalayıcısının (`serpantinum-session`) kendi ortamı
karantinalı.

### Ne adapte edildi

| Değişiklik | Neden |
|---|---|
| `hyprpolkitagent` autostart | Üstakımın kendi polkit satırı eksik/kırıktı — polkit ajanı olmadan parola isteyen işlemler (örn. NetworkManager) sessizce başarısız olur. |
| Fan-mode-cycle keybind | Üstakımda hiç yoktu — Caelestia oturumundaki SUPER+M dengi burada eksikti. |
| Klavye RGB parlaklık keybind | Aynı sebep — üstakımda yoktu, bu makinenin donanımına özgü eklendi. |
| EGL/vendor-library pinleri (`__GLX_VENDOR_LIBRARY_NAME`/`__EGL_VENDOR_LIBRARY_FILENAMES`) | Caelestia'nın dGPU-güvenliği katmanıyla aynı kaygı (yukarıdaki "dGPU güvenliği" bölümü) — pin olmadan Qt/QML istemcisi NVIDIA node'unu açıp dGPU'yu D3cold'dan çıkarabilir. |
| swww→awww yeniden adlandırması | Üstakımın duvar kağıdı daemon çağrı hedefi üstakımda ad değiştirmiş; ilgisiz bir upstream driftti, düzeltilmeden oturum hiç açılmazdı. |
| Uygulama menüsü dizin listesi (15 Ağu) | `app_fetcher.py` `XDG_DATA_DIRS`'i okumuyor, dizinleri elle sabitlemiş — HM'in `home.packages`'ının indiği `/etc/profiles/per-user/zixar/share/applications` listede yoktu, 16 uygulama menüde hiç görünmüyordu. |
| Tarayıcı bind'i `zen` → `zen-beta` (15 Ağu) | İkilinin gerçek adı `zen-beta`; `exec, zen` sessizce hiçbir şey yapmıyordu. |
| `WALLPAPER_DIR` = üstakımın kendi duvar kağıdı deposu (15 Ağu) | Seçicinin varsayılan kaynağı Caelestia'nın dizini olurdu; ayrıca `-maxdepth 1` taradığı için alt klasöre konan koleksiyon hiç görünmüyordu. |

#### Kısayol farkları (Caelestia oturumuna göre)

Üstakımın kendi bind'leriyle çakışmayan boş tuşlara kondu — Caelestia'daki karşılıkları
farklı:

| İş | Serpantinum | Caelestia | Neden farklı |
|---|---|---|---|
| Fan modu döngüsü | **SUPER+ALT+M** | SUPER+M | Üstakımda SUPER+M monitör panelinde dolu |
| Klavye RGB −/+ | **SUPER+ALT+C / SUPER+ALT+V** | (aynı iş, `binds.lua`) | — |
| Pencere kapat | **SUPER+A** | SUPER+Q | Üstakımda SUPER+Q müzik popup'ında dolu; A, Q'nun bir sıra altı aynı sütun |
| Tarayıcı | **SUPER+F** (`zen-beta`) | launcher üzerinden | Üstakımın kendi bind'i, hedefi düzeltildi |
| Duvar kağıdı seçici | **SUPER+W** | SUPER+T (şema zinciri) | Ayrı motorlar |

#### Duvar kağıdı kaynağı

Seçicinin taradığı dizin tek bir env değişkeniyle belirleniyor: `WALLPAPER_DIR`
(oturum sarmalayıcısında). Bunu hem `qs_manager.sh` (`SRC_DIR`) hem
`WallpaperPicker.qml` (`Quickshell.env`) okuyor — **ikinci bir ayar noktası yok**.
Değer, üstakımın kendi duvar kağıdı deposu `github.com/ilyamiro/shell-wallpapers`
(319 görsel, ~429 MB, `lib/serpantinum-wallpapers.nix`'te commit'e pinli). İlk açılış
görseli o depodaki `desert-doom-sand-dunes-…jpg` — `lib/wallpapers/obsidian-dunes.jpg`
ile bayt bayt aynı dosya (zaten oradan alınıp yeniden adlandırılmıştı), yani görsel
kimlik değişmedi, yalnız bağımlılık yönü düzeldi: oturum artık Caelestia'nın
`~/Pictures/Wallpapers` dizinine dayanmıyor.

Kritik ayrıntı: seçici `find … -maxdepth 1` kullanıyor. Koleksiyonu duvar kağıdı
dizininin **alt klasörüne** koymak bu yüzden hiçbir zaman işe yaramaz — 13-15 Ağu
arasında "wallpaper'ların çoğu hâlâ yok" şikâyetinin kök nedeni buydu.

### Ne YAPILMADI

- **Watcher katmanı idle-optimizasyonu YOK.** TopBar boşta ~8 `inotifywait` sakini, 5
  fetch↔wait ping-pong'u (`battery_wait.sh`'te `timeout 10`), MPRIS yokken 2 sn'de bir
  `dbus-monitor` respawn'ı, saniyede bir saat repaint'i taşıyor — hiçbiri yeniden
  yazılmadı. Bilinçli kullanıcı kararı: maliyet gerçek ama yalnız bu oturum
  SEÇİLİYKEN ödeniyor; kök `CLAUDE.md`'deki "4.28W GERİLEMEZ" kuralı yalnız her iki
  oturumun paylaştığı `system/kernel/{sched,power,cores}.nix`'i bağlıyor, buraya
  sızmıyor — açık istisna, aynı satır kök `CLAUDE.md`'de de var.
- **`qt6.qtwebengine` `QML2_IMPORT_PATH`'e bilinçli EKLENMEDİ**
  (`system/desktop/serpantinum.nix`) — ~1-2 GiB closure büyümesi, yalnız
  movie/DDG-arama widget'ları kullanıyor. Yamalı ağaçtaki 30 QML dosyasının hiçbiri
  şu an `QtWebEngine` import etmiyor, yani dışlama şu anda hiçbir şeyi kırmıyor;
  ekranda "Type unavailable" hatası görülürse oraya eklenir.

### v2.0 değerlendirme kriterleri

Üstakım 8 Ağu 2026'da "v2.0 ile bunu yeni bir kabuğa dönüştürüyorum, ay sonundan önce"
duyurdu (son gerçek config commit'i 15 May 2026) — bu yüzden emek pinlenip denendi,
üstakıma yatırılmadı (upstream `follow` edilmedi). v2.0 yayınlandığında güncellemeden
önce sırayla sorulacaklar:

1. **Yamaların kaçı üstakımın kendi hatasıydı, kaçı bu makineye özgü?**
   ~20 `postPatch` sed'inin bir kısmı üstakım hatasını düzeltiyor (örn. matugen
   `--prefer=` eksikliği, kayıp `settings_watcher.sh`, swww→awww) — v2.0 bunları
   çözmüşse kapanır. Geri kalanı bu makineye özgü (NixOS profil yolları, panel
   çözünürlüğü, Hyprland 0.56 kural sözdizimi, weather.env yönlendirmesi) ve
   `flake.nix` gelse de KALIR. Not: üstakımın kendi `mkOutOfStoreSymlink`+`rsync`
   köprüsü onun kendi makinesine özgü bir mekanizma — bu repo zaten kullanmıyor
   (`fetchFromGitHub`+`applyPatches`), o yüzden `flake.nix` gelmesi burada
   kaldırılacak bir köprü bırakmaz, yalnızca commit pinlemeyi flake input'a
   çevirebilir.
2. **Watcher katmanı systemd user service mi, yoksa hâlâ Hyprland `exec-once` mu?**
   `exec-once` demek servis yönetimi/yeniden başlatma/loglama yok demek — systemd'ye
   geçmişse bu repodaki diğer HM servisleriyle (caelestia.service gibi) aynı desene
   oturtulabilir.
3. **Watcher katmanı idle'da ne yapıyor?** inotifywait sakin sayısı, ping-pong sayısı,
   dbus-monitor respawn periyodu — v2.0 bunları event-driven'a çevirdiyse yukarıdaki
   "Ne YAPILMADI" maddesi kapanır ve idle optimizasyonu adapte etmeye değer hale gelir.
4. **matugen zorunlu mu, yoksa Stylix ile entegre edilebilir mi?** Zorunluysa Caelestia
   ile aynı "Stylix per-app renk AYARLAMASI" çelişkisi burada da doğar (kök
   `CLAUDE.md`); entegre edilebilirse serpantinum da Stylix'in tek-kaynak kuralına
   girebilir.
5. **NixOS paketleme uyarısı kalktı mı?** Üstakımın NixOS için resmi bir paketleme
   yolu/desteği yoksa (şu an yok — bu yüzden fetchFromGitHub + elle patch) v2.0'da bu
   değişmiş mi, kontrol et.

Bu beş soru olumlu yanıtlanmadan pin'i "kör" `flake update`/versiyon atlamasıyla
taşıma — her biri ayrı bir emek/risk kalemi.
