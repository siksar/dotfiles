{ pkgs, ... }:

let
  omarchy-utils = pkgs.stdenv.mkDerivation {
    pname = "omarchy-utils";
    version = "unstable";

    src = pkgs.fetchFromGitHub {
      owner = "basecamp";
      repo = "omarchy";
      rev = "master";
      sha256 = "09m23ap98djf7i83jllmn5155iq7ahsy2cm0v8362sjp2w3haw5n";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];

    dontBuild = true;

    installPhase = ''
      mkdir -p $out/bin
      cp bin/omarchy-* $out/bin/
      
      # Make sure the scripts have all necessary tools in their PATH
      for f in $out/bin/omarchy-*; do
        wrapProgram "$f" --prefix PATH : ${pkgs.lib.makeBinPath [
          pkgs.jq
          pkgs.bash
          pkgs.coreutils
          pkgs.findutils
          pkgs.gnugrep
          pkgs.hyprland
          pkgs.libnotify
          pkgs.procps
          pkgs.systemd
        ]}
      done
    '';
  };
in
{
  environment.systemPackages = [
    omarchy-utils
    pkgs.jq
    pkgs.libnotify
  ];
}
