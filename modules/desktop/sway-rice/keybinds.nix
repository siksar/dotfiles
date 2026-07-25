# Sway rice kısayol tablosu — TEK KAYNAK.
#
# `binds` burada VERİ olarak tutulur (sway'in bindsym sözdizimi değil); hm.nix
# bundan hem gerçek sway keybindings attrset'ini hem Mod+G cheatsheet'inin TSV
# verisini üretir, docs/sway-rice.md'deki tablo da elle bu listeden senkron
# tutulur. Bir kısayol eklendiğinde/değiştiğinde üçü ASLA ayrışamaz.
#
# Script action'ları store yoluyla DEĞİL, PATH'teki isimleriyle çağrılır
# (ör. "exec sway-screenshot") — vyrx'in orijinal `exec ~/Scripts/foo`
# deseninin karşılığı, ve Mod+G'nin kendi eylemi (sway-cheatsheet) ile
# aralarında Nix-seviyesinde bir döngü oluşmasını önler (cheatsheet verisi
# binds listesinden üretiliyor; binds listesi cheatsheet'in store yolunu
# BİLMEK zorunda kalmasın diye). Script derivasyonları hm.nix'te
# home.packages'a eklenir, böylece PATH'te bulunurlar.
{ lib }:

let
  mod = "Mod4";
  terminal = "ghostty";

  b = group: keys: action: desc: { inherit group keys action desc; };
in
rec {
  binds = [
    ############################################################
    # Pencere & düzen
    ############################################################
    (b "Pencere" "${mod}+Return" "exec ${terminal}" "Terminal aç (ghostty)")
    (b "Pencere" "${mod}+q" "kill" "Odaktaki pencereyi kapat")
    (b "Pencere" "${mod}+f" "fullscreen" "Tam ekran")
    (b "Pencere" "${mod}+w" "layout tabbed" "Sekmeli düzen")
    (b "Pencere" "${mod}+v" "layout toggle split" "Bölme yönünü değiştir")
    (b "Pencere" "${mod}+Shift+v" "floating toggle" "Kayan pencere aç/kapat")
    (b "Pencere" "${mod}+h" "focus left" "Sola odaklan")
    (b "Pencere" "${mod}+l" "focus right" "Sağa odaklan")
    (b "Pencere" "${mod}+j" "workspace prev" "Önceki çalışma alanı")
    (b "Pencere" "${mod}+k" "workspace next" "Sonraki çalışma alanı")
    (b "Pencere" "${mod}+Left" "focus left" "Sola odaklan (ok tuşu)")
    (b "Pencere" "${mod}+Right" "focus right" "Sağa odaklan (ok tuşu)")
    (b "Pencere" "${mod}+Up" "focus up" "Yukarı odaklan (ok tuşu)")
    (b "Pencere" "${mod}+Down" "focus down" "Aşağı odaklan (ok tuşu)")
    (b "Pencere" "${mod}+Shift+h" "move left" "Pencereyi sola taşı")
    (b "Pencere" "${mod}+Shift+l" "move right" "Pencereyi sağa taşı")
    (b "Pencere" "${mod}+Shift+Left" "move left" "Pencereyi sola taşı (ok)")
    (b "Pencere" "${mod}+Shift+Right" "move right" "Pencereyi sağa taşı (ok)")
    (b "Pencere" "${mod}+Shift+Up" "move up" "Pencereyi yukarı taşı (ok)")
    (b "Pencere" "${mod}+Shift+Down" "move down" "Pencereyi aşağı taşı (ok)")
  ]
  ++ (lib.concatMap
    (i: [
      (b "Çalışma alanı" "${mod}+${toString i}" "workspace number ${toString i}"
        "${toString i}. çalışma alanına git")
      (b "Çalışma alanı" "${mod}+Shift+${toString i}"
        "move container to workspace number ${toString i}"
        "Pencereyi ${toString i}. çalışma alanına taşı")
    ])
    (lib.range 1 9))
  ++ [
    (b "Çalışma alanı" "${mod}+0" "workspace number 10" "10. çalışma alanına git")
    (b "Çalışma alanı" "${mod}+Shift+0" "move container to workspace number 10"
      "Pencereyi 10. çalışma alanına taşı")
    (b "Pencere" "${mod}+minus" "scratchpad show" "Scratchpad'i göster")
    (b "Pencere" "${mod}+Shift+minus" "move scratchpad" "Pencereyi scratchpad'e gönder")
    (b "Pencere" "${mod}+Shift+z" ''mode "resize"'' "Boyutlandırma moduna gir (hjkl/oklar, Enter/Esc çıkar)")
    (b "Pencere" "${mod}+Shift+c" "reload" "Sway config'ini yeniden yükle")
    (b "Pencere" "${mod}+Shift+e"
      ''exec swaynag -t warning -m "Sway'den çıkılsın mı?" -B "Evet" "swaymsg exit"''
      "Sway oturumunu kapat (onaylı)")

    ############################################################
    # Uygulamalar
    ############################################################
    (b "Uygulama" "${mod}+b" "exec zen" "Tarayıcı (zen)")
    (b "Uygulama" "${mod}+e" "exec nautilus" "Dosya yöneticisi (nautilus)")
    (b "Uygulama" "${mod}+c" "exec codium" "VSCodium")
    (b "Uygulama" "${mod}+o" "exec obsidian" "Obsidian")
    (b "Uygulama" "${mod}+d" "exec vesktop" "Vesktop (Discord)")
    (b "Uygulama" "${mod}+m" "exec deezer-enhanced" "Deezer")
    (b "Uygulama" "${mod}+Shift+t" "exec ${terminal} -e toofan" "Yazma pratiği (toofan)")

    ############################################################
    # Terminal uygulamaları
    ############################################################
    (b "Terminal uygulaması" "Alt+slash" "exec ${terminal} -e btop" "Sistem izleyici (btop)")
    (b "Terminal uygulaması" "Alt+n" "exec ${terminal} -e nvim" "Neovim")
    (b "Terminal uygulaması" "Alt+m" "exec ${terminal} -e rmpc" "Müzik istemcisi (rmpc)")
    (b "Terminal uygulaması" "Alt+q" "exec ${terminal} -e yazi" "Dosya yöneticisi (yazi)")
    (b "Terminal uygulaması" "Alt+Escape" "exec ${terminal} -e tmux a" "tmux oturumuna bağlan")
    (b "Terminal uygulaması" "Alt+g" ''exec ${terminal} --title=gh-dash -e gh dash'' "GitHub dashboard (gh dash)")
    (b "Terminal uygulaması" "Alt+i" "exec kanshi-switch" "Monitör profili seç (kanshi)")
    (b "Terminal uygulaması" "Alt+c" "exec cava" "Ses görselleştirici (cava, elle açılır)")

    ############################################################
    # Web uygulamaları (launch-webapp → chromium --app)
    ############################################################
    (b "Web uygulaması" "${mod}+a" "exec launch-webapp https://chatgpt.com" "ChatGPT")
    (b "Web uygulaması" "${mod}+Alt+a" "exec launch-webapp https://claude.ai" "Claude")
    (b "Web uygulaması" "${mod}+Shift+a" "exec launch-webapp https://gemini.google.com" "Gemini")
    (b "Web uygulaması" "${mod}+t" "exec launch-webapp https://app.todoist.com/app" "Todoist")
    (b "Web uygulaması" "${mod}+y" "exec launch-webapp https://youtube.com" "YouTube")
    (b "Web uygulaması" "${mod}+Shift+g" "exec launch-webapp https://github.com" "GitHub")
    (b "Web uygulaması" "${mod}+x" "exec launch-webapp https://x.com" "X (Twitter)")
    (b "Web uygulaması" "${mod}+Shift+w" "exec launch-webapp https://web.whatsapp.com" "WhatsApp")
    (b "Web uygulaması" "${mod}+backslash" "exec launch-webapp https://devhints.io" "DevHints")

    ############################################################
    # Yardım
    ############################################################
    (b "Yardım" "${mod}+g" "exec sway-cheatsheet" "Kısayol listesini göster (aranabilir, Enter çalıştırır)")

    ############################################################
    # noctalia panelleri
    ############################################################
    (b "noctalia" "${mod}+Space" "exec noctalia msg launcher toggle" "Uygulama başlatıcı")
    (b "noctalia" "${mod}+n" "exec noctalia msg panel-toggle control-center notifications" "Bildirim paneli")
    (b "noctalia" "${mod}+Shift+n" "exec noctalia msg notification-clear-active" "Aktif bildirimi temizle")
    (b "noctalia" "${mod}+Ctrl+n" "exec noctalia msg notification-dnd-toggle" "Rahatsız etme aç/kapat")
    (b "noctalia" "${mod}+s" "exec noctalia msg panel-toggle control-center audio" "Ses paneli")
    (b "noctalia" "${mod}+period" "exec noctalia msg panel-toggle control-center network" "Ağ paneli")
    (b "noctalia" "${mod}+comma" "exec noctalia msg panel-toggle control-center system" "Sistem paneli")
    (b "noctalia" "${mod}+i" "exec noctalia msg caffeine-toggle" "Uyanık kalma (caffeine) aç/kapat")
    (b "noctalia" "${mod}+Alt+n" "exec noctalia msg nightlight-toggle" "Gece ışığı aç/kapat")
    (b "noctalia" "${mod}+Shift+space" "exec noctalia msg bar-toggle" "Bar'ı gizle/göster")
    (b "noctalia" "${mod}+Escape" "exec noctalia msg panel-toggle session" "Oturum paneli (kapat/yeniden başlat/kilitle)")
    (b "noctalia" "${mod}+Alt+l" "exec noctalia msg session lock" "Ekranı kilitle")
    (b "noctalia" "Ctrl+Alt+space" "exec noctalia msg wallpaper-random" "Rastgele duvar kağıdı")
    (b "noctalia" "${mod}+Ctrl+Shift+space" "exec noctalia msg panel-toggle wallpaper" "Duvar kağıdı paneli")
    (b "noctalia" "Alt+comma" "exec noctalia msg clipboard-toggle" "Pano geçmişi")
    (b "noctalia" "Alt+period" "exec noctalia msg launcher toggle emo" "Emoji seçici")

    ############################################################
    # Ekran görüntüsü / kayıt
    ############################################################
    (b "Ekran görüntüsü" "${mod}+p" "exec sway-screenshot" "Bölge seçerek ekran görüntüsü (satty ile düzenle)")
    (b "Ekran görüntüsü" "${mod}+Shift+p" "exec sway-screenshot fullscreen" "Tam ekran görüntüsü")
    (b "Ekran görüntüsü" "Alt+p" ''exec grim -g "$(slurp -d)" - | wl-copy'' "Bölge rengi kopyala (renk seçici)")
    (b "Ekran kaydı" "${mod}+r" "exec sway-screenrecord --with-desktop-audio" "Ekran kaydı (masaüstü sesiyle)")
    (b "Ekran kaydı" "${mod}+Alt+r" "exec sway-screenrecord --region" "Bölge kaydı")
    (b "Ekran kaydı" "${mod}+Shift+r" "exec sway-screenrecord --with-microphone-audio" "Ekran kaydı (mikrofonla)")

    ############################################################
    # Donanım tuşları
    ############################################################
    (b "Donanım" "--locked XF86AudioMute" "exec noctalia msg volume-mute" "Sesi kapat/aç")
    (b "Donanım" "--locked XF86AudioLowerVolume" "exec noctalia msg volume-down" "Ses azalt")
    (b "Donanım" "--locked XF86AudioRaiseVolume" "exec noctalia msg volume-up" "Ses artır")
    (b "Donanım" "--locked XF86AudioMicMute" "exec noctalia msg mic-mute" "Mikrofonu kapat/aç")
    (b "Donanım" "--locked XF86MonBrightnessDown" "exec noctalia msg brightness-down" "Ekran parlaklığı azalt")
    (b "Donanım" "--locked XF86MonBrightnessUp" "exec noctalia msg brightness-up" "Ekran parlaklığı artır")
    (b "Donanım" "${mod}+XF86AudioRaiseVolume" "exec ddcutil setvcp 10 + 10" "Harici monitör parlaklığı artır")
    (b "Donanım" "${mod}+XF86AudioLowerVolume" "exec ddcutil setvcp 10 - 10" "Harici monitör parlaklığı azalt")
    (b "Donanım" "${mod}+F10" "exec playerctl previous" "Önceki parça")
    (b "Donanım" "${mod}+F11" "exec playerctl play-pause" "Oynat/duraklat")
    (b "Donanım" "${mod}+F12" "exec playerctl next" "Sonraki parça")
    (b "Donanım" "--locked XF86PowerOff" "exec systemctl suspend" "Uykuya al")

    ############################################################
    # Diğer
    ############################################################
    (b "Diğer" "Ctrl+Shift+1" "exec toggle-output eDP-1" "Dahili ekranı aç/kapat")
    (b "Diğer" "Ctrl+Shift+2" "exec toggle-output" "Harici ekranı aç/kapat")
    (b "Diğer" "${mod}+Shift+BackSpace" "exec run-scrcpy mirror" "Telefon ekranını yansıt (scrcpy)")
    (b "Diğer" "${mod}+Ctrl+BackSpace" "exec run-scrcpy webcam" "Telefonu webcam yap (scrcpy)")
    (b "Diğer" "${mod}+Shift+m" "exec beats" "Radyo/YouTube ses istasyonları (beats)")
    (b "Diğer" "${mod}+Alt+space" "exec game-menu" "Kurulu oyun menüsü")
  ];

  # sway'in beklediği { "Mod4+Return" = "exec ghostty"; ... } biçimi.
  keybindings = lib.listToAttrs (map (bind: lib.nameValuePair bind.keys bind.action) binds);
}
