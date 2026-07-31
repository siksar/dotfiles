# Limine önyükleyici (systemd-boot yerine) + Miasma teması.
# Stylix'in limine hedefi bilerek kapalı: system/desktop/theme.nix
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
      timeout: 3
      interface_resolution: 2560x1600
      resolution: 2560x1600
      term_font_scale: 2x2
      term_margin: 0
    '';

    style = {
      # Miasma arka plan rengi (wallpaper yok → terminal UI)
      backdrop = "1a1a1a";

      interface = {
        branding         = "Zixar";
        brandingColor    = "5faf5f"; # Miasma green
        helpColor        = "5faf5f";
        helpColorBright  = "d7af5f"; # Miasma amber
      };

      # Miasma renk paleti
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
