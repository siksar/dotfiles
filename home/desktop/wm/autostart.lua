-- Oturum başlangıcı.
--
-- Waybar / SwayNC / swww-daemon BURADA DEĞİL: systemd user servisleri olarak
-- hyprland-session.target'a bağlılar (bkz. hm.nix). Bunun iki nedeni var:
--   1. Kapsamlama: hyprland-session.target yalnız bu oturumda aktifleşir —
--      generic graphical-session.target'a bağlansaydı başka bir bağlamda da
--      (ör. bir TTY oturumu) tetiklenebilirdi.
--   2. Çökme yönetimi: systemd Restart=on-failure verir, exec-once vermez.
--
-- Burada yalnız tema restorasyonu var: son duvar kağıdı (yoksa Stylix
-- varsayılanı) swww'ye basılır; renk dosyaları eksikse matugen bir kez koşar.
hl.on("hyprland.start", function()
    hl.exec_cmd("theme-apply --restore")
end)
