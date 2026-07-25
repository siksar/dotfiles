-- Pencere kuralları — 0.55 örnek config'inden doğrulanmış API.

-- Uygulamaların maximize isteklerini yut (tiling düzenini bozmasınlar)
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland sürükleme hatası düzeltmesi
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- Steam ana penceresi kendini float açıyor; float CEF penceresini elle
-- boyutlandırmak XWayland altında artefakt/donma üretiyor. Zorla tile +
-- maximize → boyutu layout yönetir, elle resize ihtiyacı kalmaz.
-- (Sadece ana pencere: initial_title=Steam. Popup/menüler etkilenmez.)
-- Kaynak: thinglab.org/2026/01/hyprland_steam_windowrule
hl.window_rule({
    name  = "fix-steam-float",
    match = {
        class         = "steam",
        initial_title = "Steam",
        float         = true,
    },
    float    = false,
    maximize = true,
})

-- pavucontrol küçük yüzer pencere olarak açılsın
hl.window_rule({
    name  = "float-pavucontrol",
    match = { class = "org.pulseaudio.pavucontrol" },
    float = true,
})

-- Windowed oyun (steam_app_*): oyun penceresi tile edilirse Hyprland onu
-- layout boyutuna zorlar — oyunlar keyfî resize'ı kötü işler (UI bozulur,
-- bazıları çakılır). Float + center: oyun kendi seçtiği çözünürlükte kalır.
-- Süsleme/efekt sıfırlanır: oyun yüzeyinde blur/gölge/rounding hem GPU
-- maliyeti hem artefakt kaynağı. opaque: alfa blend maliyetini keser.
-- idle_inhibit=focus: oyun odaktayken ekran kararmaz/kilitlenmez.
-- keep_aspect_ratio: mouse ile boyutlandırırken en-boy oranı korunur.
-- content=game: compositor'a içerik türü ipucu.
-- Not: misc.vrr=2 olduğundan windowed'da VRR devrede değil — panel sabit
-- 165Hz; FPS sınırı istersen MangoHud config'ine fps_limit ekle
-- (modules/apps/gaming.nix, mangohud.settings).
hl.window_rule({
    name  = "windowed-game",
    match = { class = "^steam_app_.*" },
    float             = true,
    center            = true,
    no_anim           = true,
    no_blur           = true,
    no_shadow         = true,
    no_dim            = true,
    border_size       = 0,
    rounding          = 0,
    opaque            = true,
    idle_inhibit      = "focus",
    keep_aspect_ratio = true,
    content           = "game",
})

-- gamescope pencereli (GR_GSWIN — Hyprland'de varsayılan): DIŞ pencere gamescope'un
-- KENDİSİDİR (app_id "gamescope"), oyunun steam_app_* penceresi değil (o, gamescope'un
-- içindedir → Hyprland görmez). Bu yüzden windowed-game kuralı bunu YAKALAMAZ, ayrı kural
-- gerekir. Kullanıcı KENARLIK istiyor → border_size sıfırlanmaz (global border_size=1
-- miras alınır). float+center: 1920x1080 pencere 2560x1600'de ortada → waybar (üst) +
-- border'la çakışmaz. rounding=0: yuvarlatma oyun görüntüsünün köşesini kırpar → kapalı.
-- Süsleme/idle windowed-game ile aynı. Sınıf tutmazsa `hyprctl clients` ile teyit et.
hl.window_rule({
    name  = "gamescope-windowed",
    match = { class = "^gamescope$" },
    float             = true,
    center            = true,
    no_anim           = true,
    no_blur           = true,
    no_shadow         = true,
    no_dim            = true,
    rounding          = 0,
    opaque            = true,
    idle_inhibit      = "focus",
    keep_aspect_ratio = true,
    content           = "game",
})

-- Paradox Launcher (CEF/Electron — Dawn/Chromium GPU süreci, tüm Paradox oyunlarında ortak
-- launcher, örn. HOI4 394360) — windowed-game kuralı ^steam_app_.* ile bunu da yakalayıp
-- float+center uyguluyor. Ama bu launcher, Steam'in kendi ana penceresiyle AYNI sınıf sorunu
-- taşıyor (CEF): float'ta elle/tile-sonrası resize XWayland'da bozuk render üretiyor (beyaz
-- köşe + boyanmamış siyah kalan — 22 Tem 2026 gözlemi). fix-steam-float'taki ÇÖZÜMÜN AYNISI:
-- float kapat, maximize aç → tek seferlik boyutlandırma, CEF'in swapchain'i canlı resize'a
-- hiç maruz kalmaz. class değil title ile ayırt ediyoruz çünkü asıl oyun penceresi (launcher
-- kapanıp motor açılınca) AYNI steam_app_394360 sınıfını taşır ama farklı title'a sahiptir —
-- windowed-game'in float+center'ı O pencerede doğru kalmalı, yalnız launcher'ı burada eziyoruz.
hl.window_rule({
    name  = "fix-paradox-launcher-cef",
    match = {
        class = "^steam_app_.*",
        title = "Paradox Launcher",
    },
    float    = false,
    maximize = true,
})

-- HOI4 (394360) windowed'da kenar-kaydırma: imleç pencere kenarına gidince
-- masaüstüne kaçar, harita kaymaz. confine_pointer imleci oyun penceresine
-- kilitler; alt-tab/SUPER kısayolları klavyeden çalışmaya devam eder.
-- Başka bir kenar-kaydırmalı oyun eklersen aynı kalıbı kopyala (oyun
-- sınıfı = steam_app_<appid>).
hl.window_rule({
    name  = "hoi4-confine-pointer",
    match = { class = "^steam_app_394360$" },
    confine_pointer = true,
})
