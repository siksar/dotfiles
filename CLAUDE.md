# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based NixOS configuration for a single machine: a Gigabyte AERO X16 (EG61H) laptop
with an AMD Ryzen AI 7 350 (Krackan Point, Zen 5) + Radeon 860M iGPU + NVIDIA RTX 5060
Max-Q dGPU (hybrid graphics). Full hardware profile lives in `CONTEXT.md`. One user
(`zixar`), one host (`nixos`). Comments and commit messages are in Turkish.

The flake lives at `/home/zixar/nixos-zixar` (a plain user-owned git repo, not root's
`/etc/nixos`). `/etc/nixos` is kept as a symlink to it for tooling that still assumes
the traditional path (bare `nixos-rebuild switch` with no `--flake` resolves through the
symlink), but the canonical, git-tracked location — and the one `nh`, Helix's nixd, and
this file's commands point at — is `/home/zixar/nixos-zixar`.

## Commands

```bash
# Rebuild and switch (system + embedded Home Manager) — asks for sudo
sudo nixos-rebuild switch --flake /home/zixar/nixos-zixar#nixos

# Build only, no activation (fast sanity check before switching)
nixos-rebuild build --flake /home/zixar/nixos-zixar#nixos

# Preferred day-to-day driver (wraps nixos-rebuild, does GC bookkeeping)
nh os switch

# Standalone Home Manager switch — use when only iterating on the HM tree
# (dconf keybindings, app dotfiles); reads the SAME home.nix as the embedded HM,
# so there's no drift between the two paths. Aliased to `hms` in the user shell.
nh home switch -b hm-backup

# Update flake inputs
nix flake update
nix flake lock --update-input <name>

# Search nixpkgs
nix search nixpkgs <term>
```

There is no test suite. Validation is `nixos-rebuild build` succeeding, followed by
`switch` and manual verification (rebooting/relogging, checking a systemd unit, watching
a sensor file under `/sys`, etc.). Changes to power/thermal/WMI behavior are validated by
measurement (`powertop`, MangoHud overlay, battery draw — the firmware reports charge
units, there is no `power_now`; compute W as `current_now × voltage_now / 1e12` from
`/sys/class/power_supply/BAT1/`), not by a build passing.

## Architecture

**Two entry points sharing one Home Manager tree** (`flake.nix`):
- `nixosConfigurations.nixos` — the real system: `configuration.nix` + Stylix +
  `home-manager.nixosModules.home-manager` with
  `home-manager.users.zixar = import ./home.nix`.
- `homeConfigurations."zixar"` — a standalone HM path over the *same* `home.nix`, used
  only to iterate on HM-side config faster via `hms` without a full system rebuild.
  Stylix is imported by hand here (`modules/desktop/stylix-standalone.nix`) since there's
  no NixOS module to propagate it.

Keeping both paths reading identical `home.nix` is deliberate — don't add
HM config that only one of the two entry points can see.

**`configuration.nix`** just wires up `imports` (system side) — hardware, boot, desktop
base, apps, networking/locale/audio/users. Look there first to find where a given system
concern lives.

**`home.nix`** does the same for the user/HM side — GNOME dconf settings, apps, dotfiles.

### Desktop: GNOME + GDM, themed by Stylix

The desktop is stock GNOME (`modules/desktop/gnome.nix`: `services.desktopManager.gnome`
+ GDM, a lean `environment.gnome.excludePackages` list) with user-side dconf settings in
`modules/desktop/gnome-hm.nix` (a minimal keybinding set — SUPER+Enter terminal, SUPER+M
fan cycle, SUPER+Q close, SUPER+1..9 workspaces, Copilot key → Claude Desktop — plus the
mutter `variable-refresh-rate` experimental feature and the wallpaper symlink). The
previous Hyprland + Caelestia/dms/noctalia + SDDM rice lives on the `rice/caelestia`
branch if it's ever needed again.

**Stylix is the single source of truth for colors** (`modules/desktop/stylix.nix` /
`stylix-base.nix`). Custom base16 palettes live in `modules/desktop/schemes/*.yaml`
(`zixar-main` active, `ergenekon` alternate — converted from the old Caelestia schemes);
switching palette is a one-line change of `palette` in `stylix-base.nix` + rebuild.
Stylix targets auto-theme GTK/GNOME, ghostty, helix, vesktop, starship, etc. — don't set
per-app colors manually.

One critical GNOME-specific rule: a udev rule in `gnome.nix` tags the NVIDIA DRM device
`mutter-device-ignore` so mutter never opens the dGPU node — an open fd would block RTD3
D3cold and regress the idle power budget. PRIME offload (`gamerun`) is unaffected.

Runtime-written, HM-managed config files (Vesktop's `settings.json`) need the
"mutable-copy trick": after `linkGeneration`, the HM symlink is replaced with a writable
copy so the app can write to it at runtime, and stale `*.hm-backup` files are cleaned
*before* `checkLinkTargets` runs (it errors on them if they're stale). See the
`home.activation.vesktop*` blocks in `modules/apps/vesktop.nix` for the working pattern —
replicate it exactly if adding a new runtime-mutated config elsewhere; getting the
activation-script ordering wrong is the most common way this repo's `hms`/rebuild breaks.

### Power management — the 4.28W idle budget is a hard constraint

`modules/hardware/{power,tlp,gigabyte-wmi}.nix` implement an idle-power budget that
several commits worth of measurement went into (kernel params, ASPM, TLP AC/BAT profiles,
zram, WiFi power save, USB autosuspend, brightness/webcam-by-power-source). **Anything
added under `modules/hardware/` or `modules/apps/gaming.nix` must not run or poll while
idle** — see the design constraint comment at the top of `modules/hardware/gaming.nix`
("pil/idle tabanı 4.28W GERİLEMEZ"). scx_lavd, zram priority, gamemode hooks etc. are all
gated to only activate during an actual gaming session (`game-perf.service`), never at
boot.

`modules/hardware/gigabyte-wmi.nix` builds an out-of-tree kernel module
(`aorus-laptop`, fetched from GitHub) plus uses `acpi_call` for raw WMI/EC writes
(fan curve, dGPU Dynamic Boost budget via NPCF.ACBT) that the upstream driver doesn't
expose yet. This is fragile, DSDT/EC-version-specific, hand-reverse-engineered
territory — the reasoning and measured selector values are logged in
`docs/aerox16-1vh-wmi.md`; consult it (and the memory files) before changing WMBD
selector values.

AC/battery-dependent behavior is applied via a udev rule on `ACAD`
(`power_supply` online/offline) triggering a oneshot systemd service, not polling —
follow this pattern for any new AC-state-dependent tuning rather than a timer.

### Gaming stack

`modules/hardware/gaming.nix` (system layer: gamemode, scx_lavd scheduler, ntsync,
zram, `game-perf.service`) + `modules/apps/gaming.nix` (HM layer: the `gamerun` shell
wrapper and MangoHud config) together implement the launch chain documented in
`docs/gaming.md`. Steam launch options are `gamerun %command%`; `gamerun` is a
`pkgs.writeShellScriptBin` wrapper handling dGPU PRIME offload, DLSS 4.5 env vars,
Reflex, ntsync, and CPU pinning (`GR_PIN`), then `exec`s `gamemoderun`, whose
start/stop hooks drive `game-perf.service` (scx_lavd + the WMI 0xED perf profile on AC).
When touching this chain, update `docs/gaming.md`'s launch-options table to match.

### Docs directory

`docs/` holds durable, hand-maintained investigation logs (not code comments) — most
substantially `aerox16-1vh-wmi.md` (WMI/EC reverse-engineering measurements) and
`gaming.md` (launch options reference for the user). Treat these as living lab notebooks:
extend them when you add a measurement or change a documented behavior, don't let the
code and the doc drift apart.
