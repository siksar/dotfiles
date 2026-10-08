{ config, pkgs, ... }:

# Klavye aydınlatması — HID LampArray (0x59), tek bölge RGB. WMBD 0xF6 ışığı sürmüyor.

let
  kbd-rgb = pkgs.callPackage ./package.nix { };

  kbd-anim = pkgs.writeShellScriptBin "kbd-anim" ''
    set -eu
    mode="''${1:-breathe}"
    unit="kbd-rgb-anim@$mode.service"
    if systemctl --user is-active -q "$unit"; then
      systemctl --user stop "$unit"
    else
      # başka bir mod dönüyorsa önce onu durdur (ExecStopPost firmware'i iade eder)
      systemctl --user stop 'kbd-rgb-anim@*.service' >/dev/null 2>&1 || true
      systemctl --user start "$unit"
    fi
  '';
in
{
  environment.systemPackages = [ kbd-rgb kbd-anim ];

  # uaccess SIRALAMA TUZAĞI: extraRules 99-local.rules'a yazar ama etiketi ACL'e çeviren
  # 73-seat-late.rules daha önce koşar → kural 73'ten önce sıralanan kendi dosyasında OLMALI.
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "kbd-rgb-udev-rules";
      destination = "/etc/udev/rules.d/70-kbd-rgb.rules";
      text = ''
        SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0414", ATTRS{idProduct}=="8104", TAG+="uaccess"
      '';
    })
  ];

  # Tema köprüsü: renk Stylix base0D'den; oturum başına tek yazma.
  # graphical-session.target: hidraw uaccess ACL'i ancak oturum açıkken var.
  systemd.user.services.kbd-rgb-theme = {
    description = "Klavye RGB rengini Stylix paletine eşitle";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${kbd-rgb}/bin/kbd-rgb set ${config.lib.stylix.colors.base0D}";
      RemainAfterExit = true;
    };
  };

  systemd.user.services."kbd-rgb-anim@" = {
    description = "Klavye RGB animasyonu (%i)";
    serviceConfig = {
      Type = "simple";
      ExecStart = "${kbd-rgb}/bin/kbd-rgb anim %i";
      # Durdurulunca firmware efektlerini iade et.
      ExecStopPost = "${kbd-rgb}/bin/kbd-rgb auto on";
      Restart = "no";
      Nice = 10;
    };
  };
}
