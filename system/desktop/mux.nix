# MUX / dGPU-only modu: BIOS'ta MUX dGPU-only iken bayrağı aç; COSMIC + Hyprland guard'larını
# dGPU'ya çevirir, PRIME/RTD3'ü kapatır (GNOME guard'ı çevrilmez). CANLI DOĞRULANMADI:
# önce build + verify-context, ikinci TTY açık bırak, sonra switch.
{ config, lib, ... }:

let
  cfg = config.desktop.dgpuOnly;
in
{
  options.desktop.dgpuOnly.enable = lib.mkEnableOption
    "MUX/dGPU-only modu — panel NVIDIA dGPU'da; PRIME offload ve RTD3 kapanir";

  config = lib.mkIf cfg.enable {

    # mkForce şart: gpu.nix düz atıyor.
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enableOffloadCmd = lib.mkForce false;

    hardware.nvidia.prime.nvidiaBusId = lib.mkForce "";
    hardware.nvidia.prime.amdgpuBusId = lib.mkForce "";

    hardware.nvidia.powerManagement.finegrained = lib.mkForce false;

    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x2d19", SYMLINK+="dri/hypr-dgpu", SYMLINK+="dri/kwin-dgpu", SYMLINK+="dri/sddm-dgpu"
    '';

    environment.sessionVariables = {
      AQ_DRM_DEVICES = lib.mkForce "/dev/dri/hypr-dgpu";
      KWIN_DRM_DEVICES = lib.mkForce "/dev/dri/kwin-dgpu";

      # COSMIC sözdizimi: virgül + 0xVENDOR:0xDEVICE.
      COSMIC_DRM_ALLOW_DEVICES = lib.mkForce "0x10de:0x2d19";
    };

    warnings = [
      ''
        desktop.dgpuOnly.enable = true — MUX/dGPU-only modu AÇIK.
        BIOS'ta MUX gerçekten "Discrete/dGPU only" değilse panel kararabilir.
        Switch sonrası doğrula:  ls -l /dev/dri/*-dgpu   (üç symlink olmalı)
        Pil ömrü bu modda belirgin düşer — 4.28W idle bütçesi GEÇERSİZ.
      ''
    ];
  };
}
