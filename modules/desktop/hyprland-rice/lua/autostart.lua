-- Oturum başlangıcı.
--
-- Waybar / SwayNC / swww-daemon BURADA DEĞİL: systemd user servisleri olarak
-- hyprland-session.target'a bağlılar (bkz. hm.nix). Bunun iki nedeni var:
--   1. GNOME oturumuyla birlikte yaşam: graphical-session.target GNOME'da da
--      aktifleşir; hyprland-session.target yalnız Hyprland'de → waybar GNOME
--      oturumuna sızmaz.
--   2. Çökme yönetimi: systemd Restart=on-failure verir, exec-once vermez.
--
-- Burada yalnız tema restorasyonu var: son duvar kağıdı (yoksa Stylix
-- varsayılanı) swww'ye basılır; renk dosyaları eksikse matugen bir kez koşar.
hl.on("hyprland.start", function()
    hl.exec_cmd("theme-apply --restore")
end)
