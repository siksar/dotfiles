{ pkgs, ... }:

{
  # greetd: greeter olmadan doğrudan UWSM → Hyprland başlatır
  # display-manager.service'i karşılar, logind session'ını düzgün açar
  services.displayManager.sddm.enable = false;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.uwsm}/bin/uwsm start hyprland-uwsm.desktop";
        user    = "zixar";
      };
    };
  };
}
