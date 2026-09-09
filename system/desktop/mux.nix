# MUX / dGPU-only modu — 2 Eyl 2026, kullanıcı isteği.
#
# NE İŞE YARAR: BIOS'ta MUX "Discrete Graphics / dGPU only" moduna alındığında,
# paneli artık AMD iGPU değil NVIDIA dGPU sürer. Bu repo'nun TAMAMI ise ters
# varsayımla kurulu — dört ayrı oturum köprüsü compositor'ı iGPU'ya kilitliyor ki
# dGPU D3cold'a girip 4.28W idle bütçesi korunsun. MUX açıkken o dört köprü
# compositor'a "var olmayan / paneli sürmeyen kartı kullan" demiş olur.
#
# Bu dosya o dördünü TEK BAYRAKLA çevirir:
#   desktop.dgpuOnly.enable = true;   → köprüler NVIDIA'ya bakar, PRIME kapanır
#   desktop.dgpuOnly.enable = false;  → bugünkü hibrit davranış (VARSAYILAN)
#
# ───────────────────────────────────────────────────────────────────────────
# ⚠ BU DOSYA CANLI MAKİNEDE DOĞRULANMADI (2 Eyl 2026)
# ───────────────────────────────────────────────────────────────────────────
# Yazıldığı oturumda kabuk aracı çalışmıyordu: `nixos-rebuild build` de,
# `scripts/verify-context.sh` de KOŞTURULAMADI. Repo kuralı açık (kök CLAUDE.md):
# "grep/okuma ile türetilen bir bulgu, bir şey koşturulana kadar bulgu değildir."
# Bu dosyanın kendisi o kuralın istisnası DEĞİL — aşağıdaki üç madde ÖLÇÜLMEDİ:
#
#   (Ş1) udev kuralının gerçekten eşleşip eşleşmediği. ATTRS{vendor} PCI ebeveynine
#        yürür ve cosmic.nix'in okuduğu sysfs alanının aynısıdır (0x10de/0x2d19,
#        1 Eyl 2026'da ölçülmüş) — ama DRM card node'unda eşleştiği DOĞRULANMADI.
#        Kontrol:  udevadm info -a /dev/dri/card0 | grep -m2 'ATTRS{vendor}'
#        Doğrulama: switch sonrası  ls -l /dev/dri/*-dgpu  → üç symlink görünmeli.
#
#   (Ş2) MUX modunda iGPU'nun hâlâ DRM cihazı olarak sayılıp sayılmadığı. İki alt
#        durum da bu kuralla güvende: iGPU yoksa tek kart zaten NVIDIA olur, varsa
#        filtre onu dışarıda bırakır. Yine de gözle doğrula.
#
#   (Ş3) prime.offload=false + busId'lerin boşaltılmasının nixos/modules/hardware/
#        video/nvidia.nix'teki assertion'lardan temiz geçtiği. EVAL ETMEDEN SWITCH
#        YAPMA.
#
# ZORUNLU SIRA — greeter'ı kaybetme riski gerçek (login.nix'in kendi notu:
# "giriş ekranı yok = sisteme giremezsin"):
#   1. BIOS'ta MUX'u dGPU-only yap
#   2. desktop.dgpuOnly.enable = true;
#   3. nixos-rebuild build --flake ...#nixos     ← ÖNCE BUILD, switch DEĞİL
#   4. bash scripts/verify-context.sh
#   5. İkinci bir TTY'yi (Ctrl+Alt+F2) AÇIK ve giriş yapmış bırak — geri dönüş yolu
#   6. switch, reboot
#   7. Bozulursa: TTY'den bayrağı false yap + BIOS'u geri al, ya da greeter'da
#      önceki generation'ı seç (systemd-boot menüsü)
#
# NEDEN GÜÇ YÖNETİMİ DE KAPANIYOR: powerManagement.finegrained (RTD3/D3cold)
# yalnız offload modunda anlamlı — dGPU paneli sürerken uyutulamaz, ve NixOS
# modülü finegrained için prime.offload.enable şartı koyar. dGPU-only modda
# 4.28W idle hedefi ZATEN GEÇERSİZDİR: dGPU sürekli açık kalacağı için pil ömrü
# belirgin şekilde düşer. Bu modun bedeli budur, arıza değil.
{ config, lib, ... }:

let
  cfg = config.desktop.dgpuOnly;
in
{
  options.desktop.dgpuOnly.enable = lib.mkEnableOption
    "MUX/dGPU-only modu — panel NVIDIA dGPU'da; PRIME offload ve RTD3 kapanir";

  config = lib.mkIf cfg.enable {

    #### 1) PRIME offload'ı kapat ####
    # Hibrit modun tamamı burada iptal oluyor. mkForce şart: system/drivers/gpu.nix
    # bunları düz atamayla veriyor, düz-düz çakışması eval hatası olurdu.
    hardware.nvidia.prime.offload.enable = lib.mkForce false;
    hardware.nvidia.prime.offload.enableOffloadCmd = lib.mkForce false;

    # busId'ler boşaltılıyor: PRIME modu yokken bir anlamları kalmıyor. (Ş3)
    hardware.nvidia.prime.nvidiaBusId = lib.mkForce "";
    hardware.nvidia.prime.amdgpuBusId = lib.mkForce "";

    # RTD3 finegrained — offload'sız geçersiz (yukarıdaki gerekçe).
    hardware.nvidia.powerManagement.finegrained = lib.mkForce false;

    #### 2) dGPU için kararlı, İKİ NOKTA İÇERMEYEN DRM node'ları ####
    # Üç compositor da (aquamarine, kwin greeter, kwin Plasma) değeri ':' ile
    # ayrılmış cihaz listesi olarak okur → by-path adı ("pci-0000:64:00.0-card")
    # üç geçersiz parçaya bölünür ve backend hiç GPU bulamaz. Bu yüzden igpu
    # tarafındaki desenin aynısı, yalnız hedef NVIDIA.
    #
    # DRIVERS=="nvidia" YERİNE ATTRS ile eşleşiyoruz: nvidia-drm ayrı bir modül
    # olduğu için card node'unun DRIVERS alanı amdgpu'daki kadar güvenilir değil.
    # vendor/device çifti cosmic.nix'te ölçülmüş kaynaktan geliyor. (Ş1)
    services.udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ATTRS{vendor}=="0x10de", ATTRS{device}=="0x2d19", SYMLINK+="dri/hypr-dgpu", SYMLINK+="dri/kwin-dgpu", SYMLINK+="dri/sddm-dgpu"
    '';

    #### 3) Dört köprüyü çevir ####
    # Üçü basit attr olduğu için buradan mkForce ile eziliyor. DÖRDÜNCÜSÜ
    # (SDDM greeter) burada YOK — o, birleştirilmiş bir string listesinin içinde
    # olduğu için login.nix'in KENDİSİ bu bayrağı okuyor. Oraya da bak.
    environment.sessionVariables = {
      AQ_DRM_DEVICES = lib.mkForce "/dev/dri/hypr-dgpu";
      KWIN_DRM_DEVICES = lib.mkForce "/dev/dri/kwin-dgpu";

      # COSMIC'in sözdizimi TERS — virgülle ayırır ve bu biçim iki nokta İÇERMEK
      # ZORUNDA (0xVENDOR:0xDEVICE). cosmic.nix'teki uzun nota bak, oradaki kuralı
      # buraya kopyalama.
      COSMIC_DRM_ALLOW_DEVICES = lib.mkForce "0x10de:0x2d19";
    };

    #### 4) Doğrulama kolaylığı ####
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
