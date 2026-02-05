{ config, pkgs, ... }:

{
  # ========================================================================
  # STARSHIP THEMES CONFIGURATION
  # ========================================================================
  # Bu dosya Starship temalarını ~/.config/starship/themes altına linkler
  # ve varsayılan current.toml dosyasını oluşturur.
  # ========================================================================

  xdg.configFile = {
    "starship/themes/pastel-powerline.toml".source = ./themes/pastel-powerline.toml;
    "starship/themes/tokyo-night.toml".source = ./themes/tokyo-night.toml;
    "starship/themes/gruvbox-rainbow.toml".source = ./themes/gruvbox-rainbow.toml;
    "starship/themes/catppuccin-powerline.toml".source = ./themes/catppuccin-powerline.toml;
  };
  
  # Varsayılan olarak bir "current.toml" dosyası oluştur (eğer yoksa)
  # Bu dosya mutable (değiştirilebilir) olmalı çünkü script bunu değiştirecek.
  # Ancak home-manager ile mutable dosya oluşturmak zor (read-only link).
  #
  # ÇÖZÜM: Script, ~/.config/starship/current.toml dosyasını kopyalayarak oluşturacak.
  # Zsh başladığında bu dosya yoksa varsayılan bir temayı kopyalayacağız.
}
