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
symlink), but the canonical, git-tracked location — and the one `nh` and
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
```

There is no test suite. Validation is `nixos-rebuild build` succeeding, followed by
`switch` and manual verification (rebooting/relogging, checking a systemd unit, watching
a sensor file under `/sys`, etc.). Changes to power/thermal/WMI behavior are validated by
measurement (`powertop`, `nvtop`/`nvidia-smi`, battery draw — the firmware reports charge
units, there is no `power_now`; compute W as `current_now × voltage_now / 1e12` from
`/sys/class/power_supply/BAT1/`), not by a build passing.

### Lint / inspection tooling

`deadnix`, `statix` and `nixfmt-rfc-style` are installed system-wide
(`configuration.nix`, `environment.systemPackages`) — invoke them directly. Do **not**
reach for `nix run nixpkgs#…`: that resolves the *registry's* nixpkgs instead of this
flake's pinned one. How to run them is `--help`; what follows is only what `--help`
won't tell you.

- **`statix check .` must stay filtered or it tells you to break the config.** The
  `statix.toml` beside `flake.nix` disables `repeated_keys` (it wants each file's
  `boot`/`services`/`programs` blocks merged into one attrset, destroying the
  topic-by-topic grouping the Turkish section comments are built around) and
  `empty_pattern` (`{ ... }:` → `_:`, cosmetic and against NixOS module convention).
  With those two off the repo reports **zero findings**, so treat any statix output
  at all as a real regression.
- **`deadnix .`** reports exactly one hit — an unused `pkgs` in
  `hardware-configuration.nix`, which is generated; leave it.
- **Never run `nixfmt` tree-wide.** It reflows every file and wipes the hand-aligned
  comment columns this config relies on for readability.
- **`nix store diff-closures /nix/var/nix/profiles/system-{N,N+1}-link`** after a switch
  catches closure growth before it shows up as idle power.

## Architecture

**Two entry points sharing one Home Manager tree** (`flake.nix`):
- `nixosConfigurations.nixos` — the real system: `configuration.nix` + Stylix +
  `home-manager.nixosModules.home-manager` with
  `home-manager.users.zixar = import ./home.nix`.
- `homeConfigurations."zixar"` — a standalone HM path over the *same* `home.nix`, used
  only to iterate on HM-side config faster via `hms` without a full system rebuild.
  Stylix is imported by hand here (`modules/desktop/stylix-standalone.nix`) since there's
  no NixOS module to propagate it. The `osConfig`/`extraSpecialArgs` plumbing gotcha
  (why it must be passed manually here) is documented inline in `flake.nix` itself.

Keeping both paths reading identical `home.nix` is deliberate — don't add
HM config that only one of the two entry points can see.

### Desktop: Hyprland + ly (display manager), themed by Stylix

The desktop is a single session — Hyprland 0.56 (Lua config) + Matugen dynamic
theming (Waybar/Rofi/SwayNC/awww/Cava) — toggled by `rice.hyprland.enable = true;`
in `configuration.nix`. The flag is a safety valve, not an A/B switch: turning it
off leaves the system without a working session, since ly has nothing else to
offer. GNOME and an opt-in Sway + noctalia-shell rice both lived here until
2026-07-30, when the user settled on Hyprland alone; GNOME's silent providers
(bluetooth, udisks2, gvfs, the GTK portal, a polkit agent, the Adwaita icon theme,
hyprlock/hypridle for screen lock, hyprctl-based AC/BAT refresh-rate switching) were
absorbed into `hyprland-rice/{system,hm}.nix` first, then GNOME and the Sway rice
were deleted — see git history around that date if you need the "what GNOME was
quietly doing" audit. An older Hyprland + Caelestia/dms/noctalia + SDDM rice lives
on the `rice/caelestia` branch, unrelated to the current setup.

The full design doc — the SUPER+T wallpaper→matugen theme chain, why `withUWSM = true`
is mandatory (the session file exists even without it but fails with "Unit not
found"), the Lua config integration — is `docs/hyprland-rice.md`; read it before
touching the rice. The rice-internal gotchas (`AQ_DRM_DEVICES` placement, `withUWSM`,
session-target binding, matugen's source-color-index requirement) live in
`modules/desktop/hyprland-rice/CLAUDE.md`, which loads automatically when you work in
that directory. Waybar itself ships 16 selectable themes (the original bar plus 15
vendored `atif-1402/minimal-waybar-themes` ports, all recolored from one shared
monochrome palette) switchable without a rebuild via `waybar-theme --pick` /
SUPER+W — see `docs/hyprland-rice.md`'s "Waybar çoklu tema sistemi" section. The rofi
launcher is a vendored `adi1090x/rofi` type-5/style-4 painted from that *same* palette
(`rofi-themes.nix`), so it tracks the waybar themes rather than matugen — the trade-off
and rofi 2.0's gradient parser trap are in the same doc's "Rofi launcher teması" section.
The HM side follows the system flag automatically via `osConfig` — never add a second
toggle. This works on both the embedded and standalone HM paths only because of the
flake's `extraSpecialArgs.osConfig` pass-through, so changes to `flake.nix` can
silently break it.

The **display manager is ly** (`modules/desktop/ly.nix`), a TUI greeter on the TTY.
ly 1.4.1 takes 32-bit `0xSSRRGGBB` truecolor, so it's themed by feeding
`config.lib.stylix.colors` (kanagawa-dragon) directly into
`services.displayManager.ly.settings` (Stylix has no ly target).
`services.displayManager.defaultSession = "hyprland-uwsm"` (`configuration.nix`)
picks the working session entry: the `hyprland` package also installs a plain
"Hyprland" desktop file that does **not** work here (no uwsm systemd units without
`withUWSM = true`), and ly otherwise lists both.

**Stylix is the single source of truth for colors** (`modules/desktop/stylix.nix` /
`stylix-base.nix`). Custom base16 palettes live in `modules/desktop/schemes/*.yaml`;
switching is a one-line change of `palette` in `stylix-base.nix` (currently
`kanagawa-dragon`) + rebuild — the wallpaper is keyed off the same variable.
Stylix targets auto-theme GTK, ghostty, vscodium, vesktop, starship, etc. — don't set
per-app colors manually.

`environment.sessionVariables.NIXOS_OZONE_WL = "1"` (`configuration.nix`, 2026-07-30) is
system-wide: it flips all nixpkgs-wrapped Electron/Chromium apps (VSCodium, Vesktop,
1Password, claude-desktop) from XWayland to native Wayland, because those wrappers gate
`--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations` on exactly this
variable. It buys crisp HiDPI rendering plus xdg-decoration (Hyprland answers
`MODE_SERVER_SIDE`, so those apps stop drawing their own decorations). Watch two
regressions after touching it: ibus input in Electron apps (Wayland moves to
text-input-v3) and screen sharing (falls to the portal). The full decoration policy —
including why GTK/libadwaita headerbars can *never* be removed and why an app's
self-drawn chrome needs a per-app setting instead — is in `docs/hyprland-rice.md`'s
"Pencere süslemesi politikası" section; read it before re-litigating "make app X
borderless".

Runtime-written, HM-managed config files (Vesktop's `settings.json`) need the
"mutable-copy trick": after `linkGeneration`, the HM symlink is replaced with a writable
copy so the app can write to it at runtime, and stale `*.hm-backup` files are cleaned
*before* `checkLinkTargets` runs (it errors on them if they're stale). See the
`home.activation.vesktop*` blocks in `modules/apps/vesktop.nix` for the working pattern —
replicate it exactly if adding a new runtime-mutated config elsewhere; getting the
activation-script ordering wrong is the most common way this repo's `hms`/rebuild breaks.

### Power management — the 4.28W idle budget is a hard constraint

`modules/hardware/{power,power-display,gigabyte-wmi}.nix` implement an idle-power budget
that several commits worth of measurement went into (kernel params, ASPM, zram, powertop
--auto-tune device autosuspend, brightness/webcam/refresh-by-power-source). The CPU/
platform-profile layer is **power-profiles-daemon** (`power.nix`) — it **replaced TLP**
(2026-07-18): TLP's simultaneous governor+EPP+platform_profile writes fought
amd-pstate=active (AMD's own guidance), and its device tweaks (USB autosuspend, WiFi PS,
runtime PM) are now left to powertop --auto-tune + the kernel ASPM param + the EC.
The AC/BAT brightness+webcam+refresh-rate adaptation (a udev-on-ACAD → oneshot service, not
polling) survives in `power-display.nix` — which **also sets the PPD profile per power source**
(AC → `balanced`, BAT → `power-saver`), because PPD doesn't switch on AC/BAT by itself (that was
TLP's job) and there's no desktop power slider, so power-saver's 2.0 GHz cap would
otherwise stick on AC and make the desktop sluggish. BAT stays power-saver, so the idle budget is
untouched (the freq cap only bites under load). **Anything
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

The CPU power policy during gaming is **GPU-priority** (2026-07-18): `game-perf` sets
PPD to `balanced`, **not** `performance`, so the shared NVIDIA Dynamic Boost budget
(ACBT 80W) favors the dGPU instead of starving it — full rationale is in
`modules/hardware/gaming.nix`'s inline comments (CPU-bound titles opt back in with
`GR_CPUMAX=1 gamerun …`). Undervolting the CPU is **platform-locked** on this Gigabyte
board (see `docs/undervolt-curve-optimizer.md`), so capping its power appetite is the
only lever; 100°C is by-design (Zen5 mobile Tjmax), not a fault. When touching this chain, update
`docs/gaming.md`'s launch-options table to match.

### Docs directory

`docs/` holds durable, hand-maintained investigation logs (not code comments) — most
substantially `aerox16-1vh-wmi.md` (WMI/EC reverse-engineering measurements) and
`gaming.md` (launch options reference for the user). Treat these as living lab notebooks:
extend them when you add a measurement or change a documented behavior, don't let the
code and the doc drift apart.
