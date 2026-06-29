{ ... }:

{
  boot.loader.systemd-boot.enable = false; # Limine aktif olduğunda devre dışı
  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.limine = {
    enable         = true;
    maxGenerations = 10;

    # Ayrı UEFI boot entry oluştur — systemd-boot ESP'de kalır, fallback olarak kullanılabilir.
    # Sorun olursa: F12 (boot menu) → "Linux Boot Manager" (systemd-boot) → eski generation
    efiInstallAsRemovable = false;

    extraConfig = ''
      remember_last_entry: yes
    '';

    style = {
      # Saf Tokyo Night arka plan rengi (wallpaper yok → terminal UI)
      backdrop = "1a1b26";

      interface = {
        branding         = "Omarchy Bootloader";
        brandingColor    = "9ece6a"; # Tokyo Night green
        helpColor        = "9ece6a";
        helpColorBright  = "9ece6a";
      };

      # Tokyo Night renk paleti (OMArchy limine.conf'tan)
      graphicalTerminal = {
        palette       = "15161e;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;a9b1d6";
        brightPalette = "414868;f7768e;9ece6a;e0af68;7aa2f7;bb9af7;7dcfff;c0caf5";
        foreground        = "c0caf5";
        brightForeground  = "c0caf5";
        background        = "1a1b26";
        brightBackground  = "24283b";
      };
    };
  };
}
