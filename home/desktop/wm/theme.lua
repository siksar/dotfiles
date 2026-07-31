-- Dinamik renk katmanı — matugen'in ürettiği ~/.config/hypr/colors.lua'yı
-- Hyprland'e uygular. Tema motorunun Hyprland ayağı budur:
-- theme-apply → matugen → colors.lua yazılır → post_hook `hyprctl reload`
-- → bu dosya yeniden çalışır → yeni renkler.
--
-- require DEĞİL dofile: require sonucu package.loaded'a önbelleğe alır;
-- reload sonrası Lua durumu korunursa ESKİ renkler dönerdi. dofile her
-- çalışmada diskten taze okur.

local path = os.getenv("HOME") .. "/.config/hypr/colors.lua"
local ok, colors = pcall(dofile, path)

if not ok or type(colors) ~= "table" then
    -- İlk açılış / matugen henüz koşmamışsa: kanagawa-vari sabit yedek
    -- (zixar-main paletiyle uyumlu). theme-apply --restore bunu kısa sürede
    -- gerçek matugen çıktısıyla değiştirir.
    colors = {
        active_border   = "rgba(7e9cd8ee)",
        active_border2  = "rgba(957fb8ee)",
        inactive_border = "rgba(54546daa)",
        shadow          = 0xee1a1a1a,
    }
end

hl.config({
    general = {
        col = {
            active_border = {
                colors = { colors.active_border, colors.active_border2 },
                angle  = 45,
            },
            inactive_border = colors.inactive_border,
        },
    },
    decoration = {
        shadow = { color = colors.shadow },
    },
})
