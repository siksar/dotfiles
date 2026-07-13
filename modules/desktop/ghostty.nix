# Ghostty terminali
# Renkler ve font Stylix'ten gelir (targets.ghostty otomatik) — tema AYARLAMA.
{ config, ... }:

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
      # Yeni pencere/sekme varsayılan olarak flake köküyle açılsın (claude/opencode
      # de dolayısıyla oradan başlar) — yeni sekmeler yine önceki cwd'yi devralır.
      working-directory = "/home/zixar/nixos-zixar";
    };
  };
}
