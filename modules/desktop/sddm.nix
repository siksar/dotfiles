{ ... }:

{
  # SDDM kaldırıldı — greeter yok, TTY1'de doğrudan otomatik giriş
  services.displayManager.sddm.enable = false;
  services.getty.autologinUser = "zixar";
}
