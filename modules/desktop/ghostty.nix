# Ghostty terminali
# Renkler Stylix'ten DEĞİL, Caelestia'nın OSC dizilerinden gelir (canlı tema).
# OSC tekrarı yalnız caelestia aktifken basılır (rice.shell).
{ config, lib, ... }:

{
  programs.ghostty = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      font-family = config.stylix.fonts.monospace.name;
      font-size = 13;
      window-padding-x = 8;
      window-padding-y = 8;
      confirm-close-surface = false;
    };
  };

  # Yeni açılan terminaller aktif Caelestia şemasını alsın:
  # cli, son OSC dizilerini sequences.txt'de saklar; interaktif kabukta basılır.
  programs.bash.initExtra = lib.optionalString (config.rice.shell == "caelestia") ''
    # Caelestia terminal renkleri (yalnızca grafik oturumdaki interaktif kabuk)
    if [ -n "$PS1" ] && [ -n "$WAYLAND_DISPLAY$DISPLAY" ] \
       && [ -f "$HOME/.local/state/caelestia/sequences.txt" ]; then
      command cat "$HOME/.local/state/caelestia/sequences.txt"
    fi
  '';
}
