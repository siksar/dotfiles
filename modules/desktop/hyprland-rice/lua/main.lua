-- Hyprland 0.55+ Lua config — çekirdek katman: monitör, env, giriş, düzen.
-- Renkler theme.lua'da (matugen üretir), kısayollar binds.lua'da,
-- pencere kuralları rules.lua'da, oturum başlangıcı autostart.lua'da.
-- HM extraLuaFiles bu dosyaları hypr/*.lua olarak yazar ve hyprland.lua
-- içinden otomatik require eder (alfabetik sıra: autostart, binds, main,
-- rules, theme — theme en son geldiği için renkleri o kazanır).

------------------
---- MONITORS ----
------------------

-- Panel: BOE NE160QDM-NYJ 2560x1600@165 (scale 1). MOD DEĞERİ
-- modules/hardware/power-display.nix'teki powerDisplayUserScript'in AC modu
-- ("2560x1600@165") ile ELLE SENKRON — panel değişirse ikisi birden güncelle.
hl.monitor({
    output   = "eDP-1",
    mode     = "2560x1600@165",
    position = "auto",
    scale    = 1,
})

-- Harici monitörler: tercih edilen mod, otomatik yerleşim
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-----------------------------
---- ENV / dGPU KORUMASI ----
-----------------------------

-- dGPU D3cold koruması: aquamarine NVIDIA DRM node'unu HİÇ açmasın — açık fd
-- RTD3'ü bloke edip 4.28W idle bütçesini bozar (gnome.nix'teki
-- mutter-device-ignore udev kuralının Hyprland karşılığı).
--
-- DİKKAT — AQ_DRM_DEVICES BURADA (hl.env ile) AYARLANAMAZ:
--   aquamarine backend'i, Hyprland config'i OKUNMADAN ÖNCE, initServer
--   aşamasında kurulur. Config env'i (hl.env / `env=`) ise backend ayağa
--   kalktıktan SONRA uygulanır → çok geç kalır. Değişken yokken aquamarine
--   iki GPU'yu da (NVIDIA dahil) açmayı dener ve NVIDIA node'unda çöker:
--   SIGABRT, throwError@initServer, boş hyprland.log. GDM'den Hyprland'e
--   girilememesinin kök nedeni buydu.
--   Bu yüzden değişken oturum ORTAMINDA, Hyprland başlamadan set edilir:
--   modules/desktop/hyprland-rice/system.nix → environment.sessionVariables.
--   AYRICA değer İKİ NOKTA içeremez (aquamarine ':' ile böler) → by-path yerine
--   sürücüye göre sabit bir udev symlink'i (/dev/dri/hypr-igpu) kullanılır.
--   (ölçülen: card0=nvidia pci 64:00.0, card1=amdgpu pci 65:00.0 = Radeon 860M.)

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Görünüm değerleri Anto98765/My-Hyprland-Rice look_and_feel.conf'tan
-- (waybar portuyla aynı kaynak). Bilinçli sapmalar yorumlarda.
hl.config({
    general = {
        gaps_in     = 7,
        gaps_out    = 10,
        -- Kenarlık tamamen kapalı (kullanıcı isteği, 29 Tem) — pencereler
        -- sadece gaps + rounding + gölgeyle ayrışıyor. theme.lua'nın
        -- col.active_border/inactive_border ataması artık etkisiz (matugen
        -- yine de renk üretiyor, sadece hiçbir yerde çizilmiyor) — dokunmadan
        -- bırakıldı, ileride border_size geri açılırsa renkler hazır olsun.
        border_size = 0,
        resize_on_border = true,  -- kaynakta false; kullanıcı alışkanlığı korundu
        allow_tearing    = false, -- kaynakta true; VRR/oyun akışını gamerun yönetir
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 12,
        rounding_power = 4,
        -- Pencere saydamlığı — kaynakta 1/1 (opak) ama burada kullanıcının
        -- önceki kararı korunur: TÜM pencerelere compositor saydamlığı.
        -- active_opacity, stylix.opacity.applications (stylix-base.nix) ile ELLE
        -- SENKRON: birini değiştirirsen ötekini de değiştir. Tam ekran pencereler
        -- (oyunlar) bunu baypas eder → oyunlar opak kalır, idle/perf bütçesi güvende.
        active_opacity   = 0.92,
        inactive_opacity = 0.86,
        shadow = {
            enabled      = true,
            range        = 15,
            render_power = 3,
            -- color: theme.lua uygular
        },
        blur = {
            enabled           = true,
            -- Daha yumuşak/sisli görünüm (kullanıcı isteği, 29 Tem): size+passes
            -- artırıldı, contrast düşürüldü — kenarlar daha dağınık, "miasma"
            -- tarzına yakın. Eskisi: size=2 passes=2 contrast=1.6.
            size              = 4,
            passes            = 3,
            ignore_opacity    = true,
            noise             = 0,
            contrast          = 1.0,
            popups            = true,
            xray              = false,
            new_optimizations = true,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },

    input = {
        kb_layout    = "us", -- locale.nix services.xserver.xkb ile aynı
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = { natural_scroll = true },
    },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
        -- VRR yalnız tam ekran pencerede (2): masaüstünde sabit 165Hz,
        -- oyunda değişken — GNOME'daki mutter variable-refresh-rate
        -- deneysel özelliğinin karşılığı (panel 48-165Hz, docs/gaming.md).
        vrr = 2,
    },
})

-- 3 parmak yatay kaydırma → çalışma alanı değiştir
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

--------------------
---- ANIMATIONS ----
--------------------

-- Anto98765/My-Hyprland-Rice animations.conf portu (waybar ile aynı kaynak).
-- Görünür farklar: pencereler SLIDE ile açılır / popin 80% ile kapanır,
-- fareyle sürükleme 'windowsMove' ile animasyonlu (eski sette hiç yoktu),
-- workspace geçişi fade değil SLIDE, layer'lar (rofi/waybar) animasyonlu.
--
-- Eğriler (kaynaktaki 'bezier =' satırları; '1' adlı eğri 'one' oldu —
-- Lua tarafında sayı-ad karışıklığı olmasın):
hl.curve("overshot",  { type = "bezier", points = { { 0.05,  0.9   }, { 0.1,  1.05  } } })
hl.curve("smoothOut", { type = "bezier", points = { { 0.36,  0     }, { 0.66, -0.56 } } })
hl.curve("smoothIn",  { type = "bezier", points = { { 0.25,  1     }, { 0.5,  1     } } })
hl.curve("fluid",     { type = "bezier", points = { { 0.4,   0     }, { 0.2,  1     } } })
hl.curve("bounce",    { type = "bezier", points = { { 0.175, 0.885 }, { 0.32, 1.275 } } })
hl.curve("one",       { type = "bezier", points = { { 0.5,   0.0   }, { 0.357, 1.0  } } })

-- Süreler kaynaktan ~%25 KISA (kullanıcı isteği: "biraz daha hızlı") —
-- bu alan süredir (ds, 1 = 100 ms): düşük değer = hızlı animasyon.
-- Kaynak değerler yorumda karşılaştırma için.

-- Pencere
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 3,   bezier = "default", style = "slide" })      -- kaynak 4
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3,   bezier = "one",     style = "popin 80%" })  -- kaynak 4
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3,   bezier = "fluid" })                         -- kaynak 4

-- Fade
hl.animation({ leaf = "fade",       enabled = true, speed = 3,   bezier = "fluid" })     -- kaynak 4
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 4,   bezier = "smoothIn" })  -- kaynak 5
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3,   bezier = "smoothOut" }) -- kaynak 4
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 4,   bezier = "fluid" })     -- kaynak 5
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 4.5, bezier = "fluid" })     -- kaynak 6
hl.animation({ leaf = "fadeDim",    enabled = true, speed = 4,   bezier = "fluid" })     -- kaynak 5

-- Kenarlık. DİKKAT: kaynaktaki `borderangle ... loop` BİLEREK ATLANDI —
-- gradyan kenarlığı SÜREKLİ döndürür, compositor idle'da bile her karede
-- repaint eder → 4.28W idle bütçesini doğrudan ihlal ederdi.
hl.animation({ leaf = "border", enabled = true, speed = 8, bezier = "fluid" }) -- kaynak 10

-- Workspace
hl.animation({ leaf = "workspaces",       enabled = true, speed = 4,   bezier = "fluid",  style = "slide" })     -- kaynak 5
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4.5, bezier = "bounce", style = "slidevert" }) -- kaynak 6
hl.animation({ leaf = "workspacesIn",     enabled = true, speed = 3.5, bezier = "one",    style = "slide" })     -- kaynak 4.5
hl.animation({ leaf = "workspacesOut",    enabled = true, speed = 3.5, bezier = "one",    style = "slide" })     -- kaynak 4.5

-- Layer'lar (rofi, waybar, bildirimler)
hl.animation({ leaf = "layersIn",  enabled = true, speed = 2.5, bezier = "one" }) -- kaynak 3.5
hl.animation({ leaf = "layersOut", enabled = true, speed = 6,   bezier = "one" }) -- kaynak 8
