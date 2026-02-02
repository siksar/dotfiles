{ config, pkgs, lib, noctalia, ... }:
{
  # ========================================================================
  # NOCTALIA SHELL - Modern Wayland Desktop Shell
  # ========================================================================
  
  imports = [ noctalia.homeModules.default ];
  
  programs.noctalia-shell = {
    enable = true;
    
    # Settings block removed to allow mutable configuration.
    # The application will now read/write from ~/.config/noctalia/settings.json directly
    # without NixOS overwriting it on every rebuild.
  };
}
