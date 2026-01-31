{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Anime & Manga
    ani-cli       # CLI anime viewer
    mangal        # CLI manga reader
    youtube-tui   # Modern TUI YouTube player
    
    # Wrappers (Tools to help creating wrappers)
    # (makeWrapper is usually part of buildInputs in nix derivations, 
    # but for manual scripting we can use simple shell scripts)
  ];
}
