-- Kısayollar — GNOME kas hafızası korunur (gnome-hm.nix ile bire bir:
-- Enter/Q/M/V/1-9/Copilot). Tema motoru SUPER+T'de.

local mod      = "SUPER"
local terminal = "ghostty"

------------------------
---- UYGULAMALAR -------
------------------------

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + D",      hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(mod .. " + Q",      hl.dsp.window.close())

-- Copilot tuşu → Claude Desktop (libinput ile doğrulanan kod: Meta+Shift+F23)
hl.bind(mod .. " + SHIFT + F23", hl.dsp.exec_cmd("claude-desktop"))

------------------------
---- TEMA MOTORU -------
------------------------

-- Otonom tema değiştirici (bkz. docs/hyprland-rice.md):
-- SUPER+T       → rofi grid'den duvar kağıdı seç → swww + matugen zinciri
-- SUPER+SHIFT+T → rastgele duvar kağıdı + tema
hl.bind(mod .. " + T",         hl.dsp.exec_cmd("wallpaper-picker"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("theme-apply --random"))

------------------------
---- SİSTEM ------------
------------------------

-- Bildirim paneli (GNOME'daki SUPER+V toggle-message-tray eşleniği)
hl.bind(mod .. " + V", hl.dsp.exec_cmd("swaync-client -t -sw"))

-- Fan modu döngüsü 0→1→2→5 — polkit kuralı şifresiz izin verir
-- (bkz. modules/hardware/gigabyte-wmi.nix; Fn+F7 EC'de yutulduğu için OS
-- tarafında SUPER+M kullanılıyor)
hl.bind(mod .. " + M", hl.dsp.exec_cmd("systemctl start --no-block fan-mode-cycle.service"))

-- Oturumdan çık (GDM'ye döner)
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch exit"))

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
---- MULTİMEDYA --------
------------------------

-- locked: kilit ekranında da çalışır; repeating: basılı tutunca tekrar
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })
