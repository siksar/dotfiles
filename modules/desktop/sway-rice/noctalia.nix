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

  # Pil düşük eşiği bildirimi — vyrx'in battery-monitor daemon'ının karşılığı.
  # $NOCTALIA_BATTERY_PERCENT noctalia'nın hook ortamına koyduğu değişken;
  # ''${...} Nix'in ''-string antiquotation'ını KAÇIRIR, kabuğa ham geçer.
  hooks.battery_low_percent_threshold = 15;
  hooks.battery_under_threshold = ''notify-send -u critical "Pil" "''${NOCTALIA_BATTERY_PERCENT}% kaldı"'';

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
