# atif-1402/minimal-waybar-themes portları — her biri store'da kendi
# dizininde durur, waybar `-c <dizin>/config.jsonc -s <dizin>/style.css` ile
# çalıştırılır (bkz. hm.nix `waybar-launch`). HM'in ~/.config/waybar
# symlink'lerine hiç dokunulmaz; "current" (mevcut Anto98765 portu) bu
# listede YOK, o argümansız `waybar` ile ayrı çalışır.
#
# Build-time yeniden yazma, mkTheme:
#   1. göreli "../omarchy/…/waybar.css" import'u → mutlak palet yolu
#      (göreli import store'da /nix/store/omarchy/… arardı)
#   2. "~/.config/waybar/" hardcode'u → temanın kendi $out'u
#   3. waybar-mono-overrides.css, style.css'in SONUNA eklenir
#   4. shebang'ler patchShebangs ile /nix/store'a düzeltilir
{ pkgs, lib }:

let
  palette = ./waybar-mono.css;
  overrides = ./waybar-mono-overrides.css;

  mkTheme = dir:
    pkgs.runCommand "waybar-theme-${lib.replaceStrings [ "." ] [ "-" ] (lib.toLower dir)}"
      { } ''
        mkdir -p $out
        cp -rL ${./waybar-themes}/${dir}/. $out/
        chmod -R u+w $out

        find $out -type f | while IFS= read -r f; do
          substituteInPlace "$f" \
            --replace-quiet '@import "../omarchy/current/theme/waybar.css";' '@import "${palette}";' \
            --replace-quiet '~/.config/waybar/' "$out/"
        done

        if [ -f "$out/style.css" ]; then
          printf '\n' >> "$out/style.css"
          cat ${overrides} >> "$out/style.css"
        fi

        find $out -name '*.sh' -exec chmod +x {} \;
        patchShebangs $out
      '';

  themeNames = [
    "V1"
    "V1.5"
    "V2"
    "V2.4"
    "V2.8"
    "V3"
    "V3.xa"
    "V3.Omega"
    "V3.Omegax"
    "V4"
    "V4.x"
    "V4.y"
    "V5"
    "V6"
    "V7"
  ];
in
lib.genAttrs themeNames mkTheme
