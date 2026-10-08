# streamrip (rip). Deezer ARL'si ~/.config/streamrip/config.toml'da elle; Nix dokunmaz.
{ pkgs, ... }:

{
  home.packages = [ pkgs.streamrip ];
}
