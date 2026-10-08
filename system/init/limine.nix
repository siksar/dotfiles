{ ... }:

{
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.limine = {
    enable         = true;
    maxGenerations = 10;

    # Ayrı UEFI entry; systemd-boot ESP'de yedek olarak kalır (F12 → Linux Boot Manager).
    efiInstallAsRemovable = false;

    extraConfig = ''
      timeout: 3
      interface_resolution: 2560x1600
      resolution: 2560x1600
      term_font_scale: 2x2
      term_margin: 0
    '';

    style = {
      backdrop = "1a1a1a";

      interface = {
        branding         = "Zixar";
        brandingColor    = "5faf5f";
        helpColor        = "5faf5f";
        helpColorBright  = "d7af5f";
      };

      graphicalTerminal = {
        palette       = "080808;d75f5f;5faf5f;d7af5f;5f87af;af5faf;5fafaf;d3d0c8";
        brightPalette = "1c1c1c;d75f5f;5faf5f;d7af5f;5f87af;af5faf;5fafaf;ffffff";
        foreground        = "d3d0c8";
        brightForeground  = "ffffff";
        background        = "1a1a1a";
        brightBackground  = "222222";
      };
    };
  };
}
