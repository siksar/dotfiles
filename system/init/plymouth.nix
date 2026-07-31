{ pkgs, ... }:

let
  omarchy-plymouth-theme = pkgs.stdenv.mkDerivation {
    pname = "omarchy-plymouth-theme";
    version = "unstable";

    src = pkgs.fetchFromGitHub {
      owner = "basecamp";
      repo = "omarchy";
      rev = "master";
      sha256 = "09m23ap98djf7i83jllmn5155iq7ahsy2cm0v8362sjp2w3haw5n";
    };

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/share/plymouth/themes/omarchy
      cp -r default/plymouth/* $out/share/plymouth/themes/omarchy/
      
      # Replace hardcoded paths in omarchy.plymouth config file
      substituteInPlace $out/share/plymouth/themes/omarchy/omarchy.plymouth \
        --replace "ImageDir=/usr/share/plymouth/themes/omarchy" "ImageDir=$out/share/plymouth/themes/omarchy" \
        --replace "ScriptFile=/usr/share/plymouth/themes/omarchy/omarchy.script" "ScriptFile=$out/share/plymouth/themes/omarchy/omarchy.script"
    '';
  };
in
{
  boot.plymouth = {
    enable = true;
    themePackages = [ omarchy-plymouth-theme ];
    theme = "omarchy";
  };
}
