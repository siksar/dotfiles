{ pkgs, ... }:

{
  stylix = import ../../lib/theme.nix { inherit pkgs; } // {
    # Özel limine teması korunur (system/init/limine.nix).
    targets.limine.enable = false;
    targets.plymouth.enable = false;
  };
}
