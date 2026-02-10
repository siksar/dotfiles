{ config, pkgs, ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = false;
    
    settings = builtins.fromTOML (builtins.readFile ./starship/themes/tokyo-night.toml);
  };
}
