#!/usr/bin/env python3
"""EC paylaşım penceresinden (PECM) ortam ışığı sensörünü yoklar.

DSDT kanıtı (Documentation/aerox16/dsdt.dsl.txt):
    OperationRegion (PECM, SystemMemory, 0xFC7E0800, 0x1000)
    Field (PECM, AnyAcc, Lock, Preserve) { ... Offset(0x13),
        RPM1, 16,   -> 0x13-0x14   (fan1 RPM)
        RPM2, 16,   -> 0x15-0x16   (fan2 RPM)
        BHEA, 8,    -> 0x17
        LUXM, 8,    -> 0x18        \
        LUXL, 8,    -> 0x19         > ortam ışığı (3 bayt)
        LUXH, 8,    -> 0x1A        /
        Offset(0x1B), FAN1, 8, FAN2, 8 }

KENDİNİ DOĞRULAMA: RPM1/RPM2 hwmon'daki fanN_input ile eşleşmiyorsa eşleme
yanlıştır ve LUX baytları da anlamsızdır — script bunu kendisi söyler.

Kullanım (root gerekir):  sudo python3 scripts/als-probe.py
"""

import mmap
import os
import sys

PECM_BASE = 0xFC7E0800
PAGE = 0x1000
PAGE_BASE = PECM_BASE & ~(PAGE - 1)  # 0xFC7E0000
PECM_OFF = PECM_BASE - PAGE_BASE  # 0x800


def read_window():
    """PECM penceresinin ilk 0x40 baytını döndürür."""
    fd = os.open("/dev/mem", os.O_RDONLY | os.O_SYNC)
    try:
        mm = mmap.mmap(fd, PAGE * 2, mmap.MAP_SHARED, mmap.PROT_READ, offset=PAGE_BASE)
    finally:
        os.close(fd)
    try:
        return bytes(mm[PECM_OFF : PECM_OFF + 0x40])
    finally:
        mm.close()


def hwmon_fans():
    """aorus_laptop hwmon'dan fan RPM'lerini okur (doğrulama referansı)."""
    for h in sorted(os.listdir("/sys/class/hwmon")):
        p = f"/sys/class/hwmon/{h}"
        try:
            with open(f"{p}/name") as f:
                if f.read().strip() != "aorus_laptop":
                    continue
        except OSError:
            continue
        out = []
        for n in (1, 2):
            try:
                with open(f"{p}/fan{n}_input") as f:
                    out.append(int(f.read().strip()))
            except OSError:
                out.append(None)
        return out
    return [None, None]


def main():
    if os.geteuid() != 0:
        sys.exit("root gerekir: sudo python3 scripts/als-probe.py")

    try:
        buf = read_window()
    except PermissionError:
        sys.exit(
            "/dev/mem erişimi reddedildi.\n"
            "CONFIG_IO_STRICT_DEVMEM bu bölgeyi kilitliyor olabilir "
            "(bir sürücü talep etmişse). Bu durumda tek yol küçük bir "
            "ioremap çekirdek modülü — aorus-laptop deseninin aynısı."
        )
    except OSError as e:
        sys.exit(f"/dev/mem okunamadı: {e}")

    rpm1 = buf[0x13] | (buf[0x14] << 8)
    rpm2 = buf[0x15] | (buf[0x16] << 8)
    luxm, luxl, luxh = buf[0x18], buf[0x19], buf[0x1A]

    print("PECM 0x00-0x3F ham dökümü:")
    for row in range(0, 0x40, 16):
        cells = " ".join(f"{b:02x}" for b in buf[row : row + 16])
        print(f"  +{row:02x}: {cells}")

    fan1, fan2 = hwmon_fans()
    print(f"\nDOĞRULAMA — fan RPM (PECM'den okunan vs hwmon):")
    print(f"  RPM1 = {rpm1:6d}   hwmon fan1_input = {fan1}")
    print(f"  RPM2 = {rpm2:6d}   hwmon fan2_input = {fan2}")

    ok = fan1 is not None and (abs(rpm1 - fan1) <= 200 or abs(rpm2 - fan1) <= 200)
    if ok:
        print("  → EŞLEME DOĞRU. Aşağıdaki LUX değerleri güvenilir.")
    else:
        print("  → EŞLEME TUTMADI. LUX baytları bu adreste DEĞİL;")
        print("    aşağıdaki değerlere güvenme, ham dökümde RPM'i ara.")

    print(f"\nORTAM IŞIĞI baytları:")
    print(f"  LUXM (0x18) = {luxm:3d}  0x{luxm:02x}")
    print(f"  LUXL (0x19) = {luxl:3d}  0x{luxl:02x}")
    print(f"  LUXH (0x1A) = {luxh:3d}  0x{luxh:02x}")
    print(f"  little-endian 16-bit (LUXL|LUXH<<8) = {luxl | (luxh << 8)}")
    print(f"  big-endian    16-bit (LUXH|LUXL<<8) = {luxh | (luxl << 8)}")

    if luxm == luxl == luxh == 0:
        print("\n  Hepsi sıfır — ya sensör bu pencereye yazmıyor ya da kapalı.")
        print("  Fenerle tekrar çalıştır; yine 0 ise bu kanal da ölü.")


if __name__ == "__main__":
    main()
