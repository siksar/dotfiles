-- Görünüm: boşluk, köşe, bulanıklık, gölge, animasyon, düzen.
-- Renk YOK (main.lua başındaki not): gölge = base00, Stylix paletinden.
-- Kenarlık kapalı (border_size = 0) — kullanıcı tercihi, 3 Eki 2026.

hl.config({
    general = {
        gaps_in          = 5,
        -- Üst: waybar adası (30 px, bar.nix islandHeight) + 10. Ada exclusive
        -- değil — açılınca pencerelerin üstüne düşer, yerleşim oynamaz.
        gaps_out         = { top = 40, right = 10, bottom = 10, left = 10 },
        border_size      = 0, -- kenarlık yok: pencereler yalnız boşluk + gölgeyle ayrışır (bar gibi)
        resize_on_border = true, -- kenardan/boşluktan tutup boyutlandır
        allow_tearing    = false, -- VRR fişte her zaman, pilde tam ekranda (main.lua power_sync)
        layout           = "dwindle",
        snap = { enabled = true }, -- yüzen pencereler kenarlara/birbirine yapışır
    },

    decoration = {
        rounding       = 12, -- waybar hapları da 12px
        rounding_power = 3, -- 2 = daire yayı, büyüdükçe "squircle"

        -- Pencere saydamlığı compositor'dan DEĞİL, uygulamanın kendisinden gelir
        -- (Stylix opacity: ghostty 0.85, uygulamalar 0.92 — lib/theme.nix).
        -- Burada 1.0: okunabilirlik + tek kaynak.
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        dim_inactive     = false,

        shadow = {
            enabled      = true,
            range        = 14,
            render_power = 3,
        },

        -- Bulanıklık yalnız saydam yüzeylerin ARKASINDA çizilir (ghostty, waybar,
        -- mako, başlatıcı tam ekranda) ve yalnız hasar olunca yeniden hesaplanır — boşta maliyet yok.
        blur = {
            enabled           = true,
            size              = 8,    -- buzlu cam: daha geniş ve yumuşak
            passes            = 3,
            vibrancy          = 0.22, -- arka planın rengi camdan biraz daha geçsin
            brightness        = 0.9,  -- cam hafif koyulsun, metin öne çıksın
            noise             = 0.01,
            popups            = true,
            new_optimizations = true,
            xray              = false,
        },
    },

    dwindle = {
        preserve_split = true,  -- bölünme yönü pencere kapanınca korunsun
        smart_split    = false,
    },

    master = {
        new_status = "master",
    },

    -- SUPER+ALT+Space dwindle ↔ scrolling geçişi (binds.lua). Scrolling: niri
    -- tarzı yatay şerit, her yeni pencere ekranın yarısı.
    scrolling = {
        column_width             = 0.5,
        fullscreen_on_one_column = true,
    },

    group = {
        groupbar = {
            font_size = 11,
            height    = 18,
            rounding  = 6,
            gradients = false,
        },
    },

    animations = {
        enabled = true,
    },
})

-------------------------------------------------------------------------------
-- ANİMASYONLAR — Claude sesli sohbet panelinin ritmi: 700 ms easeInOutCubic
-- (claude-voice/panel.css, cubic-bezier(0.65, 0, 0.35, 1)). speed birimi
-- desisaniye → 7 = 700 ms. Yay/aşma yok (eski "snappy" yayı kaba hissettiriyordu).
--
-- İSTİSNA — pencere boyut/konum (windows*): Hyprland, uygulama yeni boyutta
-- çizene kadar ESKİ görüntüyü yeni kutuya gerer. easeInOut yavaş başladığı
-- için ilk ~150 ms'de pencereler kıpırdamazken yenisi saydamlıktan beliriyor →
-- üst üste binen hayalet + uzun süren esneme (4 Eki 2026, karelerle görüldü).
-- Pencereler bu yüzden easeOutQuart: hemen yola çıkar, yerine uzun ve yumuşak
-- oturur; geçiş kısa sürer, his yine yavaş. Alan kaydırma, solma ve katmanlar
-- yalnız kaydırır/saydamlaştırır (germe yok) → sesli sohbet eğrisinde.
-------------------------------------------------------------------------------

hl.curve("voice",        { type = "bezier", points = { { 0.65, 0 },    { 0.35, 1 } } })
hl.curve("settle",       { type = "bezier", points = { { 0.25, 1 },    { 0.5, 1 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 },    { 0.32, 1 } } })

hl.animation({ leaf = "global",           enabled = true, speed = 7,   bezier = "voice" })
hl.animation({ leaf = "border",           enabled = true, speed = 7,   bezier = "voice" })
hl.animation({ leaf = "windows",          enabled = true, speed = 6,   bezier = "settle" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 6,   bezier = "settle", style = "popin 92%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 4.5, bezier = "settle", style = "popin 92%" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 4,   bezier = "settle" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 4,   bezier = "settle" })
hl.animation({ leaf = "fade",             enabled = true, speed = 7,   bezier = "voice" })
hl.animation({ leaf = "layers",           enabled = true, speed = 7,   bezier = "voice" })
-- Katman açılışı settle: başlatıcı tuşa basınca hemen inmeye başlamalı,
-- easeInOut'un yavaş kalkışı yazmaya başlarken gecikme gibi hissettirir.
hl.animation({ leaf = "layersIn",         enabled = true, speed = 5,   bezier = "settle", style = "popin 94%" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 3.5, bezier = "settle", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 4,   bezier = "settle" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 3.5, bezier = "settle" })
-- Alan geçişi "slide" DEĞİL: geçiş yarıda kesilince (hızlı 2→3→2) Hyprland
-- gelen alanı hep ekranın TAM dışından başlatıyor, giden alanı ise bulunduğu
-- yerden götürüyor (WorkspaceAnimationController.cpp startAnimation) → ortada
-- duvar kağıdı şeridi açılıyordu (4 Eki 2026). slidefade %15: kısa kayma +
-- karışma, kesilse de boşluk kalmaz. settle: hemen tepki verir.
hl.animation({ leaf = "workspaces",       enabled = true, speed = 6,   bezier = "settle", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 7,   bezier = "voice", style = "slidevert" })
-- Yakınlaştırma klavye/fareyle sürekli sürülür; 700 ms orada ağır kalır.
hl.animation({ leaf = "zoomFactor",       enabled = true, speed = 4,   bezier = "easeOutQuint" })
