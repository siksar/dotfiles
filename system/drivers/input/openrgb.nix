# OpenRGB yalnız paket: services.hardware.openrgb SDK sunucusu boşta döner.
# Dahili klavye (0414:8104) Aorus satıcı protokolünü (0xFF01) konuşur; postPatch PID'i detector'e ekler.
{ pkgs, ... }:

let
  # Bu ''…'' bloğunun içi script metni: her düzeltme OpenRGB'yi yeniden derletir.
  openrgb-aero = pkgs.openrgb.overrideAttrs (eski: {
    postPatch = (eski.postPatch or "") + ''
      cat >> Controllers/GigabyteAorusLaptopController/GigabyteAorusLaptopControllerDetect.cpp <<'YAMA'

      /* AERO X16 EG61H (0414:8104) — NixOS yaması, bkz. system/drivers/input/openrgb.nix.
         Aorus laptop protokolüyle birebir aynı: arayüz 3, usage page 0xFF01,
         usage 0x01, 8 baytlık unnumbered feature report. Ölçüm 19 Eyl 2026. */
      REGISTER_HID_DETECTOR_IPU("Gigabyte AERO X16 Keyboard", DetectGigabyteAorusLaptopKeyboardControllers, 0x0414, 0x8104, 3, 0xFF01, 0x01);
      YAMA
    '';
  });
in
{
  environment.systemPackages = [ openrgb-aero ];

  services.udev.packages = [ openrgb-aero ];

  # i2c-dev yüklü değilse OpenRGB her açılışta uyarı basar.
  hardware.i2c.enable = true;
}
