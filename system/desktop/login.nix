# COSMIC greeter — giriş ekranı.
#
# COSMIC oturumu ile aynı görsel yığını kullanır ve SDDM/kwin greeter'ının
# ayrı tema, PAM ve DRM ayarlarını gerektirmez. Varsayılan masaüstü oturumu
# configuration.nix'te ayrıca seçilir; greeter yalnız oturum seçimini yapar.
{ ... }:

{
  services.displayManager.cosmic-greeter = {
    enable = true;
  };
}
