# Zen Browser — Firefox tabanlı; Pywalfox ile tema geçişlerinde canlı boyanır
# (Helium'un yerine: Chromium tabanı canlı temayı desteklemiyordu)
{ inputs, pkgs, ... }:

let
  # Pywalfox native host manifest'i, zen wrapper'ının beklediği pakette
  pywalfox-host = pkgs.runCommand "pywalfox-native-host" { } ''
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    cat > $out/lib/mozilla/native-messaging-hosts/pywalfox.json <<EOF
    {
      "name": "pywalfox",
      "description": "Pywalfox native host",
      "path": "${pkgs.writeShellScript "pywalfox-host" ''
        exec ${pkgs.pywalfox-native}/bin/pywalfox start
      ''}",
      "type": "stdio",
      "allowed_extensions": [ "pywalfox@frewacom.org" ]
    }
    EOF
  '';
in
{
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = [ pywalfox-host ];
    policies = {
      DisableAppUpdate = true; # güncellemeler nix'ten gelir
      DisableTelemetry = true;
      ExtensionSettings."pywalfox@frewacom.org" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/pywalfox/latest.xpi";
      };
    };
  };
}
