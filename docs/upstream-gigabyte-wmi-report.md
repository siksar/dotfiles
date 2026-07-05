# Draft issue for tangalbert919/gigabyte-laptop-wmi

> Durum: TASLAK — kullanıcı gönderecek. Tek issue olarak ya da bölünerek
> (bug raporları ayrı, model raporu ayrı) gönderilebilir.

---

**Title:** AERO X16 1VH (2026, EG61VH): model report — hwmon works (with RPM
byte-swap), all custom-fan paths ignored by EC, gpu_boost=3 triggers dGPU
eject on this DSDT

## Hardware

| | |
|---|---|
| Model | GIGABYTE AERO X16 1VH (SKU EG61VH, DMI product family `GIGABYTE AERO`) |
| CPU/GPU | AMD Ryzen AI 7 350 + RTX 5060 Laptop |
| BIOS / EC | FB0A (AMI, 2026-05-28) / EC firmware 3.10 |
| Driver rev | 912b4e9 |
| WMI GUIDs | ABBC0F6F / ABBC0F72 / ABBC0F75 all present, driver binds fine |

I decompiled the DSDT and cross-checked every WMBC/WMBD selector against the
GB_WMIACPI MOF dump (from the archived alfc project), then live-tested the
fan paths. Happy to share the full DSDT dump and a complete selector table.

## 1. Fan RPM values are byte-swapped (bug)

`fan1_input`/`fan2_input` return e.g. `39435` (0x9A0B) while the real speed
is 0x0B9A = 2970 RPM. On this platform the EC exposes RPM in the eSPI shared
memory region as big-endian u16 (`RPM1`/`RPM2` @ offsets 0x13/0x15 of the
0xFC7E0800 window). A `swab16()` fixes it. Also only two tachometers exist
on this hardware — `fan3_input`/`fan4_input` always read 0.

## 2. All custom-fan control paths are ignored by this EC firmware

Everything is accepted at the WMI/ACPI level (no errors, registers latch),
but the EC's fan control loop never consumes any of it:

| Path | What happens |
|---|---|
| `fan_curve_index`/`fan_curve_data` (0x68, XFNW) | Writes succeed; reading back via WMBC 0x68 (XFNR/XFN1) returns 0 for every slot — the EC never copies XFNW into its curve table. No RPM effect with custom mode (TENF=1) active. |
| `fan_mode 3` (0x67 TENF) | Bit sets and reads back 1, no behavioral change. |
| `fan_mode 5` + `fan_custom_speed` (0x6A ADJF + 0x66 FLVL) | No RPM effect. |
| `fan_mode 4` (0x70, writes FAN1=FAN2=speed, GFAN=1) | FAN1 register holds the value (readable via WMBC 0x70) but the actual PWM outputs (FDTY/GDTY, readable via WMBC 0x46/0x47) stay on the EC's own values. |
| Raw WMBD 0x46/0x47 (FDTY/GDTY direct, via acpi_call) | Register holds ~20 s, then the EC's periodic refresh overwrites it. RPM never follows. |
| Raw WMBD 0x7D (TFAN flag) | Sets fine, no effect. |

The **preset modes do work**: 0x71 ("gaming" in the driver) audibly ramps
fans within seconds; 0x57 (driver "silent") switches too. So mode switching
is fine — only user-defined speeds/curves are dead. This looks like the same
family of symptoms as #35 (Aero 16 XE5): on the 2025/2026 AMD AERO
generation, Gigabyte Control Center presumably programs custom fan curves
through the EC's buffer command interface (the ACPI `ERCD` method — the same
channel the DSDT uses for CPU power limits via selectors 0xF1-0xF3), not
through the legacy XFNW path. The 15-temperature / 15-speed curve table is
actually visible in plain shared memory (offsets 0x3C-0x59 of the
0xFC7E0800 window), but nothing in the DSDT writes it.

Suggestion: nothing to fix in the driver for this (the payload format
`data<<8|index` exactly matches the DSDT's `speed<<16|temp<<8|index`); this
is EC-firmware behavior. I can capture GCC's traffic once I have a Windows
install and report back.

## 3. `gpu_boost` value range is dangerous on this DSDT

WMBD 0x51 on this machine:

| Arg | Effect |
|---|---|
| 0 | NPCF.ACBT = 0 (dynamic boost off) |
| 1 | NPCF.ACBT = saved boost value (dynamic boost on) |
| 2 | **nothing** (no case in the DSDT switch) |
| 3 | **Notify(PEGP, 3) — dGPU eject request(!)** |
| 4 | dGPU power-on / bus recheck |

So on this model `echo 3 > gpu_boost` asks ACPI to eject the dGPU. Maybe
worth a note in USAGE.md, or a per-model clamp, since on older models 0-3
were plain boost levels.

## 4. Small driver nits

- `fan_curve_data_show()` returns the driver's cached values, never the EC
  state; using `gigabyte_laptop_get_devstate2(FAN_INDEX_VALUE, index, ...)`
  (WMBC 0x68 takes the index as Arg2 and returns `speed<<8|temp` after the
  EC's ~100 ms latch) would give true readback and would have made the dead
  XFNW path visible immediately.
- `fan_curve_data_store()` does `fan_curve.temperature[index] = data;`
  with u16 `data` — works only because the array element is u8; an explicit
  `data & 0xFF` would be clearer.
- `debug_method` was invaluable for diagnosing all of this (thanks!). A
  variant that also takes an Arg2, and/or a WMBD counterpart guarded behind
  a config option, would make model bring-up much easier.

## Extra: verified selector map for this model (DSDT + MOF cross-check)

Working/verified: 0x57 CRAF (silent), 0x64/0x65 BCPS/BCPC (charge policy —
works, we run 80% limit), 0x66 FLVL, 0x67 TENF, 0x68 XFNW/XFNR+XFN1,
0x6A ADJF, 0x6B/0x70 FAN1(+FAN2/GFAN), 0x71 FANB (gaming), 0x7D TFAN,
0xE1 CTMP, 0xE2=0xE3 SKTC (same field twice), 0xE4/0xE5 RPM1/RPM2 (BE),
0x46/0x47/0x50 FDTY/GDTY duty telemetry, 0xC9 FNKS (Fn key), 0xF6 KBLL,
0x61 BHEA, plus AMD-generation extras with no MOF names: 0x4A/0x4B/0x4C
(NVIDIA NPCF watt limits), 0xED (4 performance profiles setting CPU
SPL/SPPT/FPPT + dGPU TGP as a bundle), 0xF1/0xF2/0xF3 (CPU power limits in
mW through the EC ERCD command 0x45).

Full annotated table + DSDT dump available on request.
