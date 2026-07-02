# greetd + tuigreet — Caelestia dots'un önerdiği login yöneticisi
# Renkler Stylix'in build-time paletinden gelir (greeter login öncesi
# çalıştığı için runtime tema geçişinden etkilenmez).
{ pkgs, config, lib, ... }:

let
  c = config.lib.stylix.colors;
  theme = lib.concatStringsSep ";" [
    "border=#${c.base0D}"
    "text=#${c.base05}"
    "prompt=#${c.base0D}"
    "action=#${c.base0C}"
    "button=#${c.base0D}"
    "container=#${c.base00}"
    "input=#${c.base02}"
  ];
in
{
  services.displayManager.sddm.enable = false;

  services.greetd = {
    enable = true;
    # nixpkgs'in TTY greeter ayarları (Type=idle, TTYReset vb.) — boot logu
    # ekrana taşmasın diye gerekli
    useTextGreeter = true;
    settings.default_session = {
      command = lib.concatStringsSep " " [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--time-format '%H:%M  %A %d %B'"
        "--sessions /run/current-system/sw/share/wayland-sessions"
        "--remember"
        "--remember-user-session"
        "--asterisks"
        "--theme '${theme}'"
        "--power-shutdown 'systemctl poweroff'"
        "--power-reboot 'systemctl reboot'"
      ];
      user = "greeter";
    };
  };

  # --remember için kalıcı önbellek
  systemd.tmpfiles.rules = [ "d /var/cache/tuigreet 0755 greeter greeter - -" ];
}
