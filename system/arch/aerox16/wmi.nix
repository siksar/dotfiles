# Gigabyte WMI/EC: kendi sürücümüz aero_eg61h (~/aero-eg61h) + acpi_call ile ham EC yazımı.
# UYARI: 0x4B ve 0xF1-F3 EC tarafından geri yazılıyor.
{ inputs, ... }:

{
  imports = [ "${inputs.aero-eg61h}/nix/aero-eg61h.nix" ];

  hardware.aero-eg61h = {
    enable = true;

    # AC'de responsive, pilde balanced: aynı duty merdiveni, responsive eşikleri ~14 °C erken.
    fanMode.ac = "responsive";
    fanMode.battery = "balanced";

    chargeLimit = 100;

    # ACBT (0x4C, ×8W): AC'de 80W → nvidia-powerd tavanı 50→75W+. gpu_boost (0x51) YAZILMAZ:
    # bu DSDT'de 3 = dGPU eject.
    gpuBoost.ac = 10;
    gpuBoost.battery = 0;

    # input git+file: aero-eg61h'deki değişiklik commit + `nix flake update aero-eg61h` ister.
    gui.enable = true;
  };

  # Çıplak Fn tuşu F20 gönderiyor, xkb onu XF86AudioMicMute'a eşliyor → kernel seviyesinde sustur.
  services.udev.extraHwdb = ''
    evdev:input:b0003v0414p8104*
     KEYBOARD_KEY_7006f=reserved
  '';

  # aero-power-profile, game-perf.service aktifken fan_mode yazmaz (oyun turbo'sunu ezmesin).
}
