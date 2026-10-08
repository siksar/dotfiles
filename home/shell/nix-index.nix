# nix-index (hazır veritabanı, flake girdisi) + comma: `, <komut>`, nix-locate.
{ inputs, ... }:

{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
}
