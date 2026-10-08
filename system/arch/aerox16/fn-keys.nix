# Fn+F4/F7/F9 yalnız klavyenin satıcı sayfası 0xFF02 / Report ID 4'ten gelir, evdev'e çevrilmez.
# Köprü raporu okuyup uinput tuşu üretir ve (--act) eylemi yapar. Fn matrisi EC'de değil,
# klavye denetleyicisinde (0414:8104). Masaüstü bu tuşlara eylem bağlarsa --act kaldırılabilir.
{ pkgs, ... }:

let
  fn-bridge = pkgs.writeScriptBin "fn-bridge" (
    builtins.replaceStrings
      [ "#!/usr/bin/env perl" ] [ "#!${pkgs.perl}/bin/perl" ]
      (builtins.readFile ./fn-bridge.pl)
  );

  kbd-rgb = pkgs.callPackage ../../drivers/input/keyboard-rgb/package.nix { };
in
{
  environment.systemPackages = [ fn-bridge ];

  systemd.services.aero-fn-bridge = {
    description = "AERO X16 Fn tuşları — 0xFF02 satıcı raporu → uinput + eylem";
    # wantedBy yok: tetikleyici aşağıdaki udev kuralı.
    serviceConfig = {
      Type = "simple";
      ExecStart = "${fn-bridge}/bin/fn-bridge --act --user zixar";
      Restart = "on-failure";
      RestartSec = 2;
      # pgrep: GNOME oturumunda eylemi atlamak için (gnome.nix ile çakışma).
      Environment = [
        "PATH=${
          pkgs.lib.makeBinPath [
            pkgs.util-linux
            pkgs.wireplumber
            pkgs.systemd
            pkgs.coreutils
            pkgs.procps
            kbd-rgb
          ]
        }"
        # Köprü root koşar ama kbd-rgb durum dosyası $HOME'a bağlı → kullanıcının HOME'u sabitlenir.
        "XDG_STATE_HOME=/home/zixar/.local/state"
      ];
    };
    startLimitBurst = 3;
    startLimitIntervalSec = 60;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0414", ATTRS{idProduct}=="8104", \
      TAG+="systemd", ENV{SYSTEMD_WANTS}+="aero-fn-bridge.service"
  '';
}
