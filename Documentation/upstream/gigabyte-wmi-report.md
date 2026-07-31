# Draft comment for tangalbert919/gigabyte-laptop-wmi — issue #22 ("Support for Aero 16X")

> Durum: kullanıcı gönderecek. İçerik pinlenen sürücü sürümü `912b4e9`'a ve canlı
> salt-okuma testine (`Documentation/aerox16/test-plan.md` Part 1) göre doğrulandı.
> Ham kanıt: `Documentation/aerox16/wmi-ec.md`. Aşağıdaki gövde (---'den sonra) İngilizce,
> olduğu gibi yorum olarak yapıştırılabilir.

---

> **Disclosure:** this investigation and write-up were produced with AI assistance
> (Claude). The findings are from real measurements on my machine, but please take them
> as a starting point and verify anything you'd act on.

The driver already binds on this machine — the `GIGABYTE AERO` family is in
`gigabyte_laptop_known_working_platforms` (the `// 16X, why` entry, `aorus-laptop.c:760`),
GUIDs `ABBC0F6F`/`72`/`75` are all present, and the platform + hwmon devices come up.
Here's a full model report for the **AERO X16 1VH** so #22 can be closed with the
specifics: what works, three concrete bugs (RPM scaling, silent-mode misdetection,
`gpu_boost` range), and why custom fan control is dead here (it's the EC firmware, not
the driver). I decompiled the DSDT and cross-checked every WMBC/WMBD selector against the
GB_WMIACPI MOF dump (from the archived `s-h-a-d-o-w/alfc` project), then live-tested.
Happy to share the full DSDT dump and the annotated selector table.

## Hardware

| | |
|---|---|
| Model | GIGABYTE AERO X16 1VH (SKU EG61VH, DMI product family `GIGABYTE AERO`) |
| CPU / GPU | AMD Ryzen AI 7 350 (Krackan Point) + NVIDIA RTX 5060 Laptop |
| BIOS / EC | FB0A (AMI, 2026-05-28) / EC firmware 3.10 |
| EC access | eSPI shared-memory windows (`PECM` @ `0xFC7E0800`); the classic port-EC region is nearly empty on this chassis |
| Driver rev tested | `912b4e9` (out-of-tree build, kernel 7.1.1) |

## 1. `fan1_input`/`fan2_input` are byte-swapped — the driver over-swaps (bug)

On this platform the WMI/eSPI read path already returns RPM in native order, but
`convert_fan_rpm()` swaps it anyway, so hwmon ends up wrong. Measured on the live machine:

| Source | fan1 | fan2 |
|---|---|---|
| Raw WMBC `0xE4`/`0xE5` (via `debug_method`, no conversion) | `2970` (`0x0B9A`) | `3333` (`0x0D05`) |
| hwmon `fanN_input` (after `convert_fan_rpm`) | `39435` (`0x9A0B`) | `1293` (`0x050D`) |

`39435 = swab16(2970)` and `1293 = swab16(3333)` — the hwmon values are exactly the
byte-swapped raw values. The raw `0x0B9A = 2970` / `0x0D05 = 3333` RPM are the physically
correct speeds (fans spinning up at 95 °C load); `39435` RPM is impossible.

The cause is `gigabyte_laptop_hwmon_read()`:

```c
// aorus-laptop.c:248-252
if (!strcmp(dmi_get_system_info(DMI_PRODUCT_FAMILY),"GIGABYTE GAMING"))
    *val = output;                   // no swap
else
    *val = convert_fan_rpm(output);  // rol16(v,8) == swab16  <-- applied to AERO
```

`convert_fan_rpm` (`aorus-laptop.c:178-182`) was presumably added for older port-EC
AERO/AORUS models that store the tach big-endian, but this 2025/2026 AMD generation
(eSPI shared memory) returns it little-endian. So **`GIGABYTE AERO` belongs in the
no-swap branch** alongside `GIGABYTE GAMING` (or the swap should be keyed to the EC
access generation rather than a single family string). Only two tachometers exist here,
so `fan3_input`/`fan4_input` correctly read `0`.

## 2. Silent fan mode (`fan_mode 1`) is misrouted to an empty selector (bug)

`dmesg` on this machine:

```
aorus_laptop: Older model detected, using old ID
aorus_laptop: Using old light sensor method
```

The detection in `gigabyte_laptop_probe()`:

```c
// aorus-laptop.c:779-790
ret = gigabyte_laptop_get_devstate(FAN_SILENT_OLD, &output);   // FAN_SILENT_OLD = 0xFA
if (output < 0) {  // -1 on newer devices
    gigabyte->fan_silent_method = FAN_SILENT_MODE;   // 0x57
} else {           // 0 on older devices
    gigabyte->fan_silent_method = FAN_SILENT_OLD;    // 0xFA
}
fan_modes[1] = gigabyte->fan_silent_method;
```

The heuristic assumes newer devices return a **negative** value for WMBC `0xFA`. On the
X16, WMBC has no `Case (0xFA)` and returns **`0`** for it (verified: `debug_method 0xFA`
→ `0`, same as the also-unhandled `0xFC` → `0`, while a handled selector like
`0x57` → `1`). `0` is not `< 0`, so it takes the "older" branch and sets
`fan_modes[1] = 0xFA`.

Then `echo 1 > fan_mode` (silent) evaluates **WMBD `0xFA`, which is an empty case** on
this DSDT:

```asl
// dsdt.dsl:9105-9107, Method (WMBD, ...)
Case (0xFA)
{
}
```

So silent mode does nothing on this model. The intended selector `0x57`
(`FAN_SILENT_MODE`) *is* present and readable here (WMBC `0x57` → `1`). Suggested fix:
for the `GIGABYTE AERO` (AMD, 2025+) family force `fan_silent_method = FAN_SILENT_MODE`,
or make the probe treat only a strictly-negative return as "older" (a `0` from an
unhandled selector shouldn't mean "old"). How strongly this firmware acts on `0x57` is a
separate question — see §3; the gaming preset (`0x71`) is the one with a clearly audible
effect here.

## 3. Fixed-speed fan control **works**; the custom *curve* does not

Correction to an earlier read of mine: fixed-speed mode is fully functional here. Both
the preset modes and the fixed-speed path drive the fans; only the 15-point curve and the
raw per-fan duty writes are ignored. Measured on this machine (idle, ~40 °C, fan-stop
region — so any spin-up is the override, not the temperature):

| Path | Result |
|---|---|
| **`fan_mode 5` + `fan_custom_speed`** (`0x6A` SetFixedFanStatus + `0x6B` SetFixedFanSpeed) | **Works.** From `0` RPM it drives **both** fans (CPU *and* GPU) to ~**6900 RPM** at idle, and tracks the value (e.g. `229`→~90 % duty/6800 RPM, `90`→~6400 RPM). Verified on **AC and battery**. Note: the two fans move together (single speed), and `cs=0` doesn't stop them — you exit fixed mode (`fan_mode 0/1`) to spin down. So the driver's fixed-speed attributes already give real manual control, including the GPU fan. |
| `fan_mode 2` (`0x71`, "gaming") | Works — audibly ramps within seconds. |
| `fan_curve_index`/`fan_curve_data` (`0x68`, XFNW) | **Dead.** Writes succeed; reading back via WMBC `0x68` (index → `speed<<8\|temp` after the ~100 ms latch) returns `0` for every slot — the EC never copies XFNW into its curve table. No RPM effect even with `fan_mode 3` (TENF=1) active. |
| `fan_mode 3` (`0x67`, TENF) | Bit sets and reads back `1`, no behavioral change (only matters for the dead curve). |
| `fan_mode 4` (`0x70`, "auto-max") | Drives the fans to **0**, not max, on this firmware. |
| Raw WMBD `0x46`/`0x47` (FDTY/GDTY direct, via `acpi_call`) | No clear effect — the EC's periodic refresh keeps its own values. (Fixed mode above supersedes this anyway.) |

So the actionable picture is narrower than "custom fan is dead": **fixed-speed control is
usable today** (it's the full 0–100 % range the presets never touch), and only the
*15-point curve* is unconsumed. That curve table is even visible in plain shared memory
(offsets `0x3C-0x59` of the `0xFC7E0800` window), but nothing in the DSDT programs it from
XFNW — matching the symptom in #35 (Aero 16 XE5). GCC most likely writes curves through
the EC buffer-command interface (the ACPI `ERCD` method — the same channel the DSDT uses
for CPU power limits via `0xF1`-`0xF3`), not legacy XFNW; I can capture that traffic once
I have a Windows install.

## 4. `gpu_boost` value range is dangerous on this DSDT

WMBD `0x51` on this machine (`dsdt.dsl:9375-9410`):

| Arg | Effect |
|---|---|
| 0 | `NPCF.ACBT = 0` (dynamic boost off) |
| 1 | `NPCF.ACBT = LCBT` (saved boost value; but `LCBT = 0` under Linux → no-op) |
| 2 | **nothing** (no case in the switch) |
| 3 | **`Notify (^^GPP9.PEGP, 0x03) // Eject Request`** — asks ACPI to eject the dGPU |
| 4 | dGPU power-on / bus recheck |

`gpu_boost_store()` clamps to `mode <= 3` (`aorus-laptop.c:552`), so `echo 3 > gpu_boost`
is allowed and triggers the eject on this model. Worth a note in USAGE.md or a per-model
clamp, since on older models `0-3` were plain boost levels. (For reference, the working
way to move the dynamic-boost budget here is raw WMBD `0x4C`, `NPCF.ACBT = arg*8`.)

## 5. Small nits / eSPI-specific gotchas

- `fan_curve_data_show()` returns the driver's cached values, never the EC state. Using
  `gigabyte_laptop_get_devstate2(FAN_INDEX_VALUE, index, ...)` (WMBC `0x68`) for readback
  would have made the dead XFNW path in §3 obvious immediately.
- Several probe reads use the legacy port-EC, which is empty on this eSPI chassis, so they
  silently misfire: `ec_read(0x62)` for the motherboard temp → `temp3_input` reads `0`
  (`aorus-laptop.c:234`); `ec_read(0xB0/0xB1)` for the dual-fan check → never triggers
  "Dual fan speed control required" (`aorus-laptop.c:846-852`); `ec_read(0xD)` for the
  auto-max mode bit (`aorus-laptop.c:812`).
- `debug_method` was invaluable for all of the above (thanks!). A variant that also takes
  an Arg2, and/or a guarded WMBD counterpart, would make model bring-up much easier.

## Appendix: verified selector map for this model (DSDT + MOF cross-check)

Working / verified on X16 1VH: `0x57` CRAF (intended silent ID, readable), `0x64`/`0x65`
BCPS/BCPC (charge policy — works, we run an 80% limit), `0x66` FLVL, `0x67` TENF,
`0x68` XFNW / XFNR+XFN1, `0x6A` ADJF, `0x6B` FLVL/`0x70` FAN1(+FAN2/GFAN), `0x71` FANB
(gaming, works), `0x7D` TFAN, `0xE1` CTMP, `0xE2`(=`0xE3`) SKTC (same field twice),
`0xE4`/`0xE5` RPM1/RPM2, `0x46`/`0x47`/`0x50` FDTY/GDTY (duty telemetry), `0xC9` FNKS
(this is the internal-keyboard master switch, not just "Fn key"), `0xF6` KBLL, `0x61`
BHEA. Plus AMD-generation extras with no MOF names: `0x4A`/`0x4B`/`0x4C` (NVIDIA NPCF watt
limits), `0xED` (four performance profiles bundling CPU SPL/SPPT/FPPT + dGPU TGP),
`0xF1`/`0xF2`/`0xF3` (CPU power limits in mW through the EC `ERCD` command `0x45`).

Full annotated table + DSDT dump available on request.

---

# Follow-up: DADA30000 cevabı için taslak (2026-07-11)

> Durum: kullanıcı gönderecek (issue #22'ye yanıt). §3'ün "tracks the value"
> iddiasını geri çeker; E1-E6 matrisi `Documentation/aerox16/wmi-ec.md`'de.

---

@DADA30000 You're right, and thanks for pushing back — I re-tested with a clean
state machine and **I'm retracting the "tracks the value" part of §3**. What I can
reproduce from a clean state every time (idle, fans at 0 RPM, so any spin-up is the
override; tested on battery and AC):

- `fan_custom_speed` (0x6B) is written and reads back correctly from the EC, but
  **the EC's fixed mode ignores it**. Full sweep: for each value 10, 20, … 100 I
  exited to `fan_mode 0`, let the fans stop, wrote the value, re-entered mode 5 and
  sampled after 10 s — every single value lands in the same ~6500-6900 RPM max band
  (duty telemetry 84-86), zero correlation with the register (which faithfully reads
  back each value). Changing it while inside mode 5 does nothing either. So on this
  firmware "fixed speed" is effectively a max-blast toggle, exactly as you said —
  including at 50%.
- What fooled me: the EC's duty telemetry (WMBC `0x46`/`0x47`) is a slow, filtered
  value — after the max ramp it decays 100→94→88→87 over ~20 s. My two test values
  (229, then 90) were read at different points of that decay (6800 vs 6400 RPM),
  which looked like tracking. It wasn't. Sorry for the noise.
- Why modes 3/4 can *look* like max too: the driver's transitions leave ADJF set.
  `echo 3 > fan_mode` while in mode 5 hits the `"Custom mode is already enabled"`
  early-return (`aorus-laptop.c:357`) — the sysfs value changes but ADJF stays 1,
  so "mode 3" keeps blasting; 3→4 doesn't clear ADJF either. If you always pass
  through `fan_mode 0` (or 1/2) between the custom-family modes, the clean per-mode
  behavior is:
  - mode 3 (TENF=1): no behavioral change (curve table dead, as in the report);
  - mode 4 (`0x70`): fans go to **0** at idle on this firmware — worth a warning,
    under load that's a thermal hazard, not "auto-max";
  - mode 5 (ADJF=1): max, value ignored.

So the corrected summary for FB0A / EC 3.10: the only working WMI fan controls are
the presets (`0x71` gaming clearly audible; `0x57` silent nominal) plus
"mode 5 = max". Value-level control presumably lives behind the EC's ERCD command
channel that GCC uses on Windows; I'll capture that traffic when I get Windows onto
this machine and report back here. I'd rather keep the comparison public on GitHub
so the next X16 owner finds it — happy to keep digging together in this issue.
