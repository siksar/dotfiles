# Claude Desktop — resmî .deb; kendini güncellemez, store'da sabit. Güncelleme:
#   curl -s https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages \
#     | grep -E '^(Version|SHA256):' | tail -2
# Cowork önkoşulları system/virt.nix'te.
{ pkgs, lib, ... }:

let
  claudeDesktop = pkgs.stdenv.mkDerivation rec {
    pname = "claude-desktop";
    version = "2.7032.0";

    src = pkgs.fetchurl {
      url = "https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_${version}_amd64.deb";
      sha256 = "1e7f4504bca5b2f6b2d3c4123d145d727647e77f2ee2d046850711e61e7d7b11";
    };

    nativeBuildInputs = with pkgs; [
      dpkg
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = with pkgs; [
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
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxtst
      libxcb
      libxcursor
      libxi
      libxrender
      libxscrnsaver
      libxshmfence
    ];

    # dlopen ile yüklenenler (libudev, libsecret, libnotify)
    runtimeDependencies = with pkgs; [
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

    meta = {
      description = "Claude Desktop (resmî Linux beta) — Chat, Cowork ve Code";
      homepage = "https://claude.com/download";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      mainProgram = "claude-desktop";
    };
  };
in {
  environment.systemPackages = [ claudeDesktop ];
}
