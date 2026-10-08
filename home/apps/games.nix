# gamerun PATH'te: mc-run ve emu-run buna dayanır. MangoHud/gamescope bilerek yok (çöküyor).
{ pkgs, ... }:

{
  home.packages = [ (import ../../lib/gamerun.nix { inherit pkgs; }) ];
}
