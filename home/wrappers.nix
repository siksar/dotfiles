# ============================================================================
# HOW TO CREATE WRAPPERS IN NIX
# ============================================================================
# User asked: "Bana wrapper ogretebilir misin? Bazi uygulamalar icin wrapper yapmam gerekebilir orn deezer gibi."
#
# A "wrapper" wraps a program to set environment variables or arguments before it runs.
# In Nix, we use `makeWrapper`.
#
# Example Usage in configuration.nix or home.nix:
#
# environment.systemPackages = [
#   (pkgs.symlinkJoin {
#     name = "deezer-wrapped";
#     paths = [ pkgs.deezer ];
#     buildInputs = [ pkgs.makeWrapper ];
#     postBuild = ''
#       wrapProgram $out/bin/deezer \
#         --set GDK_SCALE 2 \
#         --add-flags "--enable-features=UseOzonePlatform --ozone-platform=wayland"
#     '';
#   })
# ];

# ============================================================================
# SIMPLE SHELL SCRIPT METHOD (For quick fixes)
# ============================================================================
# You can also just make a script in bin:

# #!/bin/sh
# export ENV_VAR=value
# exec /path/to/original/app "$@"

{ pkgs, ... }:
{
  # Example: Creating a wrapper for 'deezer' (if installed) to force Wayland
  home.packages = [
    (pkgs.writeShellScriptBin "deezer-wayland" ''
      # This is a simple wrapper script
      export NIXOS_OZONE_WL=1
      # Assuming 'deezer' is in your PATH (e.g. from Flatpak or other source if not in pkgs)
      exec deezer --enable-features=UseOzonePlatform --ozone-platform=wayland "$@"
    '')
  ];
}
