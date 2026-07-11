# Noctalia v5 — rice.shell = "noctalia" iken aktif (deneme kabuğu)
# GUI runtime ayarları ~/.local/state/noctalia/settings.toml'a yazılır;
# buradaki settings (config.toml) build'de validateConfig ile doğrulanır —
# mutable-copy hilesi GEREKMEZ.
{ inputs, lib, pkgs, config, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  config = lib.mkIf (config.rice.shell == "noctalia") {
    programs.noctalia = {
      enable = true;
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      systemd.enable = true; # noctalia.service → graphical-session.target (UWSM)
      settings = {
        wallpaper.directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
      };
    };
    # NOT: power-profiles-daemon bilerek KAPALI (TLP kullanılıyor — tlp.nix);
    # Noctalia'nın güç profili widget'ı uyarı verebilir — kabul edildi.
  };
}
