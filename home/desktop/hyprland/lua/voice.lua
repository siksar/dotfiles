-- Claude sesli asistan (Copilot tuşu): pencere koreografisi Hyprland'in içinde.
--
-- Tuş doğrudan claude_voice_toggle()'ı çağırır: animasyon tuşa basılan karede
-- başlar, hiçbir süreç doğmaz. Sesli modu açıp kapatmak arka plandaki servisin
-- (claude-voice --daemon, home/desktop/hyprland/session.nix) işi; ona soket2'den
-- olay yayılır: custom>>claude-voice show | hide. Servis, sayfa sohbet penceresi
-- isteyince claude_voice_chat(true|false)'ı `hyprctl eval` ile çağırır.
--
-- İki pencere, aynı sınıf: hap (claude.ai sayfası) ve sohbet (about:blank popup,
-- ilk başlığından ayrılır). İkisi de gizli alanda doğar (rules.lua). Konum,
-- saydamlık ve hapın genişliği kare kare (hl.timer) sürülür; Hyprland'in kendi
-- animasyonu bu pencerelerde kapalı (no_anim) — genel ve hızlı, yavaşlatmak
-- hepsini etkiler.
--
-- Hap penceresinin kendisi koyu kutu (claude-voice/panel.css): düğme büyüyüp
-- küçülünce sayfa yeni genişliği bildirir (servis → claude_voice_width) ve
-- pencere merkezi sabit kalarak hapın CSS geçişiyle aynı süre ve eğride
-- boyutlanır. Chromium'un geç kalan kareleri kutuyla aynı renkte, bozulma
-- görünmüyor. Sohbet penceresi boyut değiştirmez.
--
-- Hap her zaman MERKEZİYLE konumlanır (home().cx): genişlik değişince sol kenar
-- kayar, merkez yerinde kalır.

local CLASS = "chrome-claude.ai__new-Default"
local CHAT_TITLE = "about:blank"
local HIDDEN = "special:claude-voice"
local SERVICE = "claude-voice.service"
-- Varsayılan yer: etkin monitörün alt ortası, hapın üstü alt kenardan LIFT px
-- yukarıda (2560×1600'de y 1310 — elle ayarlanan yükseklik, 4 Eki 2026).
local LIFT = 290
local GAP, CHAT_SLIDE = 10, 28 -- hap–sohbet arası boşluk, sohbetin kayma payı
-- Süreler (ms). Giriş yavaşlayarak oturur, çıkış hızlanarak gider.
local OPEN_MS, CLOSE_MS = 750, 420
local CHAT_OPEN_MS, CHAT_CLOSE_MS = 480, 320
local WIDTH_MS = 700 -- panel.css hap genişlik geçişiyle aynı (easeInOutCubic)
local WIDTH_MIN_MS = 250 -- hedef geçiş sürerken değişirse kalan süre en az bu

local step = 6 -- ms; hl.timer gerçekte ~7.5 ms'de tıklıyor
local running = {} -- adres → zamanlayıcı
local sizing = {} -- adres → { timer, ends } (genişlik geçişi)
local closing = {} -- adres → kapanış geçişinde (bitince gizlenecek)
local alpha = {} -- adres → son saydamlık (pencereden okunamıyor)
local rest = nil -- elle taşınan yer { cx, y }; nil = monitörün alt ortası
local pendingShow = false -- servis yeni başlarken tuşa basıldı: hap doğunca göster

local curves = {
    -- easeInOutCubic: yerinde kayma
    inout = function(t)
        if t < 0.5 then return 4 * t * t * t end
        return 1 - (-2 * t + 2) ^ 3 / 2
    end,
    -- easeOutQuint: hızlı gelir, yavaşlayarak oturur (kısa giriş)
    out = function(t) return 1 - (1 - t) ^ 5 end,
    -- easeInCubic: yavaş başlar, hızlanarak gider (çıkış)
    ["in"] = function(t) return t * t * t end,
    -- easeOutCubic: ekranın altından yükselme — quint kadar sert başlamaz, yol
    -- gözle görülür (quint'te hap ilk ~50 ms'de neredeyse yerindeydi)
    rise = function(t) return 1 - (1 - t) ^ 3 end,
}

local function round(v) return math.floor(v + 0.5) end

-- Hemen, animasyonsuz yerleştir.
local function place(address, x, y, a)
    local sel = "address:" .. address
    hl.dispatch(hl.dsp.window.move({ x = round(x), y = round(y), window = sel }))
    alpha[address] = a
    hl.dispatch(hl.dsp.window.set_prop({ window = sel, prop = "opacity", value = a }))
end

-- a < 0: saydamlığa dokunma. curve: inout | out | in | rise.
-- stash: verilirse geçiş BİTİNCE pencere iğnesi sökülüp oraya gizlenir — betik
-- sabit süre bekleyip gizleseydi (zamanlayıcı istenenden yavaş) pencere yolun
-- sonuna varmadan, ekranın altında görünürken sönerdi.
function claude_voice_tween(address, x, y, a, ms, curve, stash)
    local sel = "address:" .. address
    local win = hl.get_window(sel)
    if not win then return end
    if running[address] then running[address]:set_enabled(false) end
    closing[address] = (stash and stash ~= "") or nil

    local ease = curves[curve or "inout"] or curves.inout
    local fx, fy = win.at.x, win.at.y
    -- Yatayda yol yoksa x'e dokunma: genişlik geçişi aynı anda x'i (merkezi
    -- koruyarak) sürüyor olabilir, eski x'i yazmak onu titretirdi.
    local still = (x == fx)
    local fa = alpha[address] or 1
    local n, i = math.max(1, math.floor(ms / step)), 0
    local timer
    timer = hl.timer(function()
        i = i + 1
        local t = ease(math.min(i / n, 1))
        -- Belirirken saydamlık hızlı eğriyle (yolun başında görünür olsun);
        -- kaybolurken konumla aynı eğriyle (kaymadan önce sönmesin).
        local ta = (a > fa) and curves.out(math.min(i / n, 1)) or t
        local nx = round(fx + (x - fx) * t)
        if still then
            local cur = hl.get_window(sel)
            nx = cur and cur.at.x or nx
        end
        hl.dispatch(hl.dsp.window.move({ x = nx, y = round(fy + (y - fy) * t), window = sel }))
        if a >= 0 then
            alpha[address] = fa + (a - fa) * ta
            hl.dispatch(hl.dsp.window.set_prop({ window = sel, prop = "opacity", value = alpha[address] }))
        end
        if i >= n then
            timer:set_enabled(false)
            running[address] = nil
            if closing[address] then
                closing[address] = nil
                hl.dispatch(hl.dsp.window.pin({ action = "disable", window = sel }))
                hl.dispatch(hl.dsp.window.move({ workspace = stash, follow = false, window = sel }))
            end
        end
    end, { timeout = step, type = "repeat" })
    running[address] = timer
end

-- Genişliği merkezi koruyarak w'ye getir; ms = 0 ise hemen. Geçiş sürerken yeni
-- hedef gelirse (Cancel → Stop düğmesi her karede genişliyor) olduğu yerden ve
-- kalan sürede yeni hedefe döner — her seferinde baştan 700 ms beklemesin.
local function resize(address, w, ms, cx)
    local sel = "address:" .. address
    local win = hl.get_window(sel)
    if not win then return end
    local h, w0 = win.size.y, win.size.x
    cx = cx or (win.at.x + w0 / 2)
    local prev = sizing[address]
    if prev then
        prev.timer:set_enabled(false)
        sizing[address] = nil
        if ms > 0 then ms = math.max(prev.ends - prev.t, WIDTH_MIN_MS) end
    end
    if w == w0 then return end

    local function apply(cw)
        local cur = hl.get_window(sel)
        if not cur then return end
        hl.dispatch(hl.dsp.window.resize({ x = cw, y = h, window = sel }))
        hl.dispatch(hl.dsp.window.move({ x = round(cx - cw / 2), y = cur.at.y, window = sel }))
    end
    if ms <= 0 then apply(w) return end

    local n, i = math.max(1, math.floor(ms / step)), 0
    local job = { ends = ms, t = 0 }
    job.timer = hl.timer(function()
        i = i + 1
        job.t = i * step
        local cw = round(w0 + (w - w0) * curves.inout(math.min(i / n, 1)))
        apply(cw)
        if i >= n then
            job.timer:set_enabled(false)
            if sizing[address] == job then sizing[address] = nil end
        end
    end, { timeout = step, type = "repeat" })
    sizing[address] = job
end

-- ---- pencereler ------------------------------------------------------------

local function windows()
    local pill, chat
    for _, w in ipairs(hl.get_windows()) do
        if w.class == CLASS then
            if w.initial_title == CHAT_TITLE then chat = w else pill = w end
        end
    end
    return pill, chat
end

local function hidden(w) return w.workspace == nil or w.workspace.special end

local function screenBottom()
    local m = hl.get_active_monitor()
    return m and (m.y + m.height / (m.scale or 1)) or 1600
end

-- Gizli alandan etkin çalışma alanına al, her alanda görünür yap. Odak ALINMAZ:
-- o an yazılan uygulama klavyeyi kaybetmesin (sesli mod CDP ile açılıyor).
local function bring(w)
    local ws = hl.get_active_workspace()
    local sel = "address:" .. w.address
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws and ws.id or 1), follow = false, window = sel }))
    hl.dispatch(hl.dsp.window.pin({ action = "enable", window = sel }))
end

-- Hapın yeri: elle taşındıysa orası, yoksa etkin monitörün alt ortası.
local function home()
    if rest then return rest end
    local m = hl.get_active_monitor()
    if not m then return { cx = 1280, y = 1310 } end
    local s = m.scale or 1
    return { cx = m.x + m.width / s / 2, y = m.y + m.height / s - LIFT }
end

local function left(pill, r) return round(r.cx - pill.size.x / 2) end

local function show(pill)
    local r = home()
    local x = left(pill, r)
    if not closing[pill.address] then
        -- Ekranın hemen altında, görünmez hazırla; oradan yükselsin.
        place(pill.address, x, screenBottom(), 0)
        bring(pill)
    end -- kapanırken yeniden basıldıysa olduğu yerden geri döner
    claude_voice_tween(pill.address, x, r.y, 1, OPEN_MS, "rise")
    hl.dispatch(hl.dsp.event("claude-voice show"))
end

local function hide(pill, chat)
    -- Önce servise: sesli mod geçişle aynı anda dursun.
    hl.dispatch(hl.dsp.event("claude-voice hide"))
    -- Açılış geçişi sürmüyorsa ve hap yerinden oynatıldıysa (elle taşındı) yeni
    -- yeri hatırlanır. Oynatılmadıysa hatırlanan bir şey olmaz: hap bir dahaki
    -- açılışta yine o anki monitörün alt ortasında. (2 px pay: kesirli merkez
    -- yuvarlanıyor.)
    if not running[pill.address] then
        local r = home()
        local cx = pill.at.x + pill.size.x / 2
        if math.abs(cx - r.cx) > 2 or math.abs(pill.at.y - r.y) > 2 then
            rest = { cx = cx, y = pill.at.y }
        end
    end
    -- İkisi aynı mesafeyi kayar: tek bir alt sayfa gibi birlikte iner.
    local drop = screenBottom() + 8 - pill.at.y
    if chat and not hidden(chat) then
        claude_voice_tween(chat.address, chat.at.x, chat.at.y + drop, 0, CLOSE_MS, "in", HIDDEN)
    end
    claude_voice_tween(pill.address, pill.at.x, pill.at.y + drop, 0, CLOSE_MS, "in", HIDDEN)
end

-- Copilot tuşu (binds.lua).
function claude_voice_toggle()
    local pill, chat = windows()
    if not pill then
        -- Servis kapalı ya da yeni başlıyor: başlat, hap doğunca göster.
        pendingShow = true
        hl.exec_cmd("systemctl --user start " .. SERVICE)
        return
    end
    if hidden(pill) or closing[pill.address] then show(pill) else hide(pill, chat) end
end

hl.on("window.open", function(w)
    if not pendingShow or not w or w.class ~= CLASS or w.initial_title == CHAT_TITLE then return end
    pendingShow = false
    -- Kural (gizli alan) uygulandıktan sonra.
    local t
    t = hl.timer(function()
        t:set_enabled(false)
        local pill = windows()
        if pill and hidden(pill) then show(pill) end
    end, { timeout = 60, type = "oneshot" })
end)

-- Servis çağırır: sayfa sohbet penceresini istedi / bıraktı.
function claude_voice_chat(on)
    local pill, chat = windows()
    if not pill or not chat or hidden(pill) or closing[pill.address] then return end
    local r = home()
    local x = round(r.cx - chat.size.x / 2)
    local y = r.y - GAP - chat.size.y
    if on then
        if not hidden(chat) and not closing[chat.address] then return end
        if hidden(chat) then
            place(chat.address, x, y + CHAT_SLIDE, 0)
            bring(chat)
        end
        claude_voice_tween(chat.address, x, y, 1, CHAT_OPEN_MS, "out")
    elseif not hidden(chat) then
        claude_voice_tween(chat.address, x, y + CHAT_SLIDE, 0, CHAT_CLOSE_MS, "in", HIDDEN)
    end
end

-- Servis çağırır: hapın hedef genişliği değişti (panel.js → session.js). Gizliyken
-- hemen, görünürken hapın CSS geçişiyle aynı sürede.
function claude_voice_width(w)
    local pill = windows()
    if not pill then return end
    -- Merkez rest.cx'ten (kesirli): pencereden okunsa her yuvarlamada yarım
    -- piksel birikir, hap her aç-kapada 1 px sağa kayıyordu. Elle taşındıysa
    -- (merkez rest'ten belirgin uzak) pencerenin merkezi yeni yer olur.
    local r = home()
    local cx = pill.at.x + pill.size.x / 2
    if hidden(pill) or math.abs(cx - r.cx) <= 2 then
        cx = r.cx
    else
        rest = { cx = cx, y = pill.at.y } -- elle taşınmış
    end
    resize(pill.address, w, hidden(pill) and 0 or WIDTH_MS, cx)
end

-- SUPER+Q (binds.lua): asistanın penceresi odaktaysa kapatma, gizle. Kapatılan
-- hap penceresiyle sayfa da gider; servis yeniden başlayana dek (~2 sn) tuş
-- hiçbir şey açamazdı. true: pencere asistanındı, iş görüldü.
function claude_voice_close()
    local w = hl.get_active_window()
    if not w or w.class ~= CLASS then return false end
    -- Sohbet penceresinde de ikisi birlikte iner (sohbet yalnız hap görünürken var).
    local pill, chat = windows()
    if pill and not hidden(pill) and not closing[pill.address] then hide(pill, chat) end
    return true
end
