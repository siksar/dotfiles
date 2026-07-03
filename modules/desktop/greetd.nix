# greetd + tuigreet — Caelestia dots'un önerdiği login yöneticisi
# Tema: son seçilen Caelestia şeması /var/cache/tuigreet/theme.conf'a
# postHook ile yazılır (bkz. caelestia/default.nix); dosya yoksa Stylix
# build-time paleti (everforest) kullanılır.
{ pkgs, config, lib, ... }:

let
  c = config.lib.stylix.colors;
  defaultTheme = lib.concatStringsSep ";" [
    "border=#${c.base0D}"
    "text=#${c.base05}"
    "prompt=#${c.base0D}"
    "action=#${c.base0C}"
    "button=#${c.base0D}"
    "container=#${c.base00}"
    "input=#${c.base02}"
  ];

  tuigreet-run = pkgs.writeShellScript "tuigreet-run" ''
    THEME="$(cat /var/cache/tuigreet/theme.conf 2>/dev/null)"
    [ -n "$THEME" ] || THEME='${defaultTheme}'
    exec ${lib.getExe pkgs.tuigreet} \
      --time \
      --time-format '%H:%M  %A %d %B' \
      --sessions /run/current-system/sw/share/wayland-sessions \
      --remember \
      --remember-user-session \
      --asterisks \
      --theme "$THEME" \
      --power-shutdown 'systemctl poweroff' \
      --power-reboot 'systemctl reboot'
  '';
in
{
  services.displayManager.sddm.enable = false;

  services.greetd = {
    enable = true;
    # nixpkgs'in TTY greeter ayarları (Type=idle, TTYReset vb.) — boot logu
    # ekrana taşmasın diye gerekli
    useTextGreeter = true;
    settings.default_session = {
      command = "${tuigreet-run}";
      user = "greeter";
    };
  };

  systemd.tmpfiles.rules = [
    # --remember için kalıcı önbellek
    "d /var/cache/tuigreet 0755 greeter greeter - -"
    # Tema dosyası: caelestia postHook (kullanıcı) yazar, greeter okur
    "f /var/cache/tuigreet/theme.conf 0664 greeter users - -"
  ];
}
