# DankMaterialShell — rice.shell = "dms" iken aktif (deneme kabuğu)
# Ayarlar (settings.json) DMS tarafından RUNTIME'da yönetilir — HM'e bağlama
# (caelestia shell.json'daki mutable-copy sorunu tekrarlanmasın).
# İlk açılışta duvar kağıdı DankDash GUI'sinden seçilir: ~/Pictures/Wallpapers
{ inputs, lib, config, ... }:

{
  imports = [ inputs.dms.homeModules.dank-material-shell ];

  config = lib.mkIf (config.rice.shell == "dms") {
    programs.dank-material-shell = {
      enable = true;
      systemd.enable = true;         # dms.service → graphical-session.target (UWSM)
      enableSystemMonitoring = true; # dgop (CPU/RAM widget'ları)
      enableDynamicTheming = true;   # matugen: duvar kağıdından canlı tema
      enableClipboardPaste = true;   # cliphist entegrasyonu
    };

    # Upstream'in önerdiği layer kuralları (animasyon çakışmasını önler)
    wayland.windowManager.hyprland.extraConfig = ''
      layerrule = no_anim on, match:namespace ^(quickshell)$
      layerrule = no_anim on, match:namespace ^dms:.*
    '';
  };
}
