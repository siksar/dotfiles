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

-- VSCodium: pencere süslemesini compositor'a devret (kullanıcı isteği 30 Tem).
-- Uygulama tarafı kendi başlık çubuğunu çizmiyor (home/apps/vscodium.nix,
-- window.customTitleBarVisibility="never") → pencerenin tek çerçevesi buradaki
-- border. Global border_size 0 olduğu için (main.lua, kullanıcı kararı 29 Tem)
-- ELLE açılması gerekiyor; global'i değiştirmiyoruz, yalnız bu pencereye.
-- Güzel yan etki: theme.lua'nın matugen gradient'i (general.col.active_border,
-- border_size=0 yüzünden şimdiye kadar hiçbir yerde çizilmiyordu) nihayet
-- görünür oluyor → kenarlık duvar kağıdıyla birlikte değişir.
--
-- opacity: Hyprland'da TEK sayı active/inactive/fullscreen'in ÜÇÜNÜ birlikte
-- set eder → pencere odağı kaybettiğinde global inactive_opacity'ye (0.86)
-- SÖNMEZ. Kod okurken bu önemli; global active (0.92) yerine 0.94 seçildi,
-- blur açık kaldığından buzlu cam hissi korunuyor.
--
-- Sınıf: codium.desktop'ta StartupWMClass=vscodium. NIXOS_OZONE_WL=1 ile artık
-- native Wayland (app_id), öncesinde XWayland (WM_CLASS) idi — üç varyant da
-- kapsandı. Tutmazsa `hyprctl clients | grep -A2 class` ile teyit et.
hl.window_rule({
    name  = "vscodium-chrome",
    match = { class = "^(vscodium|codium|VSCodium)$" },
    border_size = 2,
    opacity     = 0.94,
})
