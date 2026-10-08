# Masaüstü — GNOME (varsayılan) + COSMIC + Hyprland

*Durum: 29 Eyl 2026'dan beri GNOME varsayılan (`defaultSession = "gnome"`,
`configuration.nix`), COSMIC ikinci oturum; giriş ekranı GDM (`system/desktop/login.nix`,
öncesi COSMIC greeter). COSMIC 11–29 Eyl 2026 arası varsayılandı. Hyprland 3 Eki 2026'da
sıfırdan üçüncü oturum olarak girdi (aşağıda "Hyprland").*

Modüller: `system/desktop/` — `cosmic.nix`, `gnome.nix`, `login.nix`, `theme.nix`,
`mux.nix`, `external-display.nix`, `hyprland.nix` (+ HM: `home/desktop/hyprland/`).
Bu defter **neden** böyle kurulduğunu anlatır.

**Önceki dönemler arşivde** (donmuş, yollar kasıtlı eski): Hyprland + Caelestia +
Serpantinum (2 Tem – Eyl 2026) → `Documentation/archive/desktop-hyprland-caelestia.md`;
KDE Plasma ikinci oturum (24 Ağu – 16 Eyl 2026) → `Documentation/archive/desktop-plasma.md`.

---

## Greeter'daki oturumlar

Girdi listesi — `sessionData.desktops` store yolundan okundu (16 Eyl 2026):

| Girdi | Kaynak | Not |
|---|---|---|
| `gnome.desktop` | upstream gnome-session | Wayland, **varsayılan** (29 Eyl 2026'dan beri) |
| `cosmic.desktop` | upstream cosmic modülü | ikinci oturum |
| `hyprland-uwsm.desktop` | hyprland paketi | **"Hyprland (uwsm-managed)"** — seçilecek olan |
| `hyprland.desktop` | hyprland paketi | UWSM'siz; bar/bildirim/idle GELMEZ (servisler UWSM hedefinde) |

**X11 girdisi YOK**: GNOME'un `gnome-xorg.desktop`'u bu yapılandırmada üretilmiyor,
`xsessions/` boş. Greeter `sw/share/`'e DEĞİL,
`config.services.displayManager.sessionData.desktops` store yoluna bakar
(16 Eyl'de bir kez yanlış dizine bakıldı). Elle yazılmış oturum girdisi **yok**.

### Oturum değiştirme — COSMIC → GNOME "already running" (24 Eyl 2026)

**Belirti:** COSMIC'ten logout → GNOME seçilince oturum açıldığı saniye kapanıyor;
her denemede `.gnome-session-init-worker` SIGABRT. Mesaj journal'a düşmüyor (stderr
greeter'a gidiyor), ikilinin içinden okundu: `A graphical session is already running!`.

**Kök sebep:** COSMIC çıkışında `Cosmic Session Target` iniyor ama
`graphical-session.target` inmiyor: `StopWhenUnneeded=yes` olsa da
`xdg-desktop-portal{,-gnome}.service` ona `Requisite=` ile bağlı ve D-Bus aktivasyonlu
portal oturumdan bağımsız yaşıyor. Kullanıcı yöneticisi greeter geçişinde ölmediği için
sonraki GNOME oturumu aktif target'ı görüp kendini öldürüyor.

**Çare:** `cosmic.nix`'te `cosmic-session-cleanup` user oneshot'ı
(`PartOf=cosmic-session.target`, ExecStop = `systemctl --user --no-block stop
graphical-session.target`). Build + unit dosyası doğrulandı; **canlı logout→GNOME
denemesi bekliyor.** Kontrol: `journalctl --user -b | grep 'Current graphical user session'`
çıkışta "Stopped" göstermeli.

---

## Pencere süslemesi — taşınabilir ders

"Başlık çubuğu" üç ayrı şeydir ve **yalnız ikisi kontrol edilebilir**:

1. **xdg-decoration konuşan uygulamalar** (Qt, native Wayland Electron/Chromium).
   Bunu açan `configuration.nix`'teki `NIXOS_OZONE_WL = "1"` — nixpkgs'in Electron
   sarmalayıcıları `--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations`
   bayraklarını tam bu değişkene bağlı ekliyor. Değişken yokken uygulamalar XWayland'de
   koşuyordu.
2. **GTK/libadwaita headerbar** — uygulamanın içinde çizilir, hiçbir bileşken ayarıyla
   kaldırılamaz.
3. **Uygulamanın kendi chrome'u** — yalnız o uygulamanın ayarıyla gider.

**COSMIC farkı:** Hyprland sunucu-taraflı süslemede yalnız kenarlık çiziyordu; COSMIC
**başlık çubuğu çizer** (Ayarlar → pencere yönetiminden kapatılır). "Borderless"
beklentisi COSMIC'te oturum ayarından geçer.

---
## GNOME — karantinalı oturum (16 Eyl 2026'da Plasma'nın yerine; 29 Eyl 2026'dan beri varsayılan)

`system/desktop/gnome.nix` upstream `services.desktopManager.gnome`'u açar;
`desktop.gnome.enable = false;` ile tek satırda geri alınır. Plasma'nın karantina
sözleşmesi aynen devralındı.

### Neden Plasma çıktı

Kullanıcı tercihi (16 Eyl 2026), teknik gerekçe değil — üç oturum taşımak yerine GNOME
Plasma'nın yerine geçti. Plasma'nın ölçümleri (idle 4.28 W, D3cold, kapanış maliyeti)
arşivde geçerli kayıt.

### DRM guard — ÜÇÜNCÜ sözdizimi

GNOME'da **ortam değişkeni yok**:

| Oturum | Mekanizma | Değer biçimi |
|---|---|---|
| COSMIC | `COSMIC_DRM_ALLOW_DEVICES` | `0x1002:0x1114` — virgülle ayrılır, `:` serbest |
| Plasma (arşiv) | `KWIN_DRM_DEVICES` | udev symlink yolu — `:` YASAK |
| **GNOME** | **udev `TAG+="mutter-device-ignore"`** | env değişkeni YOK; kart etiketlenir |

`mutter-device-ignore` **iki bağımsız kanıtla** doğrulandı:
1. String libmutter-18.so.0'da var (mutter 50.4, flake pin'i).
2. Upstream mutter'ın kendi udev kuralları bu etiketi kullanıyor (`rules.d`'de vkms
   için iki satır: `ID_PATH=="platform-vkms"`, `DEVPATH==".../faux/vkms/..."`);
   bizimki NVIDIA kartı için üçüncü satır.

Kural kart numarasına değil sürücüye bakar; ölçüm (16 Eyl 2026):
`card0 = nvidia @ 0000:64:00.0`, `card1 = amdgpu @ 0000:65:00.0`, numaralar boot
sırasına göre yer değiştirebilir.

### GNOME'un sızıntıları — Plasma'nınkinden çok daha fazla

Plasma'da kapatılacak tek şey `fwupd` timer'ıydı. GNOME modülünün açtığı ve
`gnome.nix`'te kapatılanlar: `localsearch` + `tinysparql` (dosya indeksleyici — 4.28 W bütçesi
ihlali), `rygel`, `dleyna`, `gnome-user-share`, `gnome-remote-desktop`, `geoclue2`,
`avahi`, `orca`, `i18n.inputMethod`, `gnome-browser-connector`, `gnome-initial-setup`.
Kapatılmayanlar: `gnome.nix` "Bilinen sızıntılar".

### Greeter: GDM (29 Eyl 2026)

GNOME modülü GDM'i zorlamıyor; `services.displayManager.gdm.enable` 29 Eyl 2026'da
`login.nix`'te elle açıldı. GDM kendi gnome-shell'ini koştuğundan `mutter-device-ignore`
greeter'ı da kapsar. GNOME modülü `defaultSession`'a dokunmuyor, düz `"gnome"` ataması
yeter (Plasma dönemindeki "mkDefault'a çevirirsen Plasma'ya döner" tuzağı kalktı).

### Ölçülmeden yazılmayacaklar

1. **idle watt** — `Documentation/aerox16/power.md` yöntemi, GNOME oturumunda.
2. **dGPU D3cold** — `power_state` + `gnome-shell`'in açtığı DRM fd'leri.
3. ~~Closure farkı~~ → **ÖLÇÜLDÜ (16 Eyl 2026)**: Plasma'lı sistem **26.47 GiB**,
   GNOME'lu build **24.93 GiB** → **net −1.54 GiB**. Giden (kf6, xapian/baloo, drkonqi,
   xdg-desktop-portal-kde ≈ 4.1 MiB, sycoca) gelenden (webkitgtk 167 MiB, yelp, vte,
   xdg-desktop-portal-gnome) fazla. Yöntem: `nix path-info -S /run/current-system ./result`.
4. **`gsd-power` ↔ `power-display.nix`** — parlaklık/PPD sahipliği yarışı (Plasma'da
   `powerdevil` için de ölçülmemişti).
5. **Fn köprüsü** — GNOME `KEY_MICMUTE`/`KEY_TOUCHPAD_TOGGLE`'ı kendi işlediği için
   `fn-bridge` o oturumda eylemi atlıyor (`gnome_running()`). Çift toggle olmadığı
   doğrulanmalı. Ayrıntı: `Documentation/aerox16/fn-keys.md`.

---


## COSMIC (System76) — kurulum defteri (2 Eyl 2026; 11–29 Eyl 2026 varsayılan, sonra ikinci oturum)

`system/desktop/cosmic.nix` upstream `services.desktopManager.cosmic`'i açar.
`desktop.cosmic.enable = false;` ile geri alınır — bayrak kapalıyken toplevel
**bit-aynı** dönüyor (doğrulandı). Plasma/Serpantinum gibi bir deneme değil, ana
masaüstü kalitesinde kuruldu.

### Ayarlar neden imperatif — mimariden geliyor, hile değil

Kullanıcı isteği: menüden seçilen ayarlar kalıcı olsun, deklaratiflik değil.
`cosmic-config` iki katmanlı (`libcosmic/cosmic-config/src/lib.rs`, `ConfigGet::get()`):

```rust
match self.get_local(key) {                              // ~/.config/cosmic/<ad>/v<N>/<key>
    Ok(value) => Ok(value),
    Err(Error::NotFound) => self.get_system_default(key), // $XDG_DATA_DIRS/cosmic/...
    Err(why) => Err(why),
}
```

Her anahtar ayrı bir RON dosyası, **kullanıcı katmanı her zaman kazanır**; sistem
katmanı yalnız fallback. Nix `~/.config/cosmic`'e dokunmadığı sürece GUI ayarı bir
rebuild'de ezilemez.

> **`~/.config/cosmic` altına Nix'ten hiçbir şey yazılmayacak** — ne `home.file`, ne
> `xdg.configFile`, ne activation script. Store symlink'i dosyayı salt-okunur yapar ve
> ayar menüsü **sessizce kaydedemez** (hata vermez). Sistem varsayılanı gerekirse tek
> meşru yol `/share/cosmic/<ad>/v<N>/<key>` (modül `environment.pathsToLink`'e ekliyor).
> Tek kullanımı (13 Eyl 2026'dan beri): aşağıdaki "Copilot tuşu".

Aynı gerekçeyle **Stylix köprüsü kurulmadı** (Stylix'in NixOS hedeflerinde `cosmic`
zaten yok). Bedeli bilinçli: COSMIC Stylix paletiyle eşleşmez, kendi teması olur.

### Copilot tuşu — ölçüm (13 Eyl 2026)

Kısayol `/share/cosmic` sistem katmanına yazılır; tuzaklar (F23 ↔ XF86Assistant, tam
modifier eşitliği, iki sessiz gölgeleme) `cosmic.nix`'te. Tuşun ne gönderdiği:

- `wev`, canlı COSMIC: üç olaylık akor — `Super_L` (133) → `Shift_L` (50) → keycode 201
  (= evdev `KEY_F23`).
- Tuş anında `depressed: 00000041: Shift Mod4` — xkb Shift/Super'i **tüketmiyor**
  (`types/pc`, `PC_SHIFT_SUPER_LEVEL2`: `preserve[Shift]` + `preserve[Super]`).
- `xkbcli compile-keymap --model pc104 --layout us` → `<FK23>`:
  `symbols[1] = [ F23, XF86Assistant ]`. cosmic-comp `raw_syms()` ile Level 1'i eşliyor
  (`src/input/mod.rs:2148` → smithay `key_get_syms_by_level(…, 0)`), yani doğru anahtar
  `F23`. Modifier karşılaştırması tam eşitlik (`src/config/key_bindings.rs:41`); sistem
  katmanı `find_data_file` ile çözülüyor (`cosmic-config/src/lib.rs:236`); spawn ortamı
  `src/input/actions.rs:1080`.

### DRM guard — bu repodaki `:` kuralı burada TERSİNE dönüyor

Eski oturumlarda (aquamarine, kwin) değer `:` İÇEREMEZDİ; **bu kuralı cosmic.nix'e
kopyalamak hata olur.** `cosmic-comp/src/utils/env.rs`:

```rust
pub fn dev_list_var(name: &str) -> Option<Vec<DeviceIdentifier>> {
    let value = std::env::var(name).ok()?;
    Some(value.split(',').flat_map(try_parse_dev_from_str).collect())
}
```

Ayırıcı **virgül**; kabul edilen dört biçimden üçü `:` içermek zorunda:

| Biçim | Anlamı |
|---|---|
| `0xVVVV:0xDDDD` | PCI vendor:device — **kullanılan** |
| `major:minor` | char cihaz numarası |
| `pci-0000:65:00.0` | `/dev/dri/by-path/<ad>-render` okunur |
| `<ad>` | `/dev/dri/<ad>` yolu |

PCI kimliği boot sırasından bağımsız → COSMIC için **udev symlink'i yok**
(`hypr-igpu`/`kwin-igpu`/`sddm-igpu` desenini tekrarlama).

Değer ölçüldü (1 Eyl 2026); `DeviceIdentifier::Id::matches()` render node'un
`/sys/dev/char/<major>:<minor>/device/{vendor,device}` dosyalarını okur:

| GPU | PCI | render node | char | vendor/device |
|---|---|---|---|---|
| AMD Radeon 860M (iGPU) | `65:00.0` | renderD128 | 226:128 | **`0x1002` / `0x1114`** ← izinli |
| NVIDIA RTX 5060 (dGPU) | `64:00.0` | renderD129 | 226:129 | `0x10de` / `0x2d19` |

```nix
# 20 Eyl 2026'dan beri KOŞULLU — bkz. "Harici ekran (HDMI)" bölümü
environment.sessionVariables.COSMIC_DRM_ALLOW_DEVICES =
  if config.desktop.externalDisplay.enable then
    "0x1002:0x1114,0x10de:0x2d19"
  else
    "0x1002:0x1114";
```

Gerekçe ("açık fd RTD3/D3cold'u bloke eder") 20 Eyl 2026 ölçümüyle zayıfladı — bkz.
"Bedeli — ÖLÇÜLDÜ".

#### Guard ÇALIŞIYOR — ölçüldü (2 Eyl 2026, ilk COSMIC oturumu)

```bash
# 1) değişken cosmic-comp'un gerçek ortamında
tr '\0' '\n' < /proc/$(pgrep cosmic-comp)/environ | grep COSMIC_DRM
#   → COSMIC_DRM_ALLOW_DEVICES=0x1002:0x1114

# 2) dGPU uykuda
cat /sys/bus/pci/devices/0000:64:00.0/power_state
#   → D3cold

# 3) EN GÜÇLÜ KANIT — cosmic-comp hangi DRM node'larını açtı
ls -l /proc/$(pgrep cosmic-comp)/fd | grep -o '/dev/dri/[a-zA-Z0-9]*' | sort | uniq -c
#   → 4 /dev/dri/card1        (AMD iGPU)
#     card0 (NVIDIA) HİÇ AÇILMAMIŞ
```

3. madde en güçlüsü: `power_state` sonuç, fd listesi sebep. `AQ_DRM_DEVICES`'ın da
cosmic-comp ortamında görünmesi etkisiz sızıntı (yalnız aquamarine okur).

### Harici ekran (HDMI) — guard'ın ödenmemiş faturası (20 Eyl 2026)

Guard'ın yan etkisi: HDMI'a takılan monitöre görüntü gitmiyordu. Sebep kablonun nereye
gittiği:

| konektör | kart | PCI | GPU |
|---|---|---|---|
| `card0-HDMI-A-1` | card0 | `64:00.0` | **NVIDIA RTX 5060 (dGPU)** |
| `card1-eDP-1` | card1 | `65:00.0` | AMD Radeon 860M (iGPU) |

HDMI portu **MUXSUZ, doğrudan dGPU'ya bağlı**. Kernel monitörü görüyordu, sürecek kart
açılmamıştı:

```bash
cat /sys/class/drm/card0-HDMI-A-1/status        # → connected
head -1 /sys/class/drm/card0-HDMI-A-1/modes     # → 1920x1080  (EDID okunuyor)
ls -l /proc/$(pgrep cosmic-comp)/fd | grep dri
#   → 4 × /dev/dri/card1 ;  card0 YOK
```

GNOME'da aynı yan etki `mutter-device-ignore` etiketinden geliyordu.

**Çözüm** `desktop.externalDisplay.enable` (varsayılan **açık**,
`system/desktop/external-display.nix`): COSMIC'te dGPU allow-list'e eklenir, GNOME'da
udev etiketi yazılmaz. **`mux.nix` ile karıştırma** — hibrit mod bozulmaz: panel iGPU'da,
PRIME offload ve RTD3 finegrained açık (`build` sonrası doğrulandı:
`prime.offload.enable = true`, `powerManagement.finegrained = true`).

#### Bedeli — ÖLÇÜLDÜ, devralınan iddia çürüdü (20 Eyl 2026)

Kural 6 (4.28 W boşta bütçesi) ile beklenen gerilim ölçümle kalktı. Harici ekran
**takılı değilken**:

```bash
ls -l /proc/$(pgrep cosmic-comp)/fd | grep dri
#   → card0 (NVIDIA) + renderD129 (×2) + card1 (×4)   ← dGPU node'u AÇIK

# 6 × 10 s örnek, HDMI disconnected:
#   → power_state = D3cold, runtime_status = suspended   (6/6, sapma yok)
```

**Takılıyken** (aynı gün, monitör görüntü verirken):

```bash
cat /sys/class/drm/card0-HDMI-A-1/{status,enabled,dpms}
#   → connected / enabled / On        ← konektör SÜRÜLÜYOR
cat /sys/bus/pci/devices/0000:64:00.0/{power_state,power/runtime_status}
#   → D0 / active                      ← beklenen ve kaçınılmaz
```

`enabled`, `status`'tan güçlü kanıt: `connected` düzeltmeden önce de okunuyordu,
`enabled` compositor'ın mod verdiğini gösterir.

Sonuç: **compositor dGPU'nun DRM node'unu açık tutarken de kart D3cold'a iniyor.**
Plasma döneminden devralınan *"açık fd RTD3'ü bloke eder, idle ~4.3 W → ~7 W"* iddiası bu
yapılandırmada doğrulanmadı; guard'ın idle gerekçesi zayıfladı. Tek kaçınılmaz bedel:
ekran takılıyken dGPU uyanık. Bayrak geri alınabilir; değişken PAM'den geldiği için
kapatmak **oturum yeniden başlatma** ister, `switch` yetmez.

> **Tuzak — doğrulamada `pgrep -x` kullanma.** NixOS sarmalayıcısı yüzünden `comm`
> `.cosmic-comp-wr` (15 karaktere kırpılmış); `pgrep -x cosmic-comp` boş döner ve
> "düzeltme işe yaramadı" diye yanlış okunur (20 Eyl 2026'da oldu). `-x` olmadan kullan.

### ~~Oyun bu oturumda çalışmaz — kasıtlı~~ → İKİ KEZ ÇÜRÜDÜ

2 Eyl 2026'daki iddia: "allow-list yalnız iGPU'ya izin verdiği için COSMIC'te
`gamerun`'ın PRIME offload'ı devre dışı." **11 Eyl 2026**'da çürüdü (değişken yalnız
compositor'ın açacağı node'u belirler, oyun süreci etkilenmez); **20 Eyl 2026**'da öncülü
de düştü (allow-list artık dGPU'yu da içeriyor).

**11 Eyl 2026 ölçümü** (canlı COSMIC, değişken aktif):

```bash
vulkaninfo --summary              # → hem RADV/860M hem NVIDIA RTX 5060 listeleniyor
GR_NOPERF=1 gamerun vulkaninfo    # → GPU1 = PHYSICAL_DEVICE_TYPE_DISCRETE_GPU
GR_NOPERF=1 gamerun env           # → __NV_PRIME_RENDER_OFFLOAD=1 + _PROVIDER=NVIDIA-G0
```

Aynı anda boştaki dGPU `power_state = D3cold` — guard idle tasarrufunu da bozmuyordu.

### Karantina sınırı — maliyet neden iki satır

Modülün getirdiği servisler sisteme karşı ölçüldü (`systemctl is-enabled`):

| Servis | Modül ne diyor | Sistemde durumu | Sonuç |
|---|---|---|---|
| `avahi` | `mkDefault true` | **not-found** | ⚠ yeni kalıcı daemon → `false` |
| `orca` | `mkDefault …` | **not-found** | ⚠ yeni → `false` |
| `acpid` | `mkDefault true` | enabled/active | değişiklik yok |
| `upower` | `true` | active | değişiklik yok |
| `accounts-daemon` | `true` | active | değişiklik yok |
| `geoclue2` | `true`, `enableDemoAgent=false` | enabled, D-Bus aktivasyonlu | `geoclue.nix` ile aynı değerler — çakışma yok |
| `power-profiles-daemon` | `mkDefault` | active | `power.nix` kazanır |
| `networkmanager`/`bluetooth`/`gvfs` | `mkDefault true` | zaten açık | değişiklik yok |

avahi bu makinede hiç kurulu değildi ve tüketicisi yok. **Ağ yazıcısı eklenirse geri
açılacak satır budur.**

### Session wrapper gerekmedi

Plasma'nın `sessionWrapper`'ı qt6ct ↔ Breeze çekişmesi içindi; COSMIC Qt değil, upstream
`cosmic-session` paketi doğrudan kullanılıyor (`Exec=…/cosmic-session-1.6.0/bin/start-cosmic`,
`DesktopNames=COSMIC`).

### Kapanış maliyeti — ÖLÇÜLDÜ (2 Eyl 2026)

Aynı ağaçta yalnız bayrak çevrilerek:

| Yapılandırma | Kapanış |
|---|---|
| `desktop.cosmic.enable = false` | 28.54 GB |
| `desktop.cosmic.enable = true` | 30.65 GB |
| **fark** | **+2.11 GB** |

(Plasma: +2.62 GB.) En büyük kalemler `pop-icon-theme` 65.8 MiB,
`xdg-desktop-portal-cosmic` 55.9 MiB, `pop-launcher` 9.5 MiB,
`network-manager-applet` 5.6 MiB.

### Kayda geçen, kapatılmayan sızıntılar

Güncel liste: `cosmic.nix` "Bilinen sızıntılar" bloğu (`COSMIC_DRM_ALLOW_DEVICES`'ın
diğer oturumlara sızması — maliyeti sıfır — aynı dosyanın DRM guard notunda).

### XWayland — açık bırakıldı

Ölçüm kapatmayı desteklemedi: Hyprland'de açık 6 pencereden 3'ü XWayland'di ve üçü de
Steam'di; workstation uygulamaları zaten native Wayland (`NIXOS_OZONE_WL`).
**ÖLÇÜLDÜ (2 Eyl 2026, COSMIC):** `xlsclients` → yalnız `steam` ve `steamwebhelper`.
X11'e düşen tek şey Steam; Steam kapalıyken liste boş olmalı.

### Oturum değişince ölçüm çürür — gamemode `inhibit_screensaver` (11 Eyl 2026)

`system/kernel/sched.nix`'teki `inhibit_screensaver = 1`:

- **16 Ağu 2026 — sağlayıcı YOK** (hypridle 9 Ağu'da düşmüştü; D-Bus'ta
  `org.freedesktop.ScreenSaver` sahibi yoktu).
- **11 Eyl 2026 — sağlayıcı VAR**: `busctl --user list | grep -i screensaver` →
  `org.freedesktop.ScreenSaver` / `cosmic-idle`. Oyun sırasında otomatik kilit ertelenir.

**Ders:** bir D-Bus/portal ayarının canlı olup olmadığı masaüstüne bağlı; oturum
değişince yeniden ölçülür, "ölü" diye silinmez. GNOME oturumunda yeniden ölçülmedi.
Tam ekran oyunu asıl koruyan Wayland idle-inhibit protokolü. Test edilmedi: kontrolcüyle
5+ dk klavye/fare girdisi olmadan oyna.

### Doğrulama — sırayla

```bash
# 1) oturum girdisi var mı (greeter sessionData.desktops'a bakar, sw/share'e değil)
nix eval --raw .#nixosConfigurations.nixos.config.services.displayManager.sessionData.desktops
ls <yukarıdaki yol>/share/wayland-sessions/            # cosmic.desktop, gnome.desktop

# 2) COSMIC'e gir → dGPU uykuda mı (ASIL KRİTER)
cat /sys/bus/pci/devices/0000:64:00.0/power_state      # D3cold BEKLENİYOR
systemctl --user show-environment | grep COSMIC_DRM

# 3) idle bütçesi — Documentation/aerox16/power.md yöntemi
#    (120 s sakinleşme + 6×10 s örnek), kriter 4.28 W ± gürültü

# 4) Wayland saflığı
xlsclients                                             # yalnız steam/steamwebhelper

# 5) İMPERATİF KALICILIK
#    Ayarlar'dan görünür bir şey değiştir, sonra:
ls -la ~/.config/cosmic/*/v1/     # normal DOSYA olmalı, store symlink'i DEĞİL
#    ardından switch + yeniden giriş → ayar YERİNDE DURMALI
```

---

## Hyprland — karantinalı üçüncü oturum (3 Eki 2026, sıfırdan)

Modüller: `system/desktop/hyprland.nix` (compositor, UWSM, hyprlock PAM, DRM kilidi) +
`home/desktop/hyprland/` (`default.nix` bayrak ve Lua bağlantısı, `session.nix` kilit/
idle/bildirim/pano/polkit/gece ışığı/başlatıcı, `bar.nix` waybar, `scripts.nix`
yardımcı betikler, `lua/` config'in kendisi). `desktop.hyprland.enable = false;` tek
satırda geri alır; HM tarafı bayrağı `osConfig`'ten okur.

Arşivdeki Hyprland/Caelestia döneminden **hiçbir şey taşınmadı** (kullanıcı kararı):
tasarım sıfırdan, paketin kendi API'sine (`share/hypr/stubs/hl.meta.lua`) ve kaynağına
karşı yazıldı.

### Yığın

| İş | Bileşen | Neden bu |
|---|---|---|
| compositor | Hyprland 0.56.2, **Lua config** | 0.55'ten beri hyprlang yerine Lua; bind'ler Lua fonksiyonu olabiliyor |
| oturum | UWSM (`programs.hyprland.withUWSM`) | graphical-session.target'ı kendisi yönetir ve çıkışta temiz indirir |
| bar | waybar 0.15.0 (yamalı, aşağıda) | Üst kenara yapışık tek ada: kapalıyken alan 1-2 · saat · alan 3-4 (açıkken de saate yapışık), yanında yalnız o an geçerliyse müzik notası / rahatsız etme zili / düşük pil. Üstüne gelince iki eksende büyür, altında kontrol paneli: tarih · tepsi · güç düğmesi; 2×3 eşit karo (Wi-Fi, Bluetooth, rahatsız etme, gece ışığı, uyanık tut, güç profili — açık olan renkli); ses ve parlaklık kaydırıcıları; medya kartı; pil + donanım satırı. Font Geist. Pencereleri itmez (`exclusive = false`), üst boşluk `look.lua` `gaps_out.top = 40` |
| başlatıcı / menüler | hypr-launcher (kendi, GTK4 + layer-shell, `launcher/`) | Hazır bekleyen servis; tuş soket2'ye olay yayar, süreç doğmaz. Adanın İÇİNDE açılır. Uygulama + açık pencere + sistem komutu + hesap + web araması; aynı pencere pano ve güç kipi |
| bildirim + OSD | mako | D-Bus'ta bekler; ses/parlaklık OSD'si ayrı daemon değil, `category=osd` bildirimi |
| kilit / idle | hyprlock / hypridle | ext-session-lock, ext-idle-notify — yoklama yok |
| duvar kağıdı | hyprpaper | Stylix'in hyprland hedefi kendisi açıyor (`stylix.image`) |
| pano | cliphist (`wl-paste --watch`) | pano olayında uyanır |
| polkit | hyprpolkitagent | yoksa her polkit isteği sessizce reddedilir |
| gece ışığı | hyprsunset | CTM compositor'da; 21:00 → 4500 K, 07:00 → doğal |
| ekran görüntüsü | grimblast + satty | grimblast 2026-08 sürümü Lua-farkında (`hyprctl eval`) |
| terminal camı | hyprglass 0.9.1 (eklenti, `hyprglass.nix`) | Yalnız ghostty (`+hyprglass_enabled` etiketi, global kapalı): liquid glass — `glass` preset tabanı, kenarda güçlü kırılma, mercek kubbesi, renk ayrışması, bevel. Zemin saydamlığı (0.4) yalnız bu oturumda: `ghostty-glass` servisi `/run/user/1000/ghostty-hyprland`'e yazar, ghostty `config-file = ?…` ile okur; GNOME/COSMIC'te dosya yok → 0.85. Hyprland iç API'sine bağlı → `rev` upstream `hyprpm.toml` `commit_pins`'teki Hyprland eşine kilitli; Hyprland yükselince birlikte güncellenmeli, yoksa yüklenmez ve terminal `look.lua` blur'una düşer |

**Kapanış maliyeti — ÖLÇÜLDÜ (3 Eki 2026):** 25.8 GiB → 26.0 GiB (`nix path-info -Sh
/run/current-system ./result`). Hyprland yığınının tamamı ~0.2 GiB; COSMIC'in +2.11 GB'ının
onda biri. Kaynaktan derlenen paketler yamalı waybar ve hyprglass eklentisi.

Renklerin hepsi Stylix paletinden. Pencere kenarlığı KAPALI (`border_size = 0`,
3 Eki 2026, kullanıcı tercihi): Stylix'in mavi kenarlığı waybar'ın sade haplarıyla
uyuşmuyordu; pencereler boşluk (5/10 px), 12 px köşe ve gölgeyle ayrışıyor. Gölge, hyprlock,
mako Stylix hedeflerinden; başlatıcı renkleri `session.nix`'te paletten; waybar'da
`addCss = false` ile yalnız `@baseXX` değişkenleri. Elle bağlanan tek renkler Stylix
hedeflerinin kapsamadığı yerler (hyprlock etiketleri, OSD çubuğu, takvim) ve onlar da
`config.lib.stylix.colors`'tan.

### Karantina — HM servisleri yalnız bu oturumda

HM'in Wayland servisleri (waybar, hypridle, hyprpaper, cliphist, hyprpolkitagent,
hyprsunset) varsayılan olarak `graphical-session.target`'a asılır; o hedef GNOME ve
COSMIC'te de etkin → bar GNOME'un üstünde açılırdı. `wayland.systemd.target` UWSM'in
Hyprland'e özel hedefine çevrildi:

```
wayland-session@hyprland.desktop.target
```

Ad, oturum dosyasının `Exec=uwsm start -e -D Hyprland hyprland.desktop` satırından
türer (`uwsm/main.py`: `CompGlobals.id = basename(argv[0])` → systemd kaçışı). Build
sonrası doğrulandı: HM'in ürettiği `…/systemd/user/` altında **tek** `.wants` dizini
bu hedefin (+ syncthing'in `default.target`'ı).

Üç ek delik kapatıldı:

1. **mako'nun D-Bus aktivasyonu.** HM modülü paketi `dbus.packages`'a koyuyor →
   `Name=org.freedesktop.Notifications` aktivasyon dosyası profile girer, GNOME/COSMIC'te
   o adı ilk kapan mako olabilirdi. `services.mako.package = null` + yalnız bu hedefe
   bağlı elle yazılmış `mako.service` (`Type=dbus`). Profilde başka aktive edilebilir
   bildirim daemon'u yok (3 Eki 2026, `share/dbus-1/services` tarandı).
2. **waybar'ın `tray.target`'ı.** HM waybar'ı ona da asıyor; bugün başlatanı yok ama
   ileride `Requires=tray.target` taşıyan bir servis GNOME'da açılırsa bar da açılırdı.
   `Install.WantedBy` `mkForce` ile tek hedefe indirildi.
3. **Oturum ortamı.** Hyprland'e özel değişkenler `environment.sessionVariables`'a
   değil `~/.config/uwsm/env-hyprland`'e yazılıyor (UWSM `prepare-env.sh` yalnız
   `XDG_CURRENT_DESKTOP=Hyprland` iken okur). İstisna `AQ_DRM_DEVICES` — aşağıda.

HM'in kendi `hyprland-session.target`'ı **kapalı** (`systemd.enable = false`): UWSM ile
birlikte açılırsa ilk iş `systemctl --user stop hyprland-session.target` koşar, o da
`PropagatesStopTo` ile graphical-session.target'ı ve UWSM üzerinden compositor'ı indirir.
Ortam aktarımını Hyprland kendisi yapıyor (`Compositor.cpp startCompositor`:
`import-environment` + `sd_notify READY=1` → UWSM'in `Type=notify` birimi).

**Greeter'da iki girdi var** (paket ikisini birden taşıyor): doğrusu
**"Hyprland (uwsm-managed)"**. Düz "Hyprland" girdisi de açılır ama bar/bildirim/idle
gelmez — servisler UWSM hedefine bağlı.

### DRM kilidi — DÖRDÜNCÜ sözdizimi

| Oturum | Mekanizma | Ayırıcı / biçim |
|---|---|---|
| COSMIC | `COSMIC_DRM_ALLOW_DEVICES` | virgül, `0xVVVV:0xDDDD` |
| GNOME | udev `mutter-device-ignore` | ortam değişkeni yok |
| **Hyprland** | **`AQ_DRM_DEVICES`** | **`:` ile bölünür, her parça DOSYA YOLU**, ilk kart birincil |

`/dev/dri/by-path/pci-0000:65:00.0-card` kendi içinde `:` taşıdığı için parçalanır →
iki-nokta-içermeyen udev symlink'leri `dri/hypr-igpu` (`DRIVERS=="amdgpu"`) ve
`dri/hypr-dgpu` (`DRIVERS=="nvidia"`). Eşleşme canlı ölçüldü (3 Eki 2026,
`udevadm info -a /dev/dri/cardN`): card0 → `nvidia` 10de:2d19, card1 → `amdgpu`
1002:1114. `externalDisplay` açıkken değer `/dev/dri/hypr-igpu:/dev/dri/hypr-dgpu`
(HDMI dGPU'da), kapalıyken yalnız iGPU; `mux.nix` `mkForce` ile `hypr-dgpu`'ya çevirir.

Değişken `sessionVariables`'ta, çünkü aquamarine backend'i config'i okumadan kurar —
Lua'daki `hl.env` geç kalır. Öteki oturumlara sızar; maliyeti sıfır.

### Tazeleme — 165 Hz sabit + VRR (4 Eki 2026; VRR 5 Eki'de fişe bağlandı)

Panel `lua/main.lua`'da sabit `2560x1600@165`. Fiş tak/çıkar Hyprland'de **ne
tazelemeye ne parlaklığa** dokunur — eski `refresh_panel()` + `hyprland.nix`
`ExecStartPre` kancası ve `power-display.nix`'teki %40/%80 parlaklık yazımı
kaldırıldı (kullanıcı isteği).

VRR `power_sync()` ile fişe bağlı: fişte `misc.vrr = 1` (her zaman açık, 4 Eki
kullanıcı isteği), pilde `3` (yalnız tam ekran video/oyun). Gerekçe ölçüm: VRR
açıkken PSR hiç devreye girmiyor, pilde statik masaüstü **−0.70 W**
(`Documentation/aerox16/power.md` "2026-10-05"). Tetikleyici: config yüklemesi +
`power-display-user` (fiş olayında `hyprctl eval 'power_sync()'`). İmleç titremesi
görülürse fiş kolunu `2` (yalnız tam ekran) yap.

`power-display-user`'ın cosmic-randr kolu (yalnız COSMIC'te 165/60 Hz) Hyprland'de
**bilerek koşmaz** (yalnız `power_sync()`'i çağırıp çıkar): cosmic-randr'ın iki protokolü de opsiyonel
(`lib/src/context.rs`), wlr-output-management Hyprland'de var → ikinci bir modeset ve
compositor config'ini ezen kalıcı bir wlr override bırakırdı
(`MonitorRuleManager::get` → `applyWlrOutputConfig`).

### Waybar yaması — Lua'da eski dispatch sözdizimi

`hyprland/workspaces` düğmeye tıklanınca IPC'ye `dispatch workspace 3` yolluyor. Lua
config'te Hyprland her `dispatch X`'i `hl.dispatch(X)` olarak değerlendiriyor
(`HyprCtl.cpp dispatchRequest`) → sözdizimi hatası, tıklama sessizce boşa düşüyordu.
`bar.nix` dört çağrıyı `postPatch` + `--replace-fail` ile Lua biçimine çeviriyor
(paketin kendi postPatch'i de orada, faz canlı). Doğrulandı: derlenen
`.waybar-wrapped`'ta `dispatch hl.dsp.focus({ workspace = …` var, eski iki dize yok.
Upstream düzelince `--replace-fail` derlemeyi sesli düşürür → yamayı sil.

### Waybar yaması — ada (`waybar-island.patch`, 4 Eki 2026)

- **İki eksenli drawer.** Bara dik açılan grup (yatay barda `orientation = "vertical"`)
  GtkRevealer yerine kırpan bir kap (ScrolledWindow, EXTERNAL politika) kullanır;
  boyutu tick callback'le iki eksende BİRLİKTE, kapalı adanın genişliğinden tam
  boyuta canlandırılır (easeOutQuart), içerik ortadan açılıp belirir. Revealer'la
  genişlik ancak içerik saat satırını aşınca büyüyordu → iki aşamalı, seken hareket.
  Hyprland tarafında waybar katmanı `no_anim` (rules.lua): katman animasyonu yüzeyi
  her boyut değişiminde esnetiyordu.
- **GRAB ayrılışı yok sayılır**: tepsi menüsü açılınca çekmece kapanmaz.
- **Grup içinde `expand`**: upstream yalnız barın üç kutusunda okuyor. Kenardaki iki
  boşluk modülü (alanları saate yapışık tutar) ve tarih bununla yayılıyor.
- **Boyut uyarısı yapılandırılan değere göre**: büyüyen pencerede her animasyon
  karesi "Requested height … less than minimum" basıyordu.

**Sabit pencere + yay (7 Eki 2026).** İlk tasarımda bar `width = 2` idi: pencere
içerik kadar genişti, ada büyürken waybar her karede yeniden boyutlanıyor, Hyprland
da her karede yeniden ortalıyordu. Genişlik tek/çift arasında gidip geldikçe saat ve
alan numaraları 1–2 px sağa sola titriyordu (120 fps kayıtta saat metninin x'i
11↔12). Şimdi pencere SABİT (`island.nix` `window`, 760×580, çift), ada onun içinde
üstte ortalı büyür ve genişliği hep çift piksel; yama giriş bölgesini her karede
adanın dikdörtgenine daraltır (`wl_surface` input region) → saydam kısım fareyi
alttaki pencerelere geçirir. Hareket yay fiziği (yarı örtük Euler, 1 ms adım):
açılış `spring.open = [0.55 s, sönüm 0.58]` hedefi ~%10 aşıp oturur, kapanış
kritik sönümlü; hedef değişince (hızlı gir-çık) o anki hız korunur. Başlatıcı
dönüşümü de aynı motorda (`drawer.morph`; etiket METNİNE bakılır — CSS'te karşılığı
olmayan sınıf değişimi GTK3'te style-updated yaymıyor). Doğrulama ekransız sway'de,
kalıcı sanal fareyle (pywayland + wlr-virtual-pointer): 327 karede saat x'i sabit,
saydam alanda imleç adayı açmıyor. **İçerik boyuta bağlı (8 Eki):** panel ve
başlatıcı içeriği adayla birlikte kırpılarak açılır/toplanır, saydamlığı zamana değil
adanın o anki yüksekliğine bağlı (smoothstep %6→%46). Eskiden içerik gecikmeli
belirip erken söndüğü için geçişlerde ada bir an boş blok gibi görünüyordu.
Başlatıcının kabı aynı yayı taklit eder (`leadMs` geç kalkar, kapanışta
`closeLead` kadar hızlı) → içerik adanın kenarından taşmaz. Kap dikeyde hep
üste yaslı (yoksa içerik alttan açılıyordu). Başlatıcı açılışta waybar'a sinyal
atmaz (yalnız bayat durum dosyası varsa): işleyici kurulmadan gelen SIGRTMIN+10
waybar'ı öldürüyordu. İçbükey köşeler `.modules-center` arka planında
iki `radial-gradient`. Font `home.packages` + `fonts.fontconfig.enable` (HM fontconfig
kapalıyken HM profilindeki font görünmüyordu, JetBrains Mono'ya düşüyordu).

### Başlatıcı — hypr-launcher (7 Eki 2026; fuzzel'in yerine)

Fuzzel dönemi (4–7 Eki): ada fuzzel boyutuna büyüyor, fuzzel üstüne biniyordu; ama
fuzzel'in dar karakter-ızgarası (198 px, 5 satır, adlar kesik) ve tek satırlık
sonuçları kullanıcıya yetmedi. Yerine kendi GTK4 başlatıcımız (`home/desktop/hyprland/
launcher/launcher.py` + `style.css`, paket `scripts.nix` `launcher`, servis ve config
`session.nix`):

- **Hazır bekler.** `hypr-launcher.service` uygulama dizinini, simgeleri ve pencereyi
  bir kez kurar (~46 MB). SUPER+Space/V/Esc `hl.dsp.event("hypr-launcher apps|clip|power")`
  yayar (binds.lua), servis soket2'den duyar — süreç doğmaz, ilk kare anında. İkinci
  giriş D-Bus eylemi: `gapplication action local.hypr.launcher open "'apps'"`.
- **Adanın içinde açılır.** Başlatıcının zemini yok. Açılışta waybar'a SIGRTMIN+10:
  `custom/morph` metni kip adı olur, waybar yaması adayı yayla kipin boyutuna
  büyütür (`drawer.morph`); saydam katman tam aynı yere biner, üst 26 px'i boş →
  adanın alan/saat satırı görünür kalır, içerik adayla birlikte açılır.
  İçerik adayla aynı yayla kırpılarak açılır ve toplanır (aşağıda "Sabit pencere
  + yay").
  Tam ekranda waybar pencerenin altında kalır → başlatıcı adayı kendisi çizer (`.solo`).
- **Ölçüler tek yerde** (`island.nix`): kip başına genişlik + satır sayısı; yükseklik
  hesaplanır (`header + chrome + satır × 48`). Ada ve katman aynı sayıları okur.
- **Arama:** ad > genel ad > yürütülebilir > anahtar kelime/açıklama (yalnız kelime
  başı); Türkçe harf katlama (`gor` → "Görsel"), fzf benzeri dağınık eşleşme; kullanım
  sıklığı 14 gün yarı ömürle (`~/.local/state/hypr-launcher/frecency.json`). Açık
  pencereler (`j/clients`, seçince odak), sistem komutları (pano, güç, rahatsız etme,
  gece ışığı, ekran görüntüsü, renk seçici, UEFI'ye yeniden başlat), hesap
  (`3,5*2+sqrt(16)` → 11, Enter panoya), `> komut` (ghostty'de), en altta web araması
  (`zen-beta --search`). Tab: seçili uygulamanın masaüstü eylemleri.
- **Pano kipi:** cliphist geçmişi, görsel kayıtların küçük resmi (yalnız görünen
  satırlar, önbellekli), ⇧Del siler. **Güç kipi:** kilit, uyku, oturum, yeniden
  başlat, kapat.
- GTK `GSK_RENDERER=gl` (Vulkan bütün aygıtları sayıp NVIDIA ICD'sini yüklüyordu);
  dGPU açılışta `suspended` kaldı (doğrulandı). Sarmalayıcının `LD_PRELOAD`'u
  (gtk4-layer-shell) ve `GI_TYPELIB_PATH` açılan uygulamalara GEÇMEZ (`CHILD_ENV`).
- Odak: `ON_DEMAND`; başka yere tıklanınca odak gider → kapanır.

**Test ortamı (ekransız).** Hyprland'in headless kipi yok; görsel denemeler kullanıcının
ekranını bozmadan wlroots headless sway'de yapıldı (`WLR_BACKENDS=headless
WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128`), waybar + başlatıcı `WAYLAND_DISPLAY=wayland-2`
ile, `grim`/`wf-recorder` aynı sokete. Başlatıcı waybar'ı `/proc/*/environ`'daki
`WAYLAND_DISPLAY` eşleşmesiyle seçer — test örneği gerçek bara sinyal atmaz. Sanal
işaretçi (wlrctl) komut bitince düştüğü için hover orada denenemez; panel düzeni
drawer'sız bir config kopyasıyla çizdirildi.

### Kodda kalan tuzaklar

- **İlk switch'te `/dev/dri/hypr-*` symlink'leri OLUŞMAZ** (3 Eki 2026'da yaşandı):
  udev yeni kuralı yükler ama zaten var olan kartlara uygulamaz. Symlink yokken
  aquamarine hiç GPU bulamaz ve Hyprland açılmaz. Çare reboot ya da
  `sudo udevadm trigger --subsystem-match=drm --action=change && sudo udevadm settle`
  → `hypr-igpu → card1`, `hypr-dgpu → card0` (doğrulandı).
- **`hyprctl keyword` YOK** Lua config'te ("keyword can't work with non-legacy
  parsers. Use eval."). Çalışma anı ayarı = `hyprctl eval 'hl.config({…})'`;
  dispatch = `hyprctl dispatch 'hl.dsp.…'`.
- **`pkill -x waybar` hiçbir şey bulmaz**: nixpkgs sarmalayıcısı yüzünden süreç adı
  `.waybar-wrapped` (COSMIC'teki `pgrep -x` tuzağının aynısı). Sinyal
  `systemctl --user kill --signal=SIGRTMIN+8 waybar.service` ile.
- **Fn+F4 mikrofonu Hyprland çevirmez**: fn-bridge `--act` ile çeviriyor
  (`gnome_running()` yalnız GNOME'u ayırıyor). `XF86AudioMicMute` bind'i yalnız OSD
  gösterir — toggle eklenirse mikrofon aynı yere döner.
- **Copilot tuşu `F23`**: Hyprland bind'leri modifier'sız xkb durumundan çözer
  (`KeybindManager.cpp m_xkbTranslationState`) → Level 1. `XF86Assistant` sessizce boşa düşer.
- **`Hyprland --verify-config` gerçekten denetliyor**: negatif testte uydurma kural
  alanı, bilinmeyen config anahtarı ve hatalı dispatcher argümanı yakalandı. Config
  değişince: HM dosyalarını bir dizine kopyala,
  `XDG_CONFIG_HOME=<dizin> Hyprland --verify-config -c <dizin>/hypr/hyprland.lua`.

### Kısayollar

| Kısayol | İş |
|---|---|
| SUPER+Enter / Space / E / B | ghostty / başlatıcı / nautilus / zen |
| SUPER+Q | pencereyi kapat (Claude sesli asistanında: gizle) |
| SUPER+F / SHIFT+F | tam ekran / maximize (bar görünür) |
| SUPER+T / P / C | yüzdür / her alana iğnele / ortala |
| SUPER+J / G / Tab | bölünme yönü / sekmeli grup / grupta sonraki |
| ALT+Tab | pencereler arasında dön |
| SUPER+ok / SHIFT+ok / CTRL+ok | odak / taşı / boyut |
| SUPER+1..0 / SHIFT / CTRL | alana git / pencereyle git / sessizce gönder |
| SUPER+ALT+← → , SUPER+tekerlek | önceki/sonraki alan |
| SUPER+\` / SHIFT+\` , 3 parmak yukarı | karalama alanı / oraya gönder |
| 3 parmak yatay | alan değiştir |
| SUPER+ALT+Space | dwindle ↔ scrolling düzen |
| SUPER+F1 | odak kipi (boşluk/blur/animasyon kapalı) |
| SUPER+L / Escape | kilit / güç menüsü |
| SUPER+V / N / SHIFT+N / SHIFT+C | pano / rahatsız etme / gece ışığı / renk seçici |
| Print / SHIFT / ALT / SUPER+Print | bölge / ekran / pencere / satty ile işaretle |
| SUPER+SHIFT+S | bölge → pano + dosya |
| SUPER+SHIFT+F23 (Copilot) | Claude sesli asistan aç/kapa (aşağıda) |

### Copilot tuşu → Claude sesli asistan (4 Eki 2026)

macOS'taki Quick Entry pop-up'ının karşılığı. Tuş ekranın altından küçük bir hap
getirir ve claude.ai sesli modunu kendisi başlatır (mikrofon açık gelir); Claude'un
cevabı okumaya değerse hapın üstünde bir sohbet penceresi kendiliğinden açılır.
İkinci basış sesli modu durdurur, ikisini birlikte aşağı indirip gizler
(`special:claude-voice`). Kod: `home/desktop/hyprland/claude-voice/`, tuş ve
geçişler `lua/voice.lua`, kurallar `rules.lua` "claude-voice" / "claude-voice-chat",
servis `session.nix` `claude-voice.service`.

**Hız:** tuşa basınca süreç doğmaz. `binds.lua` doğrudan `claude_voice_toggle()`'ı
(Lua, Hyprland'in içinde) çağırır: pencere aynı karede hareket etmeye başlar (ölçüm:
çağrı ~10 ms, ilk hareket ≤20 ms; açılış 0,67 sn, kapanış 0,44 sn) ve soket2'ye
`custom>>claude-voice show|hide` yayılır. Arka plandaki servis (oturumla açılır,
Chromium gizli alanda claude.ai yüklü bekler) olayı duyup sesli modu açar/kapatır.
Servis yokken basılırsa Lua onu başlatır, hap doğunca gösterir; servis hazır olunca
hap görünürse sesli modu kendisi açar. Boşta ~790 MiB, işlemci %0 (açılıştan sonraki
ilk ~1 dk claude.ai ısınırken birkaç %).

| Parça | İş |
|---|---|
| `voice.py --daemon` | servis: Chromium'u başlatır, `session.js`'i enjekte eder, soket2 olaylarıyla sesli modu CDP üzerinden açar/kapatır (son istek kazanır), sayfanın sohbet penceresi ve genişlik haberlerini `claude_voice_chat()` / `claude_voice_width()`'e iletir |
| `panel.css` + `panel.js` | uzantı: sayfayı tek düğmelik haba indirir (kapalı: ses simgesi 48px, bağlanırken "Cancel" 110px, açık: "Stop" 95px), pencereyi kutu rengine boyar, hap genişliğini CSS geçişi için verir ve hedef pencere genişliğini (hap + 68) `<html data-cv-width>`'e yazar, durum ışıması |
| `session.js` + `chat.css` | sayfanın ana dünyasında: durumu okur, sohbet penceresini (about:blank popup) açıp mesajları claude.ai stilleriyle aynalar, genişleme kararını verir, genişliği servise iletir |
| `lua/voice.lua` | `claude_voice_toggle` (tuş), `claude_voice_chat`, `claude_voice_width`, `claude_voice_close` (SUPER+Q), `claude_voice_tween`: pencere konumu, saydamlığı ve hapın genişliği kare kare, getir/götür/sabitle |

- **Durum:** mesaj kutusunun yer tutucusundan (`Connecting... / Listening... /
  Processing... / Claude is speaking...`; boşsa kullanıcı konuşuyor). Hapın kutusu
  içe doğru ışır: dinliyor beyaz nefes, duyuyor hızlı beyaz nabız, düşünüyor dönen
  turuncu kenar, konuşuyor turuncu nabız. Sohbet penceresinin başlığında Türkçe yazı.
- **Sohbet penceresi:** cevabın gövdesi 280 karakteri (≈15 sn konuşma) geçerse ya da
  kod/tablo/liste/bağlantı/görsel varsa açılır. Hapın koyu kutusuna tıklamak elle
  aç/kapa; elle kapatılan cevap tekrar açtırmaz. Konuşurken karaoke: söylenen kelime
  parlar (claude.ai'nin kendi `text-muted → text-primary`'si), liste o kelimeyi üst
  üçte birde tutar; tekerlekle kaydırınca takip 6 sn durur. Sesli modda Claude kod ve
  tabloyu genelde reddediyor ("metin sohbetine geçelim mi?"), asıl tetik uzunluk.
- **Hap penceresi = koyu kutu.** Chromium saydam pencere ÇİZMİYOR (Wayland'de de):
  sayfa saydam bırakılınca altında sayfanın varsayılan zemini (#121212, koyu tema) ve
  onun altında çerçeve rengi (#403B3B) görünüyor. Eski düzende pencere sabit 180×86,
  kutu içinde CSS ile büyüyordu; kutunun iki yanında 8–30px koyu şerit kalıyordu
  ("siyah barlar", 4 Eki 2026). Şimdi sayfa zemini, CDP
  `Emulation.setDefaultBackgroundColorOverride` (servisin bağlantısı açık kaldıkça
  geçerli) ve kutu aynı renk (rgb 32,32,31); kutu pencerenin tamamı, köşeleri Hyprland
  yuvarlar (`rounding 14`). Düğme büyüyüp küçülünce pencere de merkezi sabit kalarak
  700 ms easeInOutCubic ile boyutlanır (116 kapalı · 178 Cancel · 163 Stop). Merkez
  kesirli tutulur, yoksa her aç-kapada hap 1 px kayıyordu. Eskiden "Chromium
  boyutlandırılınca ~150 ms koyu dikdörtgen çiziyor" diye boyut hiç değiştirilmiyordu:
  koyu dikdörtgen bu varsayılan zemindi. Renkler eşitlenince 60 fps kayıtta düğme
  merkezden en çok 1–2 px kayıyor; yalnız açılışın ilk birkaç karesinde (sayfa sesli
  modu başlatırken meşgul) kutunun kenarı pencerenin gerisinde kalıyor. Sohbet ayrı
  bir pencere ve boyut değiştirmez.
- **Geçişler:** açılış ekranın altından 750 ms easeOutCubic; kapanış 420 ms easeIn,
  iki pencere aynı mesafeyi kayar; sohbet penceresi 28px kayıp belirir. Hyprland'in
  kendi animasyonu bu pencerelerde kapalı (`no_anim`: genel ve hızlı, yavaşlatmak bütün
  pencereleri etkiler). Gizleme Lua'da geçiş bitince yapılır: `hl.timer` 6 ms istenince
  ~7.5 ms tıklıyor, sabit süre bekleyen betik pencereyi yolda söndürüyordu.
- **Servis sağlamlığı:** Chromium kendini D-Bus ile kendi scope'una taşıyor
  (`app-org.chromium.Chromium-*.scope`): servis cgroup'uyla ölmez — servis SIGTERM'i
  yakalayıp kapatır, açılışta bu profili kullanan artıkları (`/proc/*/cmdline`;
  Chromium başlığı boşluklu tek dizgiye çeviriyor, `\0` ile bölme işe yaramaz)
  öldürür. Yoksa yeni Chromium eskisine devredip çıkıyor, eski süreç ikinci bir hap
  penceresi açıyordu. Açılışta `Default/Sessions` silinir, çıkış "Normal" işaretlenir
  (oturum geri yükleme eski pencereleri getiriyordu). Tek örnek kilidi
  (`/claude-voice.lock`, çıkış 75 = `RestartPreventExitStatus`) ve
  yeniden bağlanırken tarayıcı kimliği kontrolü: iki örnek aynı sayfayı yönetmesin.
  Oturum betiği gözlemcileri `document`'a bağlar, `<html>`'e değil — claude.ai
  yüklenirken kök öğeyi değiştirebiliyor, durum "connecting"te donuyordu.
  Pencereler gizli alanda doğduğu için Chromium kendini görünmez sayıp (`document.hidden`)
  hiç kare üretmiyordu: tuşa basınca pencere geliyor ama içi boş kalıyordu.
  Odaklamak, sabitlemeyi kaldırmak ve Hyprland `render_unfocused` düzeltmedi;
  `--disable-backgrounding-occluded-windows --disable-renderer-backgrounding
  --disable-background-timer-throttling` düzeltti (boştaki işlemci yine %0).
  CDP binding'i için `Runtime.enable` şart: yoksa `claudeVoice` yalnız bağlanılan
  andaki belgeye kurulur; claude.ai açılışta kendini yeniden yükleyince sayfanın
  hiçbir haberi (sohbet, genişlik) servise ulaşmıyordu.
  Hap penceresi kapatılırsa sayfa da gider: SUPER+Q bu pencerede kapatmak yerine
  gizler (`claude_voice_close`). Başka yolla kapanırsa servis sekmeyi 1,5 sn bekleyip
  çıkar, systemd 1 sn sonra yeniden başlatır (eskiden 60 sn bekliyordu ve o arada
  Copilot tuşu hiçbir şey açmıyordu); bu arada basılan tuş yeni hap doğunca açar.
- **Neden Claude Desktop değil:** Quick Entry kodda yalnız macOS'a açık; uygulama
  `--remote-debugging-port`'u engel listesiyle reddediyor. Yerine ayrı profilli
  Chromium `--app` (`~/.local/share/claude-voice/chromium`, bir kez giriş), CDP portu
  9333 yalnız 127.0.0.1. Sesli mod `Input.dispatchMouseEvent` ile açılır — URL
  parametresi / kısayol yok, JS `.click()` sayılmıyor. `--disable-popup-blocking`:
  sohbet penceresi kullanıcı hareketi olmadan açılabilsin.
- **Tuzaklar:** Wayland app_id `--app` adresinden türer (`chrome-claude.ai__new-Default`,
  `--class` yok sayılır); iki pencere aynı sınıfta, sohbet penceresi `initial_title`
  "about:blank" ile ayrılır. claude.ai'nin "hareketi azalt" ayarı
  (`data-reduce-motion="true"`) bütün animasyonları 0.01ms'ye eziyor ve uzantı stili
  yenemiyor — `panel.js` yalnız bu sayfada kapatır. `innerText` hap sayfasında boş
  (`visibility:hidden`), `textContent` kullan. Kopyada animasyonlar baştan başlıyor
  (`message-fade-up` metni konuşma boyunca gizliyordu), yazarken satır içi dev
  `min-height` (3420px) ve mutlak konumlu 256px yıldız listeyi uzatıyor — `chat.css` /
  `session.js` temizler. Karaoke yalnız `class` değiştirir: gözlemci `class`'ı da dinler.
  "Açık mı" ölçütü Stop düğmesi (`voice-audio-visualizer` sesli mod bitince de kalıyor);
  Stop'un metni `StopStop`. Seçiciler claude.ai DOM'una bağlı — site değişirse
  bozulacak yerler `panel.css`, `chat.css`, `session.js`, `voice.py`.
- **Test:** `--use-fake-device-for-media-stream --use-file-for-fake-audio-capture=x.wav%noloop`
  ile espeak-ng'nin okuduğu soru mikrofona verilip uçtan uca denendi (her deneme
  hesapta bir sohbet açar). Servisi durdur, kopyasını bayraklarla başlat:
  `systemd-run --user --unit=claude-voice-test --setenv=CLAUDE_VOICE_EXTRA_FLAGS="…"
  <claude-voice> --daemon`; tuş yerine `hyprctl eval 'claude_voice_toggle()'`.
  Pencere eşlenmeden basma: hap yoksa Lua GERÇEK servisi başlatır.
  `--use-fake-ui-for-media-stream` KULLANMA: Chromium uyarı çubuğu 86px'lik hapı
  kaplıyor.

### Doğrulama — switch + Hyprland'e giriş sonrası (canlı test bekliyor)

Build, iki eval, statix/deadnix ve `--verify-config` geçti; switch 3 Eki 2026'da yapıldı.
GNOME tarafı canlı doğrulandı: GNOME oturumundayken waybar, mako, hypridle, hyprpaper,
cliphist, hyprpolkitagent, hyprsunset hepsi `inactive`; `org.freedesktop.Notifications`
sahibi gnome-shell; greeter'da dört girdi. Aşağıdakiler Hyprland'e girince yapılacak.

```bash
# 0) GÜVENLİK AĞI: ilk girişte Ctrl+Alt+F3'te bir TTY açık kalsın.
#    Kilit testi: SUPER+L → parola. Takılırsa TTY'den:
#    hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'   (allow_session_lock_restore)

# 1) servisler doğru hedefte mi, GNOME'a sızıyor mu
systemctl --user list-dependencies wayland-session@hyprland.desktop.target
#    GNOME'a dönünce:  systemctl --user is-active waybar mako hypridle  → inactive
#                      busctl --user status org.freedesktop.Notifications | grep -i comm  → gnome-shell

# 2) aquamarine hangi kartları açtı — card1 (iGPU) birincil, card0 (dGPU) yalnız HDMI için
#    PID'i hyprctl'den al: comm sarmalayıcı yüzünden kırpılmış (.Hyprland-wrapp),
#    `pgrep -f Hyprland` ise uwsm'in komut satırını da yakalar.
ls -l /proc/$(hyprctl -j instances | jq '.[0].pid')/fd | grep -o '/dev/dri/[a-zA-Z0-9]*' | sort | uniq -c
#    dGPU'nun o an uyanık olup olmadığını bar'daki 󰢮 göstergesi söyler.

# 3) AC/pil: fişi çek → hyprctl monitors | grep -A1 eDP-1  → @60, tak → @165

# 4) bar: fan çekmecesine tıkla → mod değişir (Fn+F7 ile aynı servis); SUPER+N → zil ikonu

# 5) xlsclients → yalnız steam/steamwebhelper
```

---

## Terminal açılışı — fastfetch ve starship

Kod: `home/shell/starship.nix` (starship + fastfetch; fish ve bash açılış blokları).
Kodun yanında kalan uyarılar: `type = "data"`, `''…''` güvenliği, baştaki/sondaki
`break`'in dikey ortalama görevi.

### Logo ve yerleşim tarihçesi (29 Tem – 2 Eyl 2026)

- **Logo:** elle çizilmiş Berserk damgası oturmadı → 29 Tem'de builtin `nixos_small`;
  2 Eyl 2026'da "nixos YAZAN" ASCII wordmark: figlet `slant` fontu (pinli nixpkgs).
- **Yerleşim "A"** (2 Eyl 2026, kullanıcı seçimi): 18 satırlık kutu çizgili panel, 5
  satırlık wordmark'ın yanında dengesizdi.
- **Topluluk taraması** (fastfetch Discussion #971 + dotfiles): ya sanat panel boyuna
  uzatılıyor, ya kısa sanatla panel kısaltılıp çerçeve atılıyor ve `break` ile dikey
  ortalanıyor (ashish0kumar deseni). **İkincisi seçildi**: `{#separator}│ …` önekleri ve
  `╭╰` satırları gitti, anahtar yalnız Nerd Font ikonu.

### fish açılışı ve SHLVL guard'ı — ölçüm (2 Eyl 2026)

2 Eyl 2026'ya kadar yalnız bash bloğu vardı; giriş kabuğu fish olduğu için fastfetch
sessizce hiç çalışmıyordu. fish bloğunda bash'in `SHLVL -eq 1` guard'ı **bilerek
taşınmadı**. Ölçüm (fish 4.8.1):

| durum | bash | fish |
|---|---|---|
| SHLVL yokken | 1 | BOŞ |
| SHLVL=1 iken | 2 | 1 |
| iç içe | — | 1 (hiç artmıyor) |

fish SHLVL'i yalnız miras alır; guard iç içe fish'i yakalayamaz, SHLVL tanımsızken de
`test "" -eq 1` hata verip fastfetch'i susturur. Gerçek terminallerde (cosmic-term,
ghostty) değer 1'di (SDDM döneminde ölçüldü; GDM'de yeniden ölçülmedi — guard olmadığı
için fastfetch'i etkilemez).
