# Draft PR for tangalbert919/gigabyte-laptop-wmi

> Durum: kullanıcı gönderecek. Gövde (---'den sonrası) İngilizce, PR açıklaması
> olarak olduğu gibi kullanılabilir. Kod değişikliği:
> `modules/hardware/aorus-laptop-silent-0x57.patch` (aynı diff aşağıda gömülü).
> Test edildi: AERO X16 1VH, sürücü 912b4e9 + reboot → "Newer model detected".

**Suggested title:** `aorus-laptop: fix silent fan mode on 2025+ AMD AERO by feature-detecting the 0x57 selector`

---

> **Disclosure:** the investigation, the patch, and this write-up were produced with
> AI assistance (Claude). I tested the change on my own machine (see *Testing* below),
> but please review it carefully before merging.

## Problem

On the 2025/2026 AMD AERO generation — verified on a **GIGABYTE AERO X16 1VH**
(SKU **EG61H**/EG61VH, BIOS FB0A, EC 3.10, DMI family `GIGABYTE AERO`) — silent fan
mode does nothing: `echo 1 > fan_mode` returns success but never changes the fans.

The cause is the old/new model probe in `gigabyte_laptop_probe()`:

```c
ret = gigabyte_laptop_get_devstate(FAN_SILENT_OLD, &output);   // 0xFA
if (output < 0) {          // "-1 on newer devices"
    gigabyte->fan_silent_method = FAN_SILENT_MODE;             // 0x57
} else {                   // "0 on older devices"
    gigabyte->fan_silent_method = FAN_SILENT_OLD;              // 0xFA
}
fan_modes[1] = gigabyte->fan_silent_method;
```

It decides "new vs old" from whether reading WMBC `0xFA` comes back **negative**. But on
this firmware WMBC has **no case for `0xFA`** (and no `Default`), so it just returns
**`0`** — the exact value the code treats as "older". The chassis is therefore
mis-detected as old, `fan_modes[1]` becomes `0xFA`, and selecting silent mode dispatches
WMBD `Case (0xFA) {}`, which is **empty** on this DSDT → a no-op.

Evidence on this machine:

- `dmesg`: `aorus_laptop: Older model detected, using old ID`
- via `debug_method` (WMBC reads): `0xFA → 0`, `0xFC → 0` (both unimplemented),
  `0x57 → 1` (implemented and readable)
- DSDT: `Method (WMBD ...) { Case (0xFA) { } ... }` is empty; the `WMBC` switch has no
  `0xFA` case and no `Default`.

## Idea

Don't infer the model era from a *firmware-dependent sentinel* on the **old** selector —
the "unimplemented → -1" assumption isn't universal (this firmware returns 0). Instead,
**feature-detect the new selector (`0x57`) directly**: if it evaluates, the model
supports the new silent ID; otherwise fall back to `0xFA`.

## Solution

```diff
@@ static int gigabyte_laptop_probe(struct device *dev)
 	u8 result, result2;
 	struct gigabyte_laptop_wmi *gigabyte = dev_get_drvdata(dev);
 
-	// Older devices are using a different method ID for silent fan mode.
-	// In that case, newer devices won't return anything when using that ID.
-	ret = gigabyte_laptop_get_devstate(FAN_SILENT_OLD, &output);
-	if (output < 0) { // -1 on newer devices
+	// Silent fan mode uses selector 0x57 on newer models, 0xFA on older ones.
+	// The original probe read 0xFA and treated a 0 return as "old", but 2025+
+	// AMD AERO firmware returns 0 for unimplemented selectors too, so this
+	// chassis was mis-detected as old and silent mode fell through to the empty
+	// WMBD 0xFA case. Feature-detect 0x57 directly instead.
+	ret = gigabyte_laptop_get_devstate(FAN_SILENT_MODE, &output);
+	if (ret == 0) { // 0x57 present -> newer model
 		pr_info("Newer model detected, using new silent fan mode ID");
 		gigabyte->fan_silent_method = FAN_SILENT_MODE;
 	}
-	else { // 0 on older devices
+	else {
 		pr_info("Older model detected, using old ID");
 		gigabyte->fan_silent_method = FAN_SILENT_OLD;
 	}
```

The probe is a read-only WMBC call, so there's no behavioral risk from the detection
itself.

## Testing

Built at `912b4e9` with this patch and rebooted on the AERO X16 1VH:

- `dmesg` now prints `aorus_laptop: Newer model detected, using new silent fan mode ID`
- `fan_mode 1` now dispatches WMBD `0x57` instead of the empty `0xFA` case
- all other sysfs attributes unchanged

## Why it matters

The 0-vs-negative ambiguity isn't specific to one board — the 2025/2026 AMD AERO/AORUS
firmware returns `0` for *any* unimplemented WMBC selector, so the same misdetection hits
this whole new-device line. This restores silent mode for them and, concretely, unblocks
other **AERO X16 EG61H** owners already running this driver. For those newer machines it's
the difference between the driver's fan modes working or silently doing nothing.

## Note for the maintainer

If any genuinely-old model's firmware also returns `0` (rather than erroring) for an
unimplemented `0x57`, this feature-detect could prefer `0x57` there too. If that's a
concern, the same effect can be gated by DMI (force `FAN_SILENT_MODE` for the
`GIGABYTE AERO` family) — happy to reshape the patch either way. A fuller model report
for this chassis (RPM readback, `gpu_boost=3` = dGPU eject on this DSDT, and a
working fixed-speed fan path via `fan_mode 5` + `fan_custom_speed`) is in #22.
