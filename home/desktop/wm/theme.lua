-- Dinamik renk katmanı — Caelestia CLI'ın (`enableHypr = true`) ürettiği
-- ~/.config/hypr/scheme/current.lua'yı Hyprland'e uygular.
--
-- CLI, hyprctl `status` ile config sağlayıcısını sorar (bkz. caelestia-cli
-- src/caelestia/utils/hypr.py is_lua_config); Lua config algılanınca (bizim
-- durumumuz — home/desktop/session.nix configType="lua") çıktı BARE-HEX düz bir
-- tablo olur (`return { primary = "3fa9a0", secondary = "3a6ea5", ... }`,
-- alpha/rgba() YOK) — eski matugen'in active_border/shadow'u ÖNCEDEN
-- hesaplayan colors.lua şablonundan farklı, alpha'yı burada BİZ ekliyoruz.
--
-- require DEĞİL dofile: require sonucu package.loaded'a önbelleğe alır;
-- reload sonrası Lua durumu korunursa ESKİ renkler dönerdi. dofile her
-- çalışmada diskten taze okur.

local path = os.getenv("HOME") .. "/.config/hypr/scheme/current.lua"
local ok, colours = pcall(dofile, path)

if not ok or type(colours) ~= "table" then
    -- İlk açılış / CLI henüz koşmamışsa: zixar-main paletiyle uyumlu sabit yedek.
    -- ExecStartPre'deki defaultsGuard (caelestia/default.nix) kısa sürede gerçek
    -- CLI çıktısıyla değiştirir.
    colours = {
        primary   = "3fa9a0",
        secondary = "3a6ea5",
        outline   = "5a5f73",
        crust     = "0d0e12",
    }
end

hl.config({
    general = {
        col = {
            active_border = {
                colors = { "rgba(" .. colours.primary .. "ee)", "rgba(" .. colours.secondary .. "ee)" },
                angle  = 45,
            },
            inactive_border = "rgba(" .. colours.outline .. "aa)",
        },
    },
    decoration = {
        -- Lua sayı literaline denk gelmesi için hex string'i tonumber ile çöz
        -- (eski dosyadaki sabit `0xee1a1a1a` yazımının dinamik eşleniği).
        shadow = { color = tonumber("ee" .. colours.crust, 16) },
    },
})
