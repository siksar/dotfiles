-- matugen şablonu → çıktı: ~/.config/hypr/colors.lua (ELLE DÜZENLENMEZ)
-- theme.lua her `hyprctl reload`da dofile ile taze okur.
-- Hyprland renk biçimleri: kenarlıklar "rgba(RRGGBBAA)" dizesi,
-- gölge 0xAARRGGBB sayısı (0.55 örnek config'iyle uyumlu).
return {
    active_border   = "rgba({{colors.primary.default.hex_stripped}}ee)",
    active_border2  = "rgba({{colors.tertiary.default.hex_stripped}}ee)",
    inactive_border = "rgba({{colors.surface_variant.default.hex_stripped}}aa)",
    shadow          = 0xee{{colors.shadow.default.hex_stripped}},
}
