# Claude Desktop — RESMÎ Linux .deb'inden (Anthropic, 2026-06-30 Linux betası)
# Chat + Cowork + Code sekmeleri dahil. Eski k3d3 Windows-repack'inin yerini aldı.
#
# Güncelleme:
#   curl -s https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages \
#     | grep -E "^(Version|SHA256):" | tail -2
#   → version + sha256'yı aşağıya yaz.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  pango,
  nss,
  nspr,
  libdrm,
  mesa,
  libgbm,
  libxkbcommon,
  libGL,
  systemd,
  libsecret,
  libnotify,
  libuuid,
  libseccomp,
  libcap_ng,
  xorg,
}:

stdenv.mkDerivation rec {
  pname = "claude-desktop";
  version = "1.18286.0";

  src = fetchurl {
    url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
    sha256 = "8f314ad1a80aab52711a8eaabc06aae48fb341f0adea4a0d7264db5cab9d0536";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    pango
    nss
    nspr
    libdrm
    mesa
    libgbm
    libxkbcommon
    libGL
    libsecret
    libnotify
    libuuid
    libseccomp # paketle gelen virtiofsd için
    libcap_ng
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libXtst
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
    xorg.libXrender
    xorg.libXScrnSaver
    xorg.libxshmfence
  ];

  # dlopen ile yüklenenler (libudev, libsecret, libnotify)
  runtimeDependencies = [
    (lib.getLib systemd)
    libsecret
    libnotify
  ];

  unpackPhase = ''
    runHook preUnpack
    # dpkg-deb -x, chrome-sandbox'ın setuid modunu koruyamayınca patlıyor
    dpkg-deb --fsys-tarfile $src | tar -x --no-same-owner --no-same-permissions
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r usr/lib $out/lib
    cp -r usr/share $out/share

    # Sarmalayıcı: Wayland altında ozone otomatiği
    makeWrapper $out/lib/claude-desktop/claude-desktop $out/bin/claude-desktop \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    runHook postInstall
  '';

  # chrome-sandbox setuid gerektirmez: NixOS'ta user namespace sandbox kullanılır
  dontStrip = true;

  meta = with lib; {
    description = "Claude Desktop (resmî Linux beta) — Chat, Cowork ve Code";
    homepage = "https://claude.com/download";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    mainProgram = "claude-desktop";
  };
}
