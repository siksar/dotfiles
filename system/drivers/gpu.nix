# Hibrit: AMD 860M iGPU + NVIDIA RTX 5060 Max-Q (PRIME offload).
{ config, pkgs, ... }:

{
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" "nvidia" ];

  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    open           = true;
    nvidiaSettings = true;
    # Sürücü nvidiaPackages.latest. Geri pinleme: mkDriver { version + hash }.
    # Clang (CachyOS-lto) ile nvidia-open nv-linux.h'te const gpio_device yüzünden -Werror'a takılıyor;
    # yalnız o tanı hatadan çıkarılır (davranışsal etkisi yok). Düzelince sil.
    # Kullanıcı-alanı gcc'ye döndürülür: clang stdenv clang/llvm lib'lerini kapanışa sokuyordu (+1.4 GiB);
    # çekirdek modülü (passthru.open) clang'da kalır.
    package =
      let
        base = config.boot.kernelPackages.nvidiaPackages.latest.override {
          inherit (pkgs) stdenv;
        };
      in
      base.overrideAttrs (o: {
        passthru = o.passthru // {
          open = o.passthru.open.overrideAttrs (
            m:
            let
              prev = m.NIX_CFLAGS_COMPILE or "";
            in
            {
              NIX_CFLAGS_COMPILE =
                prev + " -Wno-error=incompatible-pointer-types-discards-qualifiers";
            }
          );
        };
      });
    # nvidia-powerd: ACBT bütçesiyle GPU tavanını 50W→75W+ yapar (Dynamic Boost).
    dynamicBoost.enable = true;
    powerManagement = {
      enable      = true;
      finegrained = true;
    };
    prime = {
      offload = {
        enable          = true;
        enableOffloadCmd = true;
      };
      nvidiaBusId = "PCI:100:0:0";
      amdgpuBusId = "PCI:101:0:0";
    };
  };

  environment.variables = {
    LIBVA_DRIVER_NAME = "radeonsi";
    VDPAU_DRIVER      = "radeonsi";
  };

  environment.systemPackages = with pkgs; [
    libva-utils
    vdpauinfo
  ];
}
