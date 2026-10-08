# hyprglass — rev Hyprland sürümüne kilitli (upstream hyprpm.toml commit_pins);
# Hyprland güncellenince eşine geç, yoksa eklenti yüklenmez.
{ lib, mkHyprlandPlugin, fetchFromGitHub, wayland-scanner, hyprland }:

mkHyprlandPlugin {
  pluginName = "hyprglass";
  version = "0.9.1";
  inherit hyprland;

  src = fetchFromGitHub {
    owner = "hyprnux";
    repo = "hyprglass";
    rev = "99f30ca394bd0058ee79bf1c272c320f223e4540";
    hash = "sha256-V8w1SLd9u2wfMh0kvFkHbhV9I5wDQey0S2SyfvGo2LM=";
  };

  nativeBuildInputs = [ wayland-scanner ];

  # .git yok → Makefile sürümü "dev" yazardı; hyprctl plugin list doğru göstersin.
  makeFlags = [ "HYPRGLASS_VERSION=0.9.1" ];

  # HM'in pluginPath'i lib/lib<pname>.so bekliyor.
  installPhase = ''
    runHook preInstall
    install -Dm755 hyprglass.so $out/lib/libhyprglass.so
    runHook postInstall
  '';

  meta = {
    description = "Liquid Glass inspired blur/refraction for Hyprland windows";
    homepage = "https://github.com/hyprnux/hyprglass";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
