# Harici ekran (HDMI): port muxsuz, dGPU'da (64:00.0). Bayrak iki DRM guard'ını gevşetir; render
# iGPU'da kalır. Kapatmak oturum yeniden başlatma ister (env PAM'den).
{ config, lib, ... }:

let
  cfg = config.desktop.externalDisplay;
in
{
  options.desktop.externalDisplay.enable = lib.mkEnableOption ''
    harici ekran (HDMI) — compositor dGPU'nun DRM node'unu da acar.
    HDMI portu bu makinede MUXSUZ ve dogrudan NVIDIA dGPU'ya bagli;
    guard acikken o konektor hic surulemez. Hibrit mod korunur (mux.nix DEGIL)
  '';

  config = lib.mkIf cfg.enable {
    # Değerler guard'ların dosyalarında koşullu (cosmic.nix, gnome.nix).

    warnings = lib.optional config.desktop.dgpuOnly.enable ''
      desktop.externalDisplay.enable = true iken desktop.dgpuOnly.enable = true
      ANLAMSIZ: dgpuOnly zaten compositor'ı SADECE dGPU'ya bağlar ve bu bayrağın
      eklediği izni mkForce ile ezer. Birini kapat.
    '';
  };
}
