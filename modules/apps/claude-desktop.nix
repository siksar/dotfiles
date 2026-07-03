# Claude Desktop — resmî Linux .deb paketi (bkz. claude-desktop-pkg.nix)
{ pkgs, ... }:

{
  home.packages = [ (pkgs.callPackage ./claude-desktop-pkg.nix { }) ];
}
