-- Kısayollar. Tam liste: Documentation/desktop.md "Hyprland → Kısayollar".
--
-- `P` = Nix'in ürettiği store yolları (default.nix, nixpaths modülü). Betikler
-- home.packages'a girmez, buradan tam yoluyla çağrılır.
--
-- `app()` uygulamayı `uwsm-app` ile başlatır: her uygulama kendi systemd
-- scope'una (app-graphical.slice) düşer, compositor'ın cgroup'una değil — biri
-- çökerse ya da bellek yerse Hyprland'i sürüklemez. uwsm-app, `uwsm app`'in hızlı
-- istemcisi (Python başlatma gecikmesi yok).

local P   = require("nixpaths")
local mod = "SUPER"

local function app(cmd) return hl.dsp.exec_cmd("uwsm-app -- " .. cmd) end
local function run(cmd) return hl.dsp.exec_cmd(cmd) end
-- Başlatıcı arka planda hazır bekleyen bir servis (hypr-launcher, session.nix):
-- tuş soket2'ye olay yayar, süreç doğmaz. Kipler: apps | clip | power.
local function launcher(mode) return hl.dsp.event("hypr-launcher " .. mode) end

-------------------------------------------------------------------------------
-- UYGULAMALAR
-------------------------------------------------------------------------------

hl.bind(mod .. " + Return",      app("ghostty"))
hl.bind(mod .. " + space",       launcher("apps"))           -- ada başlatıcıya dönüşür
hl.bind(mod .. " + E",           app(P.files))               -- nautilus
hl.bind(mod .. " + B",           app("zen-beta"))
-- Copilot tuşu = Super+Shift+F23 akoru (desktop.md "Copilot tuşu" ölçümü).
-- Seviye tuzağı COSMIC'tekiyle aynı yönde çözülür: Hyprland bind'leri modifier'sız
-- bir xkb durumundan çözer (KeybindManager.cpp m_xkbTranslationState) → Level 1
-- = "F23". "XF86Assistant" yazılırsa tuş sessizce hiçbir şey yapmaz.
-- Tuş Claude sesli asistanını aç/kapa yapar: doğrudan Lua (lua/voice.lua), süreç
-- doğmaz — animasyon basılan karede başlar. Sesli modu arka plandaki
-- claude-voice.service (session.nix) açıp kapatır.
hl.bind(mod .. " + SHIFT + F23", function() claude_voice_toggle() end)

-------------------------------------------------------------------------------
-- OTURUM
-------------------------------------------------------------------------------

hl.bind(mod .. " + L",          run("loginctl lock-session")) -- → hypridle → hyprlock
hl.bind(mod .. " + Escape",     launcher("power"))
hl.bind(mod .. " + V",          launcher("clip"))             -- cliphist geçmişi
hl.bind(mod .. " + N",          run(P.dnd .. " toggle"))
hl.bind(mod .. " + SHIFT + N",  run(P.nightLight))
hl.bind(mod .. " + SHIFT + C",  run(P.colorPicker))           -- hyprpicker → pano

-------------------------------------------------------------------------------
-- PENCERE
-------------------------------------------------------------------------------

-- Claude sesli asistanının penceresi odaktaysa kapatmaz, gizler (lua/voice.lua):
-- kapatılan pencereyle arka planda hazır bekleyen sayfa da gider.
hl.bind(mod .. " + Q", function()
    if not claude_voice_close() then hl.dispatch(hl.dsp.window.close()) end
end)
hl.bind(mod .. " + F",          hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + SHIFT + F",  hl.dsp.window.fullscreen({ mode = "maximized" }))  -- bar görünür kalır
hl.bind(mod .. " + T",          hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",          hl.dsp.window.pin({ action = "toggle" }))         -- yüzen pencere her alanda
hl.bind(mod .. " + C",          hl.dsp.window.center())
hl.bind(mod .. " + J",          hl.dsp.layout("togglesplit"))                     -- dwindle
hl.bind(mod .. " + G",          hl.dsp.group.toggle())                            -- sekmeli grup
hl.bind(mod .. " + Tab",        hl.dsp.group.next())
hl.bind("ALT + Tab",            hl.dsp.window.cycle_next())

-- Odak / taşı / boyut: oklar. (hjkl yok: SUPER+L kilit, GNOME kas hafızası.)
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mod .. " + " .. dir,             hl.dsp.focus({ direction = dir }))
    hl.bind(mod .. " + SHIFT + " .. dir,     hl.dsp.window.move({ direction = dir }))
end
local step = 40
hl.bind(mod .. " + CTRL + left",  hl.dsp.window.resize({ x = -step, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x =  step, y = 0, relative = true }), { repeating = true })
hl.bind(mod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0, y = -step, relative = true }), { repeating = true })
hl.bind(mod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0, y =  step, relative = true }), { repeating = true })

-- Fare: SUPER + sol sürükle = taşı, sağ sürükle = boyutlandır
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-------------------------------------------------------------------------------
-- ÇALIŞMA ALANLARI
-------------------------------------------------------------------------------

-- SUPER+1..0 git, SUPER+SHIFT+1..0 pencereyle git, SUPER+CTRL+1..0 sessizce gönder
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.bind(mod .. " + " .. key,            hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,    hl.dsp.window.move({ workspace = i }))
    hl.bind(mod .. " + CTRL + " .. key,     hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mod .. " + grave",          hl.dsp.workspace.toggle_special("scratch"))
hl.bind(mod .. " + SHIFT + grave",  hl.dsp.window.move({ workspace = "special:scratch" }))
hl.bind(mod .. " + mouse_down",     hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",       hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + ALT + right",    hl.dsp.focus({ workspace = "r+1" }))
hl.bind(mod .. " + ALT + left",     hl.dsp.focus({ workspace = "r-1" }))

-------------------------------------------------------------------------------
-- DÜZEN — Lua fonksiyonu olarak bind (0.56'nın asıl kazancı)
-------------------------------------------------------------------------------

-- dwindle ↔ scrolling (niri tarzı yatay şerit). Yalnız bu oturumda geçerli;
-- `hyprctl reload` look.lua'daki "dwindle"a döndürür.
hl.bind(mod .. " + ALT + space", function()
    local now  = hl.get_config("general.layout")
    local next = (now == "dwindle") and "scrolling" or "dwindle"
    hl.config({ general = { layout = next } })
    hl.exec_cmd(P.notify .. " -a Düzen -e -t 1200 '󰕰  Düzen: " .. next .. "'")
end)

-- Odak kipi: boşluk/kenarlık/bulanıklık/animasyon kapalı — ekran paylaşımı,
-- sunum ya da düşük güçte ağır iş için. İkinci basış look.lua'ya döner.
local focusMode = false
hl.bind(mod .. " + F1", function()
    focusMode = not focusMode
    if focusMode then
        hl.config({
            general    = { gaps_in = 0, gaps_out = 0 },
            decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } },
            animations = { enabled = false },
        })
    else
        hl.config({
            general    = { gaps_in = 5, gaps_out = 10 },
            decoration = { rounding = 12, blur = { enabled = true }, shadow = { enabled = true } },
            animations = { enabled = true },
        })
    end
    hl.exec_cmd(P.notify .. " -a Hyprland -e -t 1200 '" ..
        (focusMode and "󰈈  Odak kipi açık" or "󰈉  Odak kipi kapalı") .. "'")
end)

-------------------------------------------------------------------------------
-- EKRAN GÖRÜNTÜSÜ — ~/Pictures/Screenshots + pano
-------------------------------------------------------------------------------

hl.bind("Print",                 run(P.screenshot .. " area"))
hl.bind("SHIFT + Print",         run(P.screenshot .. " screen"))
hl.bind("ALT + Print",           run(P.screenshot .. " window"))
hl.bind(mod .. " + Print",       run(P.screenshot .. " edit"))   -- satty ile işaretle
hl.bind(mod .. " + SHIFT + S",   run(P.screenshot .. " area"))   -- Windows kas hafızası

-------------------------------------------------------------------------------
-- DONANIM TUŞLARI — kilit ekranında da çalışır (locked)
-------------------------------------------------------------------------------

hl.bind("XF86AudioRaiseVolume",  run(P.osd .. " volume up"),     { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  run(P.osd .. " volume down"),   { locked = true, repeating = true })
hl.bind("XF86AudioMute",         run(P.osd .. " volume mute"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   run(P.osd .. " brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", run(P.osd .. " brightness down"), { locked = true, repeating = true })

-- Fn+F4: mikrofonu fn-bridge çeviriyor (--act), burada YALNIZ gösterge.
-- non_consuming: tuş uygulamalara da iletilsin (bazıları kendi göstergesini çizer).
hl.bind("XF86AudioMicMute",      run(P.osd .. " mic"), { locked = true, non_consuming = true })

hl.bind("XF86AudioPlay",  run(P.playerctl .. " play-pause"), { locked = true })
hl.bind("XF86AudioPause", run(P.playerctl .. " play-pause"), { locked = true })
hl.bind("XF86AudioNext",  run(P.playerctl .. " next"),       { locked = true })
hl.bind("XF86AudioPrev",  run(P.playerctl .. " previous"),   { locked = true })
