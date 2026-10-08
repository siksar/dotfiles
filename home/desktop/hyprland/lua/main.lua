-- Hyprland 0.56 — çekirdek: monitör, giriş, davranış.
-- Görünüm look.lua'da, kısayollar binds.lua'da, kurallar rules.lua'da.
--
-- RENK YOK: gölge/arka plan renklerini Stylix yazar; HM'in ürettiği
-- hyprland.lua onu bu dosyaları require ettikten SONRA çağırır. Kenarlık kapalı.
-- Palet değişimi = lib/theme.nix, buraya dokunma.
--
-- API'nin tam tanımı: /run/current-system/sw/share/hypr/stubs/hl.meta.lua
-- (lua dizinindeki .luarc.json editöre bunu gösterir).

-------------------------------------------------------------------------------
-- MONİTÖRLER
-------------------------------------------------------------------------------

-- Panel eDP-1 2560x1600@165, ölçek 1 (GNOME'un monitors.xml'iyle aynı seçim).
-- Sabit tavan: fiş tak/çıkar tazelemeye DOKUNMAZ (4 Eki 2026, kullanıcı isteği).
-- Gerçek tazeleme VRR'la içeriğe göre iner (misc.vrr fişe bağlı: power_sync aşağıda).
hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@165",
    position = "0x0",
    scale    = 1,
})

-- Harici ekran (HDMI muxsuz, dGPU'da — external-display.nix): tercih edilen mod,
-- otomatik yerleşim.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-------------------------------------------------------------------------------
-- GİRİŞ
-------------------------------------------------------------------------------

hl.config({
    input = {
        kb_layout    = "us", -- system/init/locale.nix ile aynı
        repeat_rate  = 35,
        repeat_delay = 250,
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            clickfinger_behavior = true, -- iki parmakla bas = sağ tık (bölgeye bakmaz)
            scroll_factor        = 0.6,
        },
    },
    gestures = {
        workspace_swipe_create_new = true,
    },
    cursor = {
        hide_on_key_press = true, -- yazarken imleç gizlenir, fareyle geri gelir
    },
    binds = {
        workspace_back_and_forth = true, -- bulunduğun alanın tuşu = bir öncekine dön
        allow_workspace_cycles   = true,
    },
})

-- 3 parmak yatay: çalışma alanı. 3 parmak yukarı: karalama alanı (binds.lua SUPER+`).
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = "special", workspace_name = "scratch" })

-------------------------------------------------------------------------------
-- DAVRANIŞ
-------------------------------------------------------------------------------

hl.config({
    misc = {
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,   -- duvar kağıdı hyprpaper'dan (Stylix image)

        -- vrr burada YOK: fişe bağlı, aşağıdaki power_sync() yazar.

        -- Uykudaki ekranı herhangi bir girdi uyandırsın (hypridle dpms off sonrası).
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,

        -- Bağlantıya tıklayınca tarayıcı öne gelsin (xdg-activation).
        focus_on_activate = true,

        -- Terminalden açılan GUI terminali "yutar", kapanınca terminal geri gelir.
        enable_swallow = true,
        swallow_regex  = "^(com\\.mitchellh\\.ghostty)$",

        -- Kilit ekranı çökerse yeniden başlatılabilsin. Kurtarma (Ctrl+Alt+F3 TTY):
        --   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
        allow_session_lock_restore = true,
    },
    render = {
        -- Tam ekran oyun/videoda kompozisyonu atla (yalnız içerik türü "game"
        -- bildirenlerde: auto). Gecikme ve güç kazancı.
        direct_scanout = 2,
    },
    ecosystem = {
        no_update_news    = true,
        no_donation_nag   = true,
    },
})

-------------------------------------------------------------------------------
-- VRR FİŞE BAĞLI (5 Eki 2026, ölçümle)
-------------------------------------------------------------------------------
-- Fişte 1 = her zaman açık (4 Eki 2026 kullanıcı isteği: masaüstünde de
-- değişken tazeleme). Pilde 3 = yalnız tam ekran video/oyun (içerik türü
-- bildirenler). Neden: VRR açık panelde PSR (panelin kendini tazelemesi) HİÇ
-- devreye girmiyor — psr_state 0 kalıyor, kapatınca 6'ya (PSR_STATE3) iniyor.
-- Pilde statik masaüstünde ölçülen bedel 6.09 → 5.40 W, −0.70 W (boşta
-- tüketimin ~%11'i; scripts/power-ab.sh, ABBA). Documentation/aerox16/power.md.
--
-- Tetikleyici: oturum açılışı/config yüklemesi (bu dosya) + fiş olayı
-- (system/kernel/power-display.nix → power-display-user → `hyprctl eval
-- 'power_sync()'`). Pilde de her zaman açık istenirse: aşağıdaki 3'ü 1 yap.
function power_sync()
    local f = io.open("/sys/class/power_supply/ACAD/online")
    local ac = f and f:read("*l") or "1"
    if f then f:close() end
    hl.config({ misc = { vrr = (ac == "0") and 3 or 1 } })
end
power_sync()
