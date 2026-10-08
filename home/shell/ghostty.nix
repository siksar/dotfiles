# Renk/font Stylix'ten; font-size Stylix'inkinden sonra yazıldığı için kazanır.
{ config, ... }:

{
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = config.stylix.fonts.monospace.name;
      font-size = 13;
      window-padding-x = 8;
      window-padding-y = 8;
      confirm-close-surface = false;
      resize-overlay = "never";
      # Shell entegrasyonunun "cursor" özelliği imleci yanıp söndürüyor → kapalı.
      cursor-style-blink = false;
      shell-integration-features = "no-cursor";
      working-directory = "/home/zixar/nixos-zixar";
    };
  };
}
