# Hibrit grafik: AMD 860M iGPU (amdgpu) + NVIDIA RTX 5060 Max-Q (PRIME offload).
# dGPU boştayken D3cold'da uyur; oyunlar gamerun ile offload eder (home/apps/games.nix).
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
    open           = true; # Blackwell dGPU open source driver modules (zorunlu)
    nvidiaSettings = true;
    # Sürücü: nvidiaPackages.latest (şu an 610.43.03). 2026-07-18'de 610.43.02
    # pininden latest'e alındı — TEST: pinli 610.43.02'de nvidia-powerd Dynamic Boost'u
    # bu AMD+NVIDIA makinede kuramıyor, GPU 30W tabanda kilitli (enforced 30W < 50W
    # varsayılan; profil/PPD/TLP ölçümle elendi; bkz. NVIDIA open-gpu-kernel-modules
    # #392/#966 + Documentation/aerox16/wmi-ec.md). SONUÇ (31 Tem 2026): sürüm avcılığı gereksizmiş —
    # nvidia-powerd canlıda sağlıklı (D-Bus bağlı, çökmüyor); tek yinelenen log satırı
    # "SBIOS disable Dynamic Boost DC controller" (DC=pil; bu repo boost'u zaten yalnız
    # AC'ye kilitlemiş, muhtemelen zararsız). Gerçek kanıt versiyon değil ÖLÇÜM: ACBT WMI
    # yazımı (0x4C)→nvidia-powerd okuma→GPU tavanı zinciri KCD'de 38W→70-83W ölçüldü
    # (gaming-performance-project belleği). #392 (AMD CPU'da DB, NVIDIA'da 2022'den beri
    # açık/kabul edilmiş genel sınırlama) bu yüzden ilgisiz — kazanç o jenerik mekanizmadan
    # değil WMI yan-kanalından geliyor. NOT: 595 (beta/production) daha eski, bilinen
    # oyun-donma sorunları (Tsushima, s2idle) — son çare. Geri pinlemek: mkDriver { version + hash }.
    #
    # CLANG UYUMU 1 Eyl 2026 — CachyOS-lto çekirdeğine (clang-21.1.8) geçişte
    # nvidia-open 610.57.04 DERLENMİYOR. Tek engel tek satır:
    #   common/inc/nv-linux.h:1737
    #   error: passing 'const struct gpio_device *' to parameter of type
    #          'struct gpio_device *' discards qualifiers
    #          [-Werror,-Wincompatible-pointer-types-discards-qualifiers]
    # Çekirdek başlığı gpio_device_get_chip(struct gpio_device *) diyor (const YOK),
    # NVIDIA sarmalayıcısı const geçiriyor. gcc bunu yalnız UYARI sayar, clang aynı
    # tanıyı NVIDIA'nın kendi -Werror'ı altında HATAYA çevirir — CONFIG_WERROR ikisinde
    # de kapalı (ölçüldü), yani kaynak -Werror NVIDIA'nın Kbuild'i.
    # Davranışsal etkisi yok: gpio_device_get_chip yalnız gdev->chip'i OKUR, yazmaz;
    # const'un düşmesi ABI'yi değiştirmez. O yüzden yamalamak yerine bu TEK tanıyı
    # hataya yükseltmekten çıkarıyoruz — topyekûn -Wno-error DEĞİL, sadece bu.
    # Doğrulandı: modül derlendi, modinfo → vermagic 7.2.2-cachyos-lto.
    # NVIDIA sarmalayıcıyı düzeltince ya da çekirdek başlığı const alınca bu blok
    # gereksizleşir — o gün sil, sessizce taşıma.
    # KULLANICI-ALANI gcc'ye geri alındı 1 Eyl 2026 — pkgs.linuxPackagesFor paket setinin
    # TAMAMINA çekirdeğin stdenv'ini (clang) verir, NVIDIA'nın kullanıcı-alanı da dahil.
    # Sonuç ölçüldü (nix store diff-closures 143→144): nvidia-x11-*-bin, clang-21.1.8-lib
    # ve llvm-21.1.8-lib'e kalıcı referans tutup sistem closure'ını 28.49 → 29.87 GiB
    # yaptı (+1.38 GiB). Derleyici runtime closure'ında olmamalı.
    # .override { stdenv } yalnız generic.nix'in kendi stdenv argümanını değiştirir;
    # passthru.open hâlâ paket setinin callPackage'ıyla kurulduğu için ÇEKİRDEK MODÜLÜ
    # clang'da kalır (doğrulandı: üst gcc-15.3.0, .open clang-21.1.8). Kullanıcı-alanı
    # ile çekirdek modülü ayrı ABI alanları — NVIDIA'nın kendi dağıtımı da böyle yapar.
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
    # nvidia-powerd: NPCF.ACBT bütçesini okuyup GPU tavanını 50W→75W+'a
    # çıkarır (Dynamic Boost). ACBT'yi aero-power-profile yazar (0x4C).
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
