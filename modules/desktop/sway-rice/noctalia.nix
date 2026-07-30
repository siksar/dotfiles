# noctalia-shell ayarları — programs.noctalia.settings'e (attrset → TOML,
# build sırasında `noctalia config validate` ile doğrulanır) verilir.
# Alan adları noctalia v5 example.toml'a göre; ayrıntı: docs/sway-rice.md.
#
# GUI'nin çalışma zamanında yazdığı ~/.local/state/noctalia/settings.toml
# BURADAKİ değerleri ezebilir (katman 2 > katman 1) — bu kasıtlı, GUI'den
# yapılan geçici ayarlar rebuild'de kaybolmaz ama rebuild de GUI ayarını
# silmez; ikisi barışık yaşar.
{ cfgHome }:

{
  theme = {
    mode = "dark";
    source = "wallpaper";
    wallpaper_scheme = "m3-tonal-spot";
    pure_black_dark = false;
  };

  # ── HAZIR ŞABLONLAR KAPALI — pazarlık konusu değil ────────────────────────
  # noctalia varsayılan olarak `enable_builtin_templates = true` ile geliyor ve
  # hazır şablon listesi Stylix'in/HM'nin YÖNETTİĞİ uygulamaları içeriyor:
  # ghostty, gtk3, gtk4, qt, btop, fuzzel, helix, starship, cava, foot, kitty,
  # alacritty, emacs. Bunların apply.sh'ları HM dosyalarını arkadan düzenliyor —
  # ghostty'ninki tam olarak şunu yapıyor:
  #     sed -i -E 's/^theme\s*=.*/theme = noctalia/' ~/.config/ghostty/config
  # `sed -i` bir SYMLINK'İ DÜZ DOSYAYA ÇEVİRİR. HM'nin ghostty symlink'i böyle
  # yok oldu; sonraki her aktivasyon "yolumda yabancı dosya var" deyip
  # config.hm-backup'a yedekledi, ikinci seferde yedek çakıştı ve
  # home-manager-zixar.service exit 1 ile öldü — `nh os test` de `hms` de
  # bu yüzden düştü (26 Tem 01:26). btop/gtk-3.0/gtk-4.0/fuzzel'de de aynı
  # hasarın .hm-backup kalıntıları bulundu.
  #
  # Stylix sınırı ancak bu bayrak false iken gerçek: noctalia sadece kendi
  # UI'ını ve AŞAĞIDAKİ user şablonlarını boyar, HM'nin dosyalarına dokunmaz.
  theme.templates.enable_builtin_templates = false;
  theme.templates.enable_community_templates = false;

  theme.templates.user.sway = {
    input_path = "${cfgHome}/noctalia/templates/sway-colors";
    output_path = "~/.config/sway/colors";
    post_hook = "swaymsg reload";
  };
  theme.templates.user.fuzzel = {
    input_path = "${cfgHome}/noctalia/templates/fuzzel-colors.ini";
    output_path = "~/.config/fuzzel/colors.ini";
    # hook yok — fuzzel her açılışta config'i yeniden okur.
  };
  theme.templates.user.cava = {
    input_path = "${cfgHome}/noctalia/templates/cava-config";
    output_path = "~/.config/cava/colors";
    post_hook = "pkill -USR2 -x cava || true";
  };
  theme.templates.user.terminal-sequences = {
    input_path = "${cfgHome}/noctalia/templates/terminal-sequences";
    output_path = "~/.local/state/sway-rice/terminal-sequences";
    post_hook = "sway-theme-sequences";
  };

  wallpaper = {
    enabled = true;
    fill_mode = "crop";
    directory = "~/Pictures/Wallpapers";
    transition = [ "fade" "wipe" "disc" ];
    transition_duration = 1200;
  };

  bar.main = {
    position = "top";
    thickness = 34;
    start = [ "launcher" "wallpaper" "workspaces" ];
    center = [ "clock" "media" ];
    end = [
      "tray"
      "network"
      "volume"
      "brightness"
      "battery"
      "control-center"
      "session"
    ];
  };

  notification = {
    enable_daemon = true;
    show_app_name = true;
    show_actions = true;
  };

  osd.kinds = {
    volume = true;
    brightness = true;
    wifi = true;
    bluetooth = true;
    power_profile = true;
    caffeine = true;
    nightlight = true;
    dnd = true;
  };

  # swayidle+swaylock ikilisinin karşılığı — vyrx'in kanshi/swayidle config'inde
  # timeout 300 kilit, 600 ekran kapatma idi; aynı değerler.
  lockscreen.enabled = true;
  idle.behavior.lock = {
    enabled = true;
    timeout = 300;
    action = "lock";
  };
  idle.behavior.screen-off = {
    enabled = true;
    timeout = 600;
    action = "screen_off";
  };

  # Harici monitör parlaklığı ddcutil'den, dahili panel backlight'tan.
  # DİKKAT: cihaz adı doğrulanmalı — `ls /sys/class/backlight/` çıktısına göre
  # amdgpu_bl0/amdgpu_bl1 olabilir (Intel'in intel_backlight'ı DEĞİL, bu
  # makinede AMD iGPU var). Yanlışsa parlaklık tuşları sessizce no-op kalır.
  brightness = {
    enable_ddcutil = true;
    monitor."eDP-1" = {
      backend = "backlight";
      backlight_device = "amdgpu_bl1";
    };
  };

  # Pil düşük eşiği — vyrx'in battery-monitor daemon'ının karşılığı; bildirimi
  # noctalia kendisi basıyor, hook gerekmiyor.
  #
  # İLK SÜRÜM YANLIŞTI: `hooks.battery_low_percent_threshold` ve
  # `hooks.battery_under_threshold` diye iki anahtar uydurulmuştu; ikisi de yok.
  # `noctalia config validate` bunları HATA değil UYARI sayıp exit 0 döndürüyor
  # ("✓ Config is valid (2 warning(s))"), o yüzden build yeşil kaldı ve hata
  # ancak çalışırken journal'da görüldü. Yani HM modülünün build-time validate'i
  # yanlış DEĞERLERİ yakalar, yanlış ANAHTAR ADLARINI yakalamaz.
  #
  # Gerçek şema (`noctalia config export full`):
  #   [battery] warning_threshold = <int>
  #   [hooks]   battery_charging / battery_discharging / battery_plugged /
  #             battery_percentage_changed — hepsi KOMUT LİSTESİ (dizi), string değil.
  #             "eşiğin altına düştü" diye bir hook YOK.
  battery.warning_threshold = 15;

  # Idle güç bütçesine dokunmasın diye muhafazakâr poll aralıkları (varsayılanlar).
  # Ölçümde 4.28W tabanı gerilerse burası ilk kapatılacak yer.
  system.monitor = {
    enabled = true;
    cpu_poll_seconds = 2.0;
    gpu_poll_seconds = 5.0;
    memory_poll_seconds = 2.0;
    network_poll_seconds = 3.0;
    disk_poll_seconds = 10.0;
  };
}
