{ lib, stdenv, rustc }:

# Tek kaynak dosya, SIFIR crate bağımlılığı (ioctl main.rs'te elle bildiriliyor)
# → cargo/Cargo.lock/cargoHash/vendoring zinciri hiç kurulmuyor, `rustc` yeter.
# Kapanışa katkı: yalnızca binary (~400 KB) + zaten mevcut glibc.
stdenv.mkDerivation {
  pname = "kbd-rgb";
  version = "0.1.0";

  src = ./src;

  nativeBuildInputs = [ rustc ];

  buildPhase = ''
    runHook preBuild
    rustc --edition 2021 -O -C strip=symbols -o kbd-rgb main.rs
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 kbd-rgb $out/bin/kbd-rgb
    runHook postInstall
  '';

  meta = {
    description = "AERO X16 klavye aydınlatma kontrolü (HID LampArray)";
    platforms = lib.platforms.linux;
    mainProgram = "kbd-rgb";
  };
}
