# SSDT9 binary patch: 2x 'PC00'->'PCI0' + OemRevision +1 + checksum düzeltme.
# Kullanım: patch-ssdt9.py <pristine.dat> <çıktı.aml>
# Neden OemRev +1: kernel tables.c 'existing >= new -> skip' der; eşit kalırsa
# override OLMAZ ve tablo scan'de DUPLICATE yüklenir (AE_ALREADY_EXISTS).
import sys

src, dst = sys.argv[1], sys.argv[2]
data = bytearray(open(src, "rb").read())

def fail(msg):
    sys.exit(f"patch-ssdt9: HATA: {msg}")

if len(data) != 13612:                  fail(f"boy {len(data)} != 13612")
if bytes(data[0:4])   != b"SSDT":       fail("imza SSDT değil")
if bytes(data[10:16]) != b"OptRf2":     fail("OemId OptRf2 değil")
if bytes(data[16:24]) != b"Opt2Tabl":   fail("OemTableId Opt2Tabl değil")

offs, i = [], data.find(b"PC00")
while i != -1:
    offs.append(i); i = data.find(b"PC00", i + 1)
if len(offs) != 2:                      fail(f"'PC00' sayısı {len(offs)} != 2: {offs}")
for o in offs:
    data[o:o+4] = b"PCI0"

oemrev = int.from_bytes(data[24:28], "little")
if oemrev != 0x1000:                    fail(f"OemRevision 0x{oemrev:x} != 0x1000 (BIOS güncellendi mi?)")
data[24:28] = (oemrev + 1).to_bytes(4, "little")

data[9] = 0
data[9] = (0x100 - sum(data)) & 0xFF
assert sum(data) % 256 == 0 and b"PC00" not in data

open(dst, "wb").write(bytes(data))
print(f"patch-ssdt9: OK ofsetler={offs} OemRev=0x{oemrev+1:04x} checksum=0x{data[9]:02x}")
