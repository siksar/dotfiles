# Pencere kuralları — vyrx-dev/dotfiles'ın assign/for_window listesinin
# bizim paket setimize uyarlanmış hali. app_id'ler `swaymsg -t get_tree`
# ile ilk girişte doğrulanmalı — electron/GTK uygulamalarının app_id'si
# derleyiciye/sürüme göre değişebilir; yanlış eşleşme sessizce no-op'tur
# (build'i bozmaz), en kötü ihtimalle kural uygulanmaz.
{ }:
{
  # Uygulama → sabit çalışma alanı
  assigns = {
    "2" = [ { app_id = "codium"; } ];
    "7" = [ { app_id = "org.telegram.desktop"; } ];
    "8" = [ { app_id = "obsidian"; } ];
    "9" = [ { app_id = "deezer-enhanced"; } ];
    "10" = [ { app_id = "vesktop"; } ];
  };

  window = {
    commands = [
      { command = "focus"; criteria = { app_id = "vesktop"; }; }
      { command = "focus"; criteria = { app_id = "obsidian"; }; }
      { command = "focus"; criteria = { app_id = "deezer-enhanced"; }; }
      { command = "focus"; criteria = { app_id = "codium"; }; }
      { command = "focus"; criteria = { app_id = "org.telegram.desktop"; }; }
      { command = "focus"; criteria = { app_id = "mpv"; }; }

      {
        command = "resize set width 960 height 540, move position center";
        criteria = { app_id = "mpv"; };
      }
      {
        command = "resize set width 1000 height 600, move position center";
        criteria = { app_id = "org.gnome.Nautilus"; };
      }
      {
        command = "resize set width 700 height 650, move position center";
        criteria = { app_id = "com.gabm.satty"; };
      }
    ];
  };

  floating = {
    criteria = [
      { app_id = "mpv"; }
      { app_id = "org.gnome.Nautilus"; }
      { app_id = "com.gabm.satty"; }
      { app_id = "pavucontrol"; }
    ];
  };
}
