-- Kısayollar — eskiden GNOME'un dconf kısayollarıyla bire bir eşleşecek
-- şekilde seçildi (Enter/Q/M/V/1-9/Copilot); GNOME artık yok ama kas hafızası
-- kalıcı. Tema motoru SUPER+T'de.

local mod      = "SUPER"
local terminal = "ghostty"

------------------------
---- UYGULAMALAR -------
------------------------

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + Q",      hl.dsp.window.close())
-- SUPER+D artık uygulama başlatıcı DEĞİL — bkz. "SİSTEM" bölümü (dashboard'a
-- taşındı, launcher SUPER+SPACE'e geçti).

-- Copilot tuşu → Claude Desktop (libinput ile doğrulanan kod: Meta+Shift+F23)
hl.bind(mod .. " + SHIFT + F23", hl.dsp.exec_cmd("claude-desktop"))

------------------------
---- TEMA MOTORU -------
------------------------

-- Rastgele duvar kağıdı (Caelestia CLI zinciri: wallpaper → dynamic şema →
-- tüm enable* hedefleri). Eski görsel grid seçicinin (rofi wallpaper-grid)
-- karşılığı yok — launcher'ı SUPER+SPACE'le açıp ">wallpaper <ad>" yazmak
-- (actionPrefix varsayılanı ">") en yakın eşdeğer, elle kullanılır.
hl.bind(mod .. " + T", hl.dsp.exec_cmd("caelestia wallpaper -r"))

-- SUPER+W serbest kaldı — waybar'ın 16-tema seçicisi Caelestia'ya geçişte
-- kaldırıldı (tek bar, tema seçici yok).

------------------------
---- SİSTEM ------------
------------------------

-- Pano geçmişi (GNOME'daki SUPER+V eşleniği; eskiden bildirim paneliydi —
-- bildirim paneli artık SUPER+SHIFT+N, aşağıda "PENCERE DÜZENİ" dışında yok,
-- bkz. Caelestia sidebar). cliphist + fuzzel dmenu, CLI'ın kendi bağımlılığı.
hl.bind(mod .. " + V", hl.dsp.exec_cmd("caelestia clipboard"))

-- Uygulama başlatıcı (Caelestia launcher, doğal UX'i SUPER-release ama Lua
-- API'sinde bindrd/bindn desteği doğrulanmadı — basit SUPER+SPACE tutuldu;
-- bkz. rice/caelestia:modules/desktop/hyprland/binds.nix'teki launcherInterrupt
-- ikizi referansı, ileride eklenebilir).
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("caelestia shell drawers toggle launcher"))

-- Dashboard (performans/medya paneli — eskiden SUPER+D rofi launcher'dı,
-- launcher SUPER+SPACE'e taşındığı için bu tuş serbest kaldı).
hl.bind(mod .. " + D", hl.dsp.exec_cmd("caelestia shell drawers toggle dashboard"))

-- Bildirim/hızlı-ayarlar paneli (sidebar) — eski swaync panelinin eşleniği.
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd("caelestia shell drawers toggle sidebar"))

-- Fan modu döngüsü 4→1→2→5 — polkit kuralı şifresiz izin verir
-- (bkz. system/arch/aerox16/wmi.nix; Fn+F7 EC'de yutulduğu için OS
-- tarafında SUPER+M kullanılıyor)
hl.bind(mod .. " + M", hl.dsp.exec_cmd("systemctl start --no-block fan-mode-cycle.service"))

-- Klavye aydınlatması (HID LampArray — bkz. system/drivers/input/keyboard-rgb/).
-- Renk normalde Caelestia'nın tema motorundan gelir (postHook →
-- home/desktop/caelestia/default.nix); bunlar elle kontrol. Animasyon
-- idle'da ASLA dönmez, yalnız bu toggle ile başlar.
-- Z/X = animasyon, C/V = parlaklık (klavyede yan yana; C solda azaltır).
hl.bind(mod .. " + ALT + Z", hl.dsp.exec_cmd("kbd-anim breathe"))
hl.bind(mod .. " + ALT + X", hl.dsp.exec_cmd("kbd-anim rainbow"))
hl.bind(mod .. " + ALT + C", hl.dsp.exec_cmd("kbd-rgb bright -10"), { repeating = true })
hl.bind(mod .. " + ALT + V", hl.dsp.exec_cmd("kbd-rgb bright +10"), { repeating = true })

-- Oturumdan çık (ly'ye döner)
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch exit"))

-- Kilit ekranı (GNOME kas hafızası SUPER+L). Caelestia kendi kilidini
-- (WlSessionLock + PamContext) IPC ile sağlıyor — hypridle/hyprlock artık
-- yok, loginctl'e gerek kalmadı. GÜVENLİK: switch sonrası bunu ikinci bir
-- TTY açıkken test et (bkz. plan Faz 0).
hl.bind(mod .. " + L", hl.dsp.exec_cmd("caelestia shell lock lock"))

------------------------
---- PENCERE DÜZENİ ----
------------------------

-- SUPER+F = yüzen/döşeli geçişi (kullanıcı isteği, 2026-07-16 — eskiden
-- fullscreen buradaydı); fullscreen SHIFT'e taşındı.
-- fullscreen 1 = "maximize" (bar görünür kalır); tam ekran istersen 0 yap.
-- hl.dsp altında fullscreen sarmalayıcısının imzası 0.55 wiki'sinde henüz
-- doğrulanmadı → garantili yol: hyprctl dispatcher.
hl.bind(mod .. " + F",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 1"))
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit")) -- dwindle

-- Odak: SUPER + ok tuşları
hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Çalışma alanları: SUPER+1..9 geçiş, SUPER+SHIFT+1..9 taşıma
for i = 1, 9 do
    hl.bind(mod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }))
end

-- Fare: SUPER + sol tık sürükle = taşı, sağ tık sürükle = boyutlandır
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- SUPER + tekerlek: komşu çalışma alanları
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

------------------------
---- EKRAN GÖRÜNTÜSÜ ---
------------------------

-- Print: bölge seç (dondurulmuş ekran) + swappy ile düzenle (CLI'ın kendi
-- grim+swappy zinciri, -r bare "slurp" const'u ile picker'ı da tetikleyebilir
-- ama -f ile ekranı dondurmak seçimi kolaylaştırıyor). SHIFT+Print: tüm ekran.
-- SUPER+SHIFT+S: bölge → doğrudan panoya (openClip IPC'si, dosya yazmaz,
-- düzenleyici açmaz) — eski hypr-screenshot clipboard modunun birebir eşleniği.
hl.bind("Print",               hl.dsp.exec_cmd("caelestia screenshot -r -f"))
hl.bind("SHIFT + Print",       hl.dsp.exec_cmd("caelestia screenshot"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd("caelestia shell picker openClip"))

------------------------
---- MULTİMEDYA --------
------------------------

-- locked: kilit ekranında da çalışır; repeating: basılı tutunca tekrar
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
