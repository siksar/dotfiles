# GNOME kullanıcı ayarları (HM) — kısayol temel seti
# İlke: GNOME varsayılanları esas; yalnız Hyprland kas hafızasının özü taşınır.
# Kilit ekranı zaten GNOME varsayılanı SUPER+L — dokunulmaz.
{ lib, ... }:

let
  ws = lib.range 1 9;

  # SUPER+1..9 → çalışma alanı geçişi (GNOME varsayılanında dock favorileri)
  wsSwitch = lib.listToAttrs (map (i: {
    name = "switch-to-workspace-${toString i}";
    value = [ "<Super>${toString i}" ];
  }) ws);

  # Dock favori kısayolları boşaltılır ki SUPER+1..9 çakışmasın
  appClear = lib.listToAttrs (map (i: {
    name = "switch-to-application-${toString i}";
    value = [ ];
  }) ws);

  kbPath = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings";
in
{
  dconf.settings = {
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
    } // wsSwitch;

    "org/gnome/shell/keybindings" = appClear // {
      # GNOME yerleşiği SUPER+M'yi bildirim/takvim paneline verir ve gsd
      # custom kısayolundan ÖNCE yutar → yalnız SUPER+V'de kalsın; SUPER+M
      # fan döngüsüne boşalır. (Fn+F7 EC'de yutuluyor, OS'e olay düşmüyor —
      # bkz. gigabyte-wmi.nix hwdb notu; bu yüzden fan SUPER+M'de.)
      toggle-message-tray = [ "<Super>v" ];
    };

    # VRR (oyun; panel 48-165Hz) — bkz. docs/gaming.md
    "org/gnome/mutter" = {
      experimental-features = [ "variable-refresh-rate" ];
    };

    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "${kbPath}/terminal/"
        "${kbPath}/fan-mode/"
        "${kbPath}/claude/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/terminal" = {
      name = "Terminal";
      binding = "<Super>Return";
      command = "ghostty";
    };
    # Fan modu döngüsü 0→1→2→5 — polkit kuralı şifresiz izin verir,
    # bildirim düşer; bkz. modules/hardware/gigabyte-wmi.nix
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/fan-mode" = {
      name = "Fan mode cycle";
      binding = "<Super>m";
      command = "systemctl start --no-block fan-mode-cycle.service";
    };
    # Copilot tuşu = Meta+Shift+F23 (libinput ile doğrulandı)
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/claude" = {
      name = "Claude Desktop";
      binding = "<Shift><Super>F23";
      command = "claude-desktop";
    };
  };
}
