-- Pencere, katman ve çalışma alanı kuralları.
-- Sınıf adını doğrulamak için: hyprctl clients | grep -E 'class|title'

-------------------------------------------------------------------------------
-- GENEL
-------------------------------------------------------------------------------

-- Uygulamaların kendini maximize etme isteğini yut: döşeme düzenini bozmasın.
hl.window_rule({
    name  = "suppress-maximize",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland sürükle-bırak hayaletleri (upstream örnek config'inden).
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Tam ekran bir pencere varken (video, oyun) ekran kilitlenmesin / kararmasın.
-- Wayland idle-inhibit'i kendisi istemeyen uygulamalar için emniyet.
hl.window_rule({
    name  = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-------------------------------------------------------------------------------
-- YÜZEN PENCERELER — küçük araçlar ve diyaloglar
-------------------------------------------------------------------------------

hl.window_rule({
    name  = "float-tools",
    match = { class = "^(com\\.saivert\\.pwvucontrol|io\\.github\\.kaii_lb\\.Overskride|org\\.gnome\\.Settings|org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueberry\\.py|org\\.gnome\\.Calculator|com\\.gabm\\.satty|hyprland-share-picker|xdg-desktop-portal-gtk|org\\.gnome\\.FileRoller)$" },
    float  = true,
    center = true,
    size   = "monitor_w*0.45 monitor_h*0.55",
})

-------------------------------------------------------------------------------
-- CAM — pencereleri bar'ın diline sok (3 Eki 2026)
-------------------------------------------------------------------------------
-- opacity "aktif pasif" — uygulamanın kendi alfasıyla ÇARPILIR. Arkası
-- look.lua'daki blur ile buzlu cam olur. Yalnız Hyprland'de: GNOME/COSMIC'e
-- dokunmaz (orada aynı uygulamalar opak kalır).

-- Liquid glass terminal: saydamlığı ZEMİN veriyor (ghostty background-opacity
-- 0.4, yalnız Hyprland'de — default.nix "Cam terminal"), pencere opacity'si
-- değil: o metni de soldurur. Arkası hyprglass (aşağıda); eklenti yoksa
-- look.lua blur. Odaktan çıkınca hafifçe erir.
hl.window_rule({
    name    = "liquid-terminal",
    match   = { class = "^(com\\.mitchellh\\.ghostty)$" },
    opacity = "1.0 0.9",
    no_shadow = true, -- cam yüzeyde koyu gölge çamur gibi duruyor
    tag     = "+hyprglass_enabled",
})

-- hyprglass (4 Eki 2026): ghostty'nin arkasındaki bulanıklığı Liquid Glass'la
-- değiştirir — kenarda kırılma, mercek, renk ayrışması, parlak bevel.
-- Eklenti GLOBAL KAPALI, yalnız yukarıdaki etiketli pencerelerde çalışır
-- (diğer cam pencereler look.lua blur'unda kalır). noblur'u eklenti kendisi
-- koyar. Paket: home/desktop/hyprland/hyprglass.nix (Hyprland sürümüne kilitli);
-- yüklenemezse bu blok atlanır, terminal eski blur'la devam eder.
-- Canlı ayar: hyprctl keyword plugin:hyprglass:<ayar> <değer>
if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        enabled        = false,
        default_theme  = "dark",
        default_preset = "terminal",
    })

    -- Liquid glass: eklentinin "glass" preset'i tabanı — kalın kenarda güçlü
    -- kırılma (arka plan kenara doğru bükülür), ortada mercek kubbesi, kenarda
    -- prizma gibi renk ayrışması, arkadaki renkleri alan bevel ve parlama.
    -- Bulanıklık metnin arkası sakin kalacak kadar; adaptive_dim parlak
    -- bulutları bastırır ki açık metin okunur kalsın.
    hg.preset("terminal", {
        inherits             = "glass",
        blur_strength        = 1.6,  -- ≈19 px
        blur_iterations      = 3,
        refraction_strength  = 6.0,
        refraction_flow      = 0.3,
        refraction_spread    = 0.8,
        edge_thickness       = 0.1,
        lens_distortion      = 0.45,
        chromatic_aberration = 0.55,
        fresnel_strength     = 0.55,
        fresnel_tint         = 0.4,
        specular_strength    = 0.9,
        bevel_strength       = 0.7,
        bevel_size           = 5.0,
        bevel_tint           = 0.4,
        tint_color           = 0x1a1d2238, -- tema zemini (base00), hafif
        dark = { brightness = 0.95, contrast = 1.0, saturation = 1.15, vibrancy = 0.35, adaptive_dim = 0.3 },
    })
end

-- libadwaita araçları (ses, bluetooth, Wi-Fi, dosyalar): opak düz pencereler
-- bar'ın yarı saydam haplarıyla uyuşmuyordu → hafif cam, içerik okunur kalır.
hl.window_rule({
    name    = "glass-tools",
    match   = { class = "^(com\\.saivert\\.pwvucontrol|io\\.github\\.kaii_lb\\.Overskride|org\\.gnome\\.Settings|org\\.gnome\\.Nautilus)$" },
    opacity = "0.94 0.88",
})

-- Polkit parola penceresi (hyprpolkitagent): yüzer, ortada, her alanda görünür.
-- match alanlarının HEPSİ tutmalı — bu yüzden yalnız sınıf.
hl.window_rule({
    name  = "float-polkit",
    match = { class = ".*[Pp]olkit.*" },
    float  = true,
    center = true,
    pin    = true,
})

-- Dosya seçici / kaydet diyalogları (GTK portal + uygulama içi).
hl.window_rule({
    name  = "float-file-dialogs",
    match = { title = "^(Open File|Save File|Save As|Open Folder|Dosya Aç|Kaydet|Farklı Kaydet).*" },
    float  = true,
    center = true,
    size   = "monitor_w*0.55 monitor_h*0.6",
})

-------------------------------------------------------------------------------
-- RESİM İÇİNDE RESİM — sağ alt köşe, her alanda, oranı korunur
-------------------------------------------------------------------------------

hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture-in-Picture|Resim içinde resim)$" },
    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
    size              = "monitor_w*0.25 monitor_h*0.25",
    move              = "monitor_w*0.75-16 monitor_h*0.75-16",
    no_initial_focus  = true,
})

-------------------------------------------------------------------------------
-- CLAUDE SESLİ ASİSTAN — Copilot tuşu; ekranın altında hap, her alanda
-------------------------------------------------------------------------------
-- İki pencere, aynı sınıf (Chromium app_id'yi --app adresinden türetir):
--   hap    — claude.ai sayfası; pencerenin KENDİSİ koyu kutu (claude-voice/
--            panel.css), köşeleri buradaki rounding. Düğme büyüyüp küçülünce
--            lua/voice.lua pencereyi merkezi sabit kalarak boyutlandırır
--            (116 = sesli mod kapalı; Stop 163, Cancel 178). Yer: monitörün alt
--            ortası, üstü alttan 290px (voice.lua home / LIFT ile aynı). Açılışta
--            yeri Lua yeniden verir; buradaki yalnız doğduğu yer.
--   sohbet — hapın üstündeki about:blank popup (session.js); ilk başlığından
--            ayrılır, boyut değiştirmez.
-- İkisi de gizli alanda doğar (servis Chromium'u arka planda açık tutar).
-- Getirip götürmeyi, kaymayı, solmayı ve hapın genişliğini lua/voice.lua yapar
-- (Hyprland'in kendi animasyonu kapalı — genel ve hızlı). Sabitleme (pin) de
-- orada: gizli alandaki pencere sabitlenemez.
-- Chromium saydam pencere çizmiyor: pencere kutudan geniş olunca kenarlarda
-- koyu şerit kalıyordu, o yüzden pencere = kutu.
-- no_blur / no_shadow: yuvarlatılmış köşelerin dışı temiz kalsın.

hl.window_rule({
    name  = "claude-voice",
    match = { class = "^(chrome-claude\\.ai__new-Default)$" },
    float       = true,
    size        = "116 86",
    move        = "monitor_w*0.5-58 monitor_h-290",
    rounding    = 14,
    workspace   = "special:claude-voice silent",
    border_size = 0,
    no_shadow   = true,
    no_blur     = true,
    no_anim     = true,
})

-- Sonra gelen kural öncekini ezer: sohbet penceresi kendi boyutunu alır.
hl.window_rule({
    name  = "claude-voice-chat",
    match = { class = "^(chrome-claude\\.ai__new-Default)$", initial_title = "^(about:blank)$" },
    size     = "480 360",
    rounding = 14,
})

-------------------------------------------------------------------------------
-- STEAM — ana pencere döşenir, arkadaş listesi/diyaloglar yüzer
-------------------------------------------------------------------------------

hl.window_rule({
    name  = "steam-dialogs",
    match = { class = "^(steam)$", title = "^(Friends List|Steam Settings|Steam - News.*|Special Offers)$" },
    float = true,
})

-- Oyunlar (Proton → XWayland, sınıf steam_app_<id>): içerik türünü "game" işaretle.
-- direct_scanout = 2 (main.lua) yalnız bu türde kompozisyonu atlar. Kilitlenmeye
-- karşı koruma yukarıdaki idle-inhibit-fullscreen kuralından gelir; pencere
-- kipindeki oyun için gamemode'un inhibit_screensaver'ı var (sched.nix →
-- org.freedesktop.ScreenSaver, sağlayıcısı hypridle).
hl.window_rule({
    name  = "steam-games",
    match = { class = "^(steam_app_.*|gamescope)$" },
    content = "game",
})

-------------------------------------------------------------------------------
-- KATMANLAR — bar, launcher, bildirim: bulanık cam
-------------------------------------------------------------------------------

-- ignore_alpha: tamamen saydam piksellerin arkası bulanıklaştırılmaz → köşe
-- yuvarlamalarının dışında "hayalet dikdörtgen" kalmaz.
hl.layer_rule({
    name  = "glass",
    match = { namespace = "^(waybar|notifications)$" },
    blur         = true,
    ignore_alpha = 0.2,
})

-- Başlatıcı (hypr-launcher) adanın İÇİNDE açılır: zemini, bulanıklığı ve
-- büyüme hareketi waybar adasının; bu katman yalnız içeriği çizer ve kendi
-- solmasını kendisi yapar (launcher/style.css). Bulanıklık olsaydı ada iki kez
-- bulanırdı; Hyprland'in katman animasyonu da içeriği kaydırıp adadan koparırdı.
-- Tam ekranda kendi zeminini çizerken (.solo) de bulanık cam olsun diye blur
-- AÇIK, ama ignore_alpha yüksek: yarı saydam seçim/arama zemini bulanıklık
-- tetiklemesin, yalnız .solo'nun %90'lık zemini.
hl.layer_rule({
    name         = "launcher-island",
    match        = { namespace = "^hypr-launcher$" },
    no_anim      = true,
    blur         = true,
    ignore_alpha = 0.85,
})

-- Waybar adası animasyonsuz: ada kendi boyutunu kare kare canlandırıyor
-- (waybar-island.patch). Katman animasyonu açıkken Hyprland yüzeyi eski/yeni
-- boyut arasında ESNETİYORDU — yazılar büyüyüp küçülüyor, ada seker gibi
-- görünüyordu (4 Eki 2026, karelerle doğrulandı).
hl.layer_rule({
    name  = "no-anim-bar",
    match = { namespace = "^waybar$" },
    no_anim = true,
})

-- Ekran görüntüsü seçim katmanı animasyonsuz (yoksa seçim çerçevesi
-- görüntüye girer). grimblast da aynı kuralı çalışırken ekliyor; kalıcı olsun.
hl.layer_rule({
    name  = "no-anim-selection",
    match = { namespace = "^(selection|hyprpicker)$" },
    no_anim = true,
})

