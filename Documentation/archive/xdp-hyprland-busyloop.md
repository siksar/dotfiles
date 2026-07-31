# xdg-desktop-portal-hyprland — epoll busy-loop (2 çekirdek 7/24)

**Not (2026-07-30):** Kök sebep olarak teşhis edilen `modules/desktop/sway-rice/`
(ve GNOME) bu tarihte repodan kaldırıldı — tek oturum artık Hyprland. Bu dosya
tarihsel bir kanıt/yatırım günlüğü olarak kalıyor; aşağıdaki dosya yolları
(`sway-rice/system.nix` vb.) artık repoda yok, ama olayın teşhis mantığı ve
`xdg.portal.wlr` global-kapsam dersi gelecekte benzer bir sızıntıyla
karşılaşılırsa hâlâ geçerli.

**Durum (2026-07-27, ikinci oturum sonrası):** Tetikleyici **repo tarafında lokalize
edildi** (Sway rice'ın `xdg.portal.wlr.enable = true` global ayarı, Hyprland/GNOME
oturumlarına sızıyor) ve düzeltme uygulandı — ayrıntı aşağıda "2026-07-27 oturumu"
bölümünde. Ama **doğrudan mekanik repro başarısız oldu**: dört farklı abrupt-kill
denemesi (2 kod yolu × 2 durum) hiçbirinde spin üretmedi. Düzeltme, güçlü **korelasyonel**
kanıta dayanıyor (3/3 boot eşleşmesi + closure diff), kanıtlanmış bir mekanizmaya değil.
Bu, aşağıdaki gibi okunmalı: **kök sebep büyük olasılıkla doğru teşhis edildi, ama "neden
bu spesifik teşhis" sorusunun son adımı (xdph canlı yayın sırasında ölürse ne olur)
hâlâ açık** — modifier-negotiation bug'ı (aşağıda) bu son adımı test etmeyi engelledi.

**Bu doküman bir plan değil, bir kanıt dosyasıdır.** İlk bölüm (Ortam→İlgili dosyalar
öncesi) gerçek, tek seferlik bir olaydan (26–27 Tem 2026) toplandı; olay o gün kapandığı
için bazı kanıtlar (strace, canlı fd durumu) o oturumda tekrar toplanamadı. İkinci oturum
(27 Tem, aynı gün) bilerek yeniden tetikleme denemeleri yaptı — sonuçları kendi bölümünde.

---

## Belirti

Kullanıcının şikayeti: "işlemcim sürekli 5 GHz core çalışıyor."

Gerçekte iki ayrı sorunun toplamıydı:

1. **Bu doküman (A):** `xdg-desktop-portal-hyprland` 2 çekirdeği kesintisiz meşgul
   ediyordu → amd-pstate haklı olarak o çekirdekleri boost'a çıkarıyordu.
2. **Ayrı sorun (B), 2026-07-27'de düzeltildi:** PPD/systemd sıralama döngüsü yüzünden
   EPP boot'ta `performance`ta kalıyor, boştaki 8 çekirdek 3465 MHz'e çivileniyordu.
   Düzeltmesi `modules/hardware/power-display.nix` içinde (`ppd_apply` + `graphical.target`).
   **A ile B'nin hiçbir nedensel ilişkisi yok** — aynı anda ortaya çıkmaları tesadüf.

Bu, `4.28W idle bütçesi` hard-constraint'ini doğrudan deliyordu: 2 çekirdek saatlerce
boost'ta. Bütçe için bkz. `CLAUDE.md` → "Power management".

---

## Ortam

| Bileşen | Değer |
|---|---|
| Paket | `xdg-desktop-portal-hyprland` **1.4.0** (`/nix/store/28529m1v2l6y4x8mljdh3xswmdhrg09p-…`) |
| Compositor | Hyprland **0.56.0** (CLAUDE.md "0.55" diyor — drift, ayrıca düzeltilmeli) |
| Oturum | opt-in Hyprland rice, `rice.hyprland.enable = true` |
| Portal paketi nereden | sistemden (`programs.hyprland`); rice'ta `portalPackage = null` (`hyprland-rice/hm.nix:258`) |
| PipeWire | pid 2415 |
| ptrace | `kernel.yama.ptrace_scope = 1` → **kullanıcı olarak strace attach edilemiyor**, root gerekiyor |

---

## Ölçümler

### 1. Bunun bir regresyon olduğu — systemd'nin kendi CPU muhasebesi

`journalctl --user -u xdg-desktop-portal-hyprland.service` içindeki
"Consumed … CPU time over … wall clock time" satırları:

| Boot | Wall clock | Tüketilen CPU | Oran |
|---|---|---|---|
| 25 Tem | 9s 46dk 50sn | **1,041 saniye** | ~%0 ✅ sağlıklı |
| 26 Tem 00:21 → 01:12 | 50dk 34sn | **1s 12dk 27sn** | **%143** ❌ |
| 26 Tem 12:58 → 27 Tem 00:0x | ~11 saat | **~19,25 saat** | **%175** ❌ |

Aynı binary 25 Tem'de 10 saatte 1 saniye CPU yiyordu. **26 Tem'deki reboot'tan sonra
patladı.** Yani paket sürümüne değil, o boot'ta oluşan bir duruma bağlı.

### 2. Yükün çekirdekte olduğu — `/proc/2676/stat`

```
utime = 19.735 s   (kullanıcı alanı)
stime = 50.063 s   (ÇEKİRDEK)      → zamanın %72'si kernel'de
```

Userspace hesap döngüsü değil, **syscall fırtınası**.

### 3. Döngü hızı — `/proc/2676/status`

```
voluntary_ctxt_switches: 7.311.972.062   → 2 saniye sonra: 7.312.366.200
                                            fark: +394.138 / 2 sn
```

**≈ 197.000 gönüllü bağlam değişimi / saniye.** Gönüllü ctxt switch = thread bir
bloklama syscall'ında bloklanıyor. Yani bloklaması gereken bir syscall **anında
dönüyor**, saniyede 197 bin kez. Toplam 7,3 **milyar** — tek boot'ta.

İki thread spin'de: 2676 (ana, %82) + 2688 (%99). Toplam %175–182.

### 4. Hangi fd — `/proc/2676/fdinfo/{8,10,14}` (üç epoll instance)

```
--- epoll fd 8 ---
tfd:  9  events: 19  data: 5941cef04ea0   ino:41c  sdev:11   → eventfd
tfd: 17  events: 19  data: 5941cef3e8a0   ino:4f05 sdev:a    → SOCKET
tfd: 12  events: 19  data: 5941cef0d640   ino:41c  sdev:11   → eventfd
--- epoll fd 10 ---
tfd: 11  events: 19                                          → eventfd
--- epoll fd 14 ---
tfd: 15  events: 19                                          → eventfd
```

`events = 0x19` = `EPOLLIN | EPOLLERR | EPOLLHUP`.

### 5. fd → karşı uç eşlemesi (`/proc/2676/fd`, `/proc/net/unix`, `ss -xp`)

| fd | Tür | Karşı uç |
|---|---|---|
| 3 | socket:[20217] | `dbus-broker` pid 1966 fd 63 |
| 7 | socket:[20218] | **peer inode `0` — karşı uç YOK (kapanmış)** |
| 13 | socket:[20225] | peer 25734 |
| **17** | socket:[20229] | **`pipewire` pid 2415 fd 66** ← epoll fd 8'de izleniyor |
| 18 | `/dev/shm/wlroots-fLNANK` | **(deleted)** — yıkılmış screencopy tamponu |
| 19,20,21 | `/dev/dri/renderD128` | iGPU render node |
| 1,2 | socket:[20215] | journald |

Ayrıca: olay sırasında `pw-cli ls Node | grep -i screen/capture/portal` **boş** —
yani **aktif hiçbir screencast oturumu yokken** dönüyordu.

---

## Mekanizma (kanıtlanan kısım)

Bir ekran yakalama/paylaşma oturumu başlamış, sonra sona ermiş:
- wlroots tarafındaki shm tamponu silinmiş (fd 18 `(deleted)`),
- fd 7'nin karşı ucu tamamen kapanmış (peer inode 0),
- ama **fd 17 (PipeWire soketi) hâlâ epoll fd 8'de kayıtlı** ve sürekli hazır
  (`EPOLLIN` ve/veya `EPOLLERR|EPOLLHUP`) rapor ediyor.

Portal bu fd'yi ne **drain** ediyor ne de `EPOLL_CTL_DEL` ile düşürüyor →
`epoll_wait` her çağrıda anında dönüyor → sonsuz döngü.

Bu, klasik "hangup'a bakmayan event loop" hatası. `stime` baskınlığı, 197k/s ctxt
switch ve `EPOLLERR|EPOLLHUP` maskesi birlikte bu tabloyu tek başına açıklıyor.

### Doğrulayıcı test (yapıldı)

```
systemctl --user restart xdg-desktop-portal-hyprland.service
```

| | PID | CPU |
|---|---|---|
| önce | 2676 | **%177**, loadavg 2.84 |
| sonra (41 sn) | 83054 | **0 saniye CPU**, loadavg 2.56 |

Yeniden başlatma sonrası tekrar patlamadı (30 sn gözlem). Portal on-demand olarak
`xdg-desktop-portal` tarafından yeniden ayağa kaldırıldığı için oturum etkilenmedi.

---

## 2026-07-27 oturumu: repo-taraflı kök neden + repro girişimleri

### Doğal deney — jenerasyon 105→106 sınırı

`journalctl --list-boots` + `nix store diff-closures`, üç boot'u jenerasyonlarla eşledi:

| Boot | Jenerasyon (oluşturulma) | `xdg-desktop-portal-wlr` | xdph sağlığı |
|---|---|---|---|
| 25 Tem 14:33 → 26 Tem 00:20 (9s47dk) | 105 (25 Tem 17:29) | **hiç başlamadı** | ✅ 1.041s CPU |
| 26 Tem 00:21 → 01:12 | 106 (**26 Tem 00:20** — bu boot'tan 13sn önce) | 00:21:50'de xdph ile **aynı saniye** başladı | ❌ %143 |
| 26 Tem 12:58 → 27 Tem 00:2x | 106 | 12:58:56'da başladı | ❌ %175 |

`nix store diff-closures system-105-link system-106-link`: pipewire, hyprland, xdph
**değişmedi**; portal ile ilgili tek delta `xdg-desktop-portal-wlr 0.8.3`'ün eklenmesi
(Sway rice, jenerasyon 106'da devreye girdi — bkz. commit `adab707`).

**Kök sebep, repo tarafında:** `modules/desktop/sway-rice/system.nix`'teki
`xdg.portal.wlr.enable = true` **global** bir NixOS opsiyonu — `mkIf cfg.enable` içine
yazılması onu Sway'e kapsamıyor. Kurduğu `xdg-desktop-portal-wlr.service` yalnızca
`ConditionEnvironment=WAYLAND_DISPLAY` ile korunuyor (masaüstü koşulu yok), yani her
Wayland oturumunda (GNOME, Hyprland) da kurulu duruyor. `WLR_DRM_DEVICES`'ın
Hyprland/GNOME'a sızmaması için zaten `programs.sway.extraSessionCommands`'a scoped
edildiği aynı ders, portal katmanında tekrarlanmamış.

### Upstream #411 ELENDİ

hyprwm/xdg-desktop-portal-hyprland#411 ("Infinite CPU loop … triggered by
Screenshot/ScreenCast"), 21 Tem 2026'da kapandı — bizim olaydan 5 gün önce. Ama 4 bağımsız
uyuşmazlık var: #411'de ~10GB/24s bellek sızıntısı var, bizde 11.6M tepe; #411'de portal
restart **düzeltmiyor**, bizde düzeltti; #411'in döngüsü `xdg-desktop-portal`'ın kendisinde
(dbus/color-scheme gevezeliği), bizimki `…-hyprland`'da; #411 userspace döngüsü (yüksek
utime), bizimki %72 stime (kernel). **Ayrı bir sınıf hata.**
([kaynak](https://github.com/hyprwm/xdg-desktop-portal-hyprland/issues/411))

### Yan bulgu 1 — wlr portal'ın seçici mekanizması sistemde hiç çalışmıyor

`xdg-desktop-portal-wlr`'ın output seçici için hardcoded fallback listesi (`slurp, wmenu,
wofi, rofi, bemenu, mew, fuzzel`) — sistemde **hiçbiri yok** (`which` hepsinde başarısız;
`fuzzel` kurulu ama systemd `--user` servisinin `PATH`'inde değil). Config dosyası
(`~/.config/xdg-desktop-portal-wlr/config`, `[screencast] output_name=… chooser_type=none`)
ile bypass edilebiliyor ama **hiçbir yerde böyle bir config yok**. Sonuç: **wlr portal'ın
ekran paylaşımı, Sway oturumu dahil, muhtemelen daha önce hiç çalışmadı.** Bu, Faz 2'nin
"bilinen bedeli"ni (Sway'de ekran paylaşımının kaybı) sıfıra indiriyor — zaten çalışmıyordu.

### Yan bulgu 2 — portal aggregator'ın "yapışkan" backend seçimi

`hyprland-portals.conf`: `[preferred] default=hyprland;gtk` — ScreenCast için hyprland'i
önceliklendirmesi gerekiyor. Ama `busctl --user monitor` ile canlı izlemede, gerçek bir
`CreateSession`/`SelectSources` çağrısı **wlr'a routing edildi** (config'te hiç adı
geçmemesine rağmen). Aggregator (`xdg-desktop-portal.service`, PID 2612, boot başından beri
hiç restart edilmemiş) muhtemelen ScreenCast için ilk çözümlediği backend'e "yapışıyor" ve
bunu `*-portals.conf` her değiştiğinde yeniden değerlendirmiyor. wlr `mask` edilip
aggregator restart edildiğinde routing doğru şekilde hyprland'e düştü. **Sonuç:** wlr
mevcut olduğu sürece, config ne derse desin, ScreenCast isteklerini fiilen o karşılıyor
olabilir — orijinal olayın 3/3 korelasyonuna makul bir tamamlayıcı mekanizma.

### Yan bulgu 3 — xdph'nin kendi DMA-BUF modifier bug'ı (AYRI hata, busyloop DEĞİL)

wlr `mask`lenip aggregator zorla xdph'e yönlendirildiğinde, `gpu-screen-recorder -w portal`
ile gerçek bir kullanıcı onayı (picker tıklaması) sonrası xdph PipeWire negotiation'ı
başlatıyor ama **DMA-BUF modifier'ı EGL image'a çeviremiyor**
(`failed to create egl image with modifier 0x2000000084abb04, renegotiating…` →
`no more input formats` → 5sn timeout → temiz teardown). Bu muhtemelen hibrit
AMD-iGPU/NVIDIA-dGPU DRM node kurulumuyla ilgili (bkz. `AQ_DRM_DEVICES`,
`hyprland-rice/CLAUDE.md`) — **spin ÜRETMİYOR** (temiz hata + timeout), ama xdph'nin
kendi ekran paylaşımını bu donanımda hiç tamamlayamadığını gösteriyor. Ayrı bir issue
olarak takip edilmeli, bu dokümanın kapsamı dışında.

### Repro girişimleri — SONUÇSUZ (4 deneme, spin YOK)

| # | Yol | Durum kill anında | Sonuç |
|---|---|---|---|
| 1 | wlr servis ediyor, tam canlı yayın (2560x1600, pipewire node 87, gerçek mp4 üretti) | `kill -9` yayın ortasında | Ne xdph ne wlr'da spin |
| 2 | xdph servis ediyor (wlr mask'li), `SelectSources` beklemede (picker açık, kimse onaylamadı) | `kill -9` | Spin yok |
| 3 | xdph servis ediyor, kullanıcı picker'ı gerçekten onayladı, ama modifier negotiation başarısız oldu | (gsr kendi kendine temiz kapandı, kill gerekmedi) | Spin yok |
| — | xdph'nin **sürdürülebilir canlı yayın sırasında** ölmesi (orijinal fd kanıtıyla — canlı pipewire + silinmiş shm tampon — birebir eşleşen tek durum) | **test edilemedi** | Modifier bug'ı bu duruma ulaşmayı engelliyor |

Kullanılamayan araçlar: `wtype`/`ydotool`/`wlrctl` yok (picker'ı programatik tıklayamadık,
kullanıcı bir kez elle onayladı ama modifier bug'ına çarpıldı); passwordless `sudo` yok
(strace/gdb kullanıcı elle çalıştırmalı — spin hiç oluşmadığı için gerekmedi).

**Sonuç:** Faz 2 düzeltmesi, kanıtlanmış bir mekanizma yerine güçlü korelasyonel kanıtla
ilerliyor. Tekrar olursa aşağıdaki "Tekrar olursa" bölümündeki komutlar hâlâ geçerli —
özellikle strace/gdb, bu oturumda da eksik kaldı.

---

## BİLİNMEYENLER — planın çözmesi gerekenler

İlk oturumda bilerek açık bırakıldı; ikinci oturum (27 Tem) hepsini araştırdı — durumları
güncellendi.

1. **Tetikleyici hangi uygulama? KISMEN AÇIKLANDI.** Hangi son-kullanıcı uygulamasının
   orijinal olayı başlattığı hâlâ bilinmiyor (vesktop/tarayıcı/OBS/1Password şüpheli
   listesi doğrulanmadı). Ama *mekanizma* artık anlaşılıyor: portal aggregator'ın
   "yapışkan" backend seçimi yüzünden (bkz. "Yan bulgu 2"), wlr mevcut olduğu sürece
   HERHANGİ bir uygulamanın ScreenCast isteği — `hyprland-portals.conf` ne derse desin —
   wlr üzerinden geçiyor olabilir. Spesifik uygulamayı bulmak artık düzeltme için gerekli
   değil; kök sebep uygulamadan bağımsız.

2. **Hangi kod yolu? HÂLÂ AÇIK.** İkinci oturumda da root strace/gdb alınamadı —
   bu kez neden farklı: spin **hiç oluşmadı** (4 abrupt-kill denemesi, bkz. "Repro
   girişimleri" tablosu), yani incelenecek canlı bir süreç olmadı. `ptrace_scope=1` +
   passwordless sudo yokluğu ikinci bir engel olarak duruyor.

3. **Üç epoll instance'ının hangisi kimin? HÂLÂ AÇIK.** Aynı sebeple (spin oluşmadı).

4. **Upstream'de bilinen bir hata mı? YANITLANDI — HAYIR.** #411 kontrol edildi ve
   4 bağımsız kanıtla elendi (bkz. yukarı "Upstream #411 ELENDİ"). Başka açık CPU
   issue'su yok (#416, #362, #319 — hepsi ya kapalı ya farklı senaryo).

5. **nixpkgs'te daha yeni sürüm var mı? İLGİSİZ HALE GELDİ.** `nix store diff-closures
   105 106` xdph'nin **değişmediğini** kanıtladı — regresyon sürümden gelmiyor, repo
   config'inden geliyor (wlr'ın eklenmesi). Sürüm sorusu düzeltmeyi etkilemiyor.

6. **Tekrarlanabilir mi? DENENDİ — HAYIR (4/4 deneme spin üretmedi).** Ayrıntı yukarıda
   "Repro girişimleri" tablosunda. En yakın eşleşen senaryo (xdph sürdürülebilir yayın
   sırasında ölürse) xdph'nin kendi modifier-negotiation bug'ı yüzünden test edilemedi.
   **Düzeltme, kanıtlanmış mekanizma yerine korelasyonel kanıtla ilerliyor** — bu
   dokümanın en üstündeki "Durum" satırı bunu netleştiriyor.

---

## Değerlendirilecek yönler (karar verilmedi)

Bunlar seçenek listesi, öneri değil. Plan bunları tartmalı.

- **Kök sebebi upstream'de çözmek** — repro + root backtrace → issue aç / yama yaz.
  En doğru, en yavaş. Yama gerekirse nixpkgs `overlay` ile `patches` eklenebilir.
- **Sürüm yükseltmek** — upstream'de düzeltildiyse en ucuz yol. Önce (4)/(5) yanıtlanmalı.
- **Tetikleyiciden kaçınmak** — hangi uygulama olduğu bulunursa o akışı değiştirmek.
- **Zarar sınırlama (semptom yaması)** — kullanıcı unit'ine `CPUQuota=` koymak ya da
  CPU eşiği aşınca restart eden bir watchdog. Kök sebebi **çözmez**, bütçeyi korur.
  Kalıcı çözüm gelene kadar köprü olarak düşünülebilir; tek başına kabul edilmemeli.

### Planın uyması gereken repo kısıtları

- `CLAUDE.md`: `modules/hardware/` ve rice altına eklenen hiçbir şey **idle'da koşmamalı /
  poll etmemeli** — 4.28W bütçesi. Bir watchdog düşünülürse bu kural doğrudan çarpar
  (timer = idle'da uyanma). Olay-tabanlı bir tetik tercih edilmeli.
- Hyprland rice opt-in ve **Sway rice ile kod paylaşmaz** (kullanıcı bağımsızlığı DRY'a
  tercih etti). Düzeltme rice'a özgüyse `modules/desktop/hyprland-rice/` içinde kalmalı.
- Rice'a dokunmadan önce `docs/hyprland-rice.md` + `hyprland-rice/CLAUDE.md` okunmalı.
- `nix run nixpkgs#…` kullanılmaz (registry'nin nixpkgs'ini çözer, flake'in pinini değil).
- Yorumlar ve commit mesajları Türkçe. `nixfmt` ağaç genelinde **asla** çalıştırılmaz.
- Doğrulama = `nixos-rebuild build` + `switch` + **ölçüm**; test paketi yok.

---

## Tekrar olursa: teşhis komutları

Bunlar bu olayda işe yarayan komutlar — olay tekrarlarsa **önce bunlar, sonra restart**
(restart kanıtı yok eder).

```bash
# 0) Tetikleyiciyi NOT ET: hemen öncesinde ne ekran paylaştın/yakaladın?
PID=$(pgrep -f xdg-desktop-portal-hyprland | head -1)

# 1) kullanıcı/çekirdek zaman dağılımı (stime baskınsa syscall fırtınası)
awk '{printf "utime=%.0fs stime=%.0fs\n", $14/100, $15/100}' /proc/$PID/stat

# 2) döngü hızı (2 sn arayla fark al)
grep voluntary_ctxt /proc/$PID/status; sleep 2; grep voluntary_ctxt /proc/$PID/status

# 3) epoll izleme listeleri — hangi fd, hangi maske (0x19 = IN|ERR|HUP)
for e in $(ls -l /proc/$PID/fd | grep eventpoll | awk '{print $9}'); do
  echo "--- epoll $e ---"; cat /proc/$PID/fdinfo/$e; done

# 4) fd → karşı uç (peer inode 0 = karşı uç ölmüş)
ls -l /proc/$PID/fd; ss -xp | grep "pid=$PID"

# 5) aktif screencast var mı
pw-cli ls Node | grep -iE 'screen|capture|portal'

# 6) EKSİK KANIT — root gerekiyor, mutlaka al:
sudo strace -c -f -p $PID   # 5 sn yeter; hangi syscall'ın döndüğünü kesinleştirir
sudo gdb -p $PID -batch -ex 'thread apply all bt'   # kod yolu için

# 7) ancak bunlardan SONRA:
systemctl --user restart xdg-desktop-portal-hyprland.service
```

---

## İlgili dosyalar

- `modules/desktop/sway-rice/system.nix` — **kök sebep burada**: `xdg.portal.wlr.enable`
  global opsiyonu, Hyprland/GNOME'a sızıyordu (27 Tem'de düzeltildi — bkz. commit geçmişi)
- `modules/desktop/hyprland-rice/system.nix` — portal'ı ekleyen yer
- `modules/desktop/hyprland-rice/hm.nix:258` — `portalPackage = null`
- `docs/hyprland-rice.md` — rice tasarım dokümanı
- `docs/sway-rice.md` — Sway'de ekran paylaşımının neden kapalı olduğu (27 Tem sonrası)
- `modules/hardware/power-display.nix` — B sorununun düzeltmesi (bu olayla karışmasın)
