{ config, pkgs, noctalia, ... }:

{
  programs.noctalia-shell = {
    enable = true;
    # Enable systemd integration for automatic startup
    systemd.enable = true;
    
    # Use the package from the flake input
    package = noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
    
    # Basic settings only to ensure stability
    settings = {
      # Minimal configuration if needed, otherwise rely on defaults
    };
  };
}
