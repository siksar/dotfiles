{ pkgs, ... }:

let
  omarchy-sddm-theme = pkgs.stdenv.mkDerivation {
    pname = "omarchy-sddm-theme";
    version = "unstable";

    src = pkgs.fetchFromGitHub {
      owner = "basecamp";
      repo = "omarchy";
      rev = "master";
      sha256 = "09m23ap98djf7i83jllmn5155iq7ahsy2cm0v8362sjp2w3haw5n";
    };

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/share/sddm/themes/omarchy
      cp -r default/sddm/omarchy/* $out/share/sddm/themes/omarchy/
      
      # Add QtVersion=6 to metadata.desktop for Qt6 SDDM compatibility
      echo "QtVersion=6" >> $out/share/sddm/themes/omarchy/metadata.desktop
    '';
  };
in
{
  # OMArchy SDDM teması için Qt6 uyumluluğu ile varsayılan SDDM paketini kullanıyoruz
  services.displayManager.sddm = {
    enable  = true;
    wayland.enable = true;
    theme   = "omarchy";
    extraPackages = with pkgs.kdePackages; [
      qt5compat
      qtsvg
      qtmultimedia
    ];
  };

  # Tema dosyalarının /share/sddm/themes/omarchy/ altında görünmesi için
  environment.systemPackages = [ omarchy-sddm-theme ];
}


