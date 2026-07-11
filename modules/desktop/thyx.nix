# Thyx — SDDM greeter teması (github:rccyx/thyx)
# greetd+tuigreet'in yerini aldı. Varsayılan preset: Cinder (video arka plan,
# theme.conf içinde backgrounds/cinder.mp4). Modül SDDM'i kendisi açar ve
# video için qt6 multimedia paketlerini getirir.
{ lib, pkgs, config, inputs, ... }:

{
  services.displayManager.sddm.thyx.enable = true;
  services.displayManager.sddm.wayland.enable = true;

  # Cinder'ın sıcak köz videosu kalır; renk paleti zixar-main (Kanagawa
  # Boğaziçi) ile uyumlu hale getirildi — vurgu rengi (login butonu, seçili
  # dropdown) ateş turuncusundan Türkuaz'a çekildi (ateş+çini kontrastı),
  # kenarlık/hover'lar Safran ve Bakır'a bağlandı. bkz. thyx-zixar-main.conf.
  services.displayManager.sddm.thyx.package =
    (pkgs.callPackage "${inputs.thyx}/default.nix" { }).overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        cp ${./thyx-zixar-main.conf} "$out/share/sddm/themes/thyx/theme.conf"
      '';
    });

  # Hibrit GPU: panel yalnızca amdgpu'ya (card1) bağlı, dGPU (nvidia) normalde
  # D3cold'da (bkz. hardware/gpu.nix, [[power-optimization-project]]). SDDM'in
  # weston greeter'ı DRM cihazını otomatik seçince nvidia'yı (card0) buluyor,
  # hiçbir çıkışı "connected" göremiyor ve "Could not enable any output" ile
  # anında çöküyor (ekran hiç gelmiyor). Hyprland aynı sorunu AQ_DRM_DEVICES=
  # /dev/dri/card1 ile çözüyor (hyprland/settings.nix); weston'da eşdeğeri
  # --drm-device. NixOS'un varsayılan compositorCommand'ını (sddm.nix)
  # birebir yeniden üretip bu bayrağı ekliyoruz.
  services.displayManager.sddm.wayland.compositorCommand = lib.mkForce (
    let
      westonIni = (pkgs.formats.ini { }).generate "weston.ini" {
        libinput = {
          enable-tap = config.services.libinput.mouse.tapping;
          left-handed = config.services.libinput.mouse.leftHanded;
        };
        keyboard = {
          keymap_model = config.services.xserver.xkb.model;
          keymap_layout = config.services.xserver.xkb.layout;
          keymap_variant = config.services.xserver.xkb.variant;
          keymap_options = config.services.xserver.xkb.options;
        };
      };
    in
    "${lib.getExe pkgs.weston} --shell=kiosk --drm-device=card1 -c ${westonIni}"
  );
}
