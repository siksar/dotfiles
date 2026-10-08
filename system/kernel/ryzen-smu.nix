# ryzen_smu — SMU/SMN okuma kapısı; tüketicisi ~/aero-eg61h. postPatch CachyOS ad çakışmalarını ve
# const imzalarını düzeltir. Çekirdek değişince REBOOT ister. '' '' içindeki her değişiklik modülü yeniden derletir.
{ config, ... }:

let
  ryzen-smu = config.boot.kernelPackages.callPackage (
    { fetchFromGitHub, kernel, lib, stdenv }:
    stdenv.mkDerivation {
      pname = "ryzen_smu";
      version = "unstable-2025-09-21";

      src = fetchFromGitHub {
        owner = "kylon";
        repo = "ryzen_smu";
        rev = "d2a4c942398d46ce5f6b97314cf236409d92bb18";
        hash = "sha256-uTYu3RlVRpqwfffPQB+9fLUCX7T0UnkZTSvOgkq1qkg=";
      };

      nativeBuildInputs = kernel.moduleBuildDependencies ++ [ kernel.stdenv.cc ];
      makeFlags = [
        "KERNEL_BUILD=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
        "CC=clang"
        "LLVM=1"
      ];

      postPatch = ''
        substituteInPlace drv.c \
          --replace-fail \
            'struct bin_attribute *attr, char *buff' \
            'const struct bin_attribute *attr, char *buff' \
          --replace-fail \
            'static struct bin_attribute *drv_bin_attrs[MAX_BIN_ATTRS_LEN]' \
            'static const struct bin_attribute *drv_bin_attrs[MAX_BIN_ATTRS_LEN]'

        substituteInPlace smu.c \
          --replace-fail \
            '#include <asm/io.h>' \
            '#include <asm/io.h>

        static inline u32 ryzen_smu_cpuid_eax(const u32 leaf)
        {
            u32 eax, ebx, ecx, edx;
            asm volatile("cpuid"
                : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
                : "a"(leaf));
            return eax;
        }

        static inline u32 ryzen_smu_cpuid_ebx(const u32 leaf)
        {
            u32 eax, ebx, ecx, edx;
            asm volatile("cpuid"
                : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
                : "a"(leaf));
            return ebx;
        }'
        substituteInPlace smu.c \
          --replace-fail 'cpuid_eax(0x00000001)' 'ryzen_smu_cpuid_eax(0x00000001)' \
          --replace-fail 'cpuid_ebx(0x80000001)' 'ryzen_smu_cpuid_ebx(0x80000001)'
      '';

      installPhase = ''
        install -D ryzen_smu.ko \
          "$out/lib/modules/${kernel.modDirVersion}/extra/ryzen_smu.ko"
      '';

      dontFixup = true;

      meta = {
        description = "Linux kernel driver exposing AMD Ryzen SMU access";
        homepage = "https://github.com/kylon/ryzen_smu";
        license = lib.licenses.gpl3Only;
        platforms = lib.platforms.linux;
      };
    }
  ) { };
in
{
  boot.extraModulePackages = [ ryzen-smu ];
  boot.kernelModules = [ "ryzen_smu" ];
}
