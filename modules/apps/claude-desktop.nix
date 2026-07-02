# Claude Desktop (topluluk flake'i: k3d3/claude-desktop-linux-flake)
# MCP gerekirse claude-desktop-with-fhs varyantına geçilebilir.
{ inputs, pkgs, ... }:

{
  home.packages = [
    inputs.claude-desktop.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
  ];
}
