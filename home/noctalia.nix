{ config, pkgs, noctalia, ... }:

{
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = false;
    
    # Use the package from the flake input
    package = noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # settings = {
    #   bar = {
    #     position = "bottom";
    #     floating = true;
    #     backgroundOpacity = 0.95;
    #   };
    #   general = {
    #     animationSpeed = 1.0;
    #     radiusRatio = 1.25;
    #   };
    #   colorSchemes = {
    #     darkMode = true;
    #     useWallpaperColors = true;
    #   };
    # };

    # We can also handle colors here if needed, or let dynamic wallpaper colors take over
    # colors = {
    #   # Example override if needed, otherwise empty to use defaults/wallpaper
    # };
  };

  # Remove manual package installation since it's now handled by the module
  # home.packages = ... (Noctalia package removed from here as it's in home.nix or handled by module)
}
