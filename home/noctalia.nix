{ config, pkgs, lib, ... }:
{
  # ========================================================================
  # NOCTALIA SHELL - Hyprland Desktop Shell
  # ========================================================================
  # noctalia-shell artık nixpkgs unstable'da mevcut.
  # Home Manager modülü: modules/noctalia-home.nix (lokal kopyası)
  imports = [ ../base/modules/noctalia-home.nix ];

  programs.noctalia-shell = {
    enable = true;
    package = pkgs.noctalia-shell;
    systemd.enable = true;

    settings = {
      bar = {
        position = "top";
        height = 36;
        transparent = true;
      };

      theme = {
        mode = "dark";
      };

      modules = {
        clock = {
          format = "%H:%M";
          date_format = "%Y-%m-%d";
        };
      };
    };
  };
}
