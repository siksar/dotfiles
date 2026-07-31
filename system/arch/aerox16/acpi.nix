{ pkgs, ... }:

let
  # Fabrika SSDT9 dökümü (2026-07-11): \_SB.PCI0.GPP9.PEGP.GPS (NVIDIA legacy
  # _DSM) LTGP'yi var olmayan \_SB.PC00.AMW0.LTGP'den okuyor (Intel şablon
  # artığı) -> her dGPU uyanışında AE_NOT_FOUND + NVRM PSHAREPARAMS spam'i,
  # WMBD 0x4B (TGP 75-87W) işlevsiz. Çözüm: kernel initrd ACPI table upgrade
  # ile binary-patch'li SSDT9. Ayrıntı + BIOS güncelleme politikası:
  # Documentation/aerox16/wmi-ec.md "SSDT9 PC00->PCI0" bölümü.
  pristine       = ./acpi/ssdt9-pristine.dat;
  pristineSha256 = "03b2207ec1db487d3b2235435c5a42778c841ff2286f035bae63b1b639cb01dd";

  acpiOverride = pkgs.runCommand "acpi-ssdt9-pc00fix"
    { nativeBuildInputs = [ pkgs.python3 pkgs.acpica-tools pkgs.libarchive ]; } ''
      # 1) Guard: dump değiştiyse (BIOS güncellemesi sonrası) build DURSUN
      echo "${pristineSha256}  ${pristine}" | sha256sum -c -

      # 2) Binary patch (2x PC00->PCI0, OemRev 0x1000->0x1001, checksum)
      python3 ${./acpi/patch-ssdt9.py} ${pristine} ssdt9-pc00fix.aml

      # 3) Denetim: patch'li tablo temiz disassemble olmalı, doğru path görünmeli
      iasl -d ssdt9-pc00fix.aml
      grep -q 'PCI0.AMW0.LTGP' ssdt9-pc00fix.dsl
      ! grep -q 'PC00' ssdt9-pc00fix.dsl

      # 4) Sıkıştırmasız newc cpio — nixpkgs microcode-amd ile aynı yöntem.
      #    Dosya adı kernel için önemsiz (içerikteki imzaya bakar), path önemli.
      mkdir -p kernel/firmware/acpi "$out"
      cp ssdt9-pc00fix.aml kernel/firmware/acpi/
      touch -d @$SOURCE_DATE_EPOCH kernel/firmware/acpi/ssdt9-pc00fix.aml
      echo kernel/firmware/acpi/ssdt9-pc00fix.aml \
        | bsdtar --uid 0 --gid 0 -cnf - -T - \
        | bsdtar --null -cf - --format=newc @- > "$out/acpi-override.img"
      cp ssdt9-pc00fix.aml "$out/"   # reboot sonrası cmp doğrulaması için
    '';
in
{
  # amd-ucode mkOrder 1 ile İLK cpio (nixpkgs amd-microcode.nix); bu tanım
  # default order (1000) ile ONDAN SONRA gelir. Kernel earlycpio ardışık
  # sıkıştırmasız arşivleri tarar; asıl initrd (zstd) en sonda.
  # Çalışma zamanı ayak izi SIFIR (yalnız initrd içeriği) -> 4.28W idle korunur.
  boot.initrd.prepend = [ "${acpiOverride}/acpi-override.img" ];
}
