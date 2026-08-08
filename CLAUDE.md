# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flake-based NixOS configuration for a single machine: a Gigabyte AERO X16 (EG61H) laptop
with hybrid graphics (AMD Radeon 860M iGPU + NVIDIA RTX 5060 Max-Q dGPU). One user
(`zixar`), one host (`nixos`). Comments and commit messages are in Turkish.
**The hardware table, the tree map and the expected lint output live in `README.md`** —
this file carries the rules and the traps, not the inventory. Don't duplicate them back
in here; a fact with two homes is a fact that goes stale (that is exactly how the stale
paths found on 8 Aug 2026 got in).

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
**measurement**, not by a build passing — the how is in
`Documentation/aerox16/power.md` (note the firmware reports charge units, so there is no
`power_now` to read).

### Lint / inspection tooling

`deadnix`, `statix` and `nixfmt` are installed system-wide — invoke them directly. Do
**not** reach for `nix run nixpkgs#…`: that resolves the *registry's* nixpkgs instead of
this flake's pinned one. README has the commands and their expected output; what follows
is only what neither `--help` nor README will tell you.

- **`statix check .` must stay filtered or it tells you to break the config.** The
  `statix.toml` beside `flake.nix` disables `repeated_keys` (it wants each file's
  `boot`/`services`/`programs` blocks merged into one attrset, destroying the
  topic-by-topic grouping the Turkish section comments are built around) and
  `empty_pattern` (`{ ... }:` → `_:`, cosmetic and against NixOS module convention).
- **Both linters have a zero-noise baseline, so any deviation is a regression**: statix
  clean, deadnix exactly one hit (the generated `hardware-configuration.nix` — leave
  it). Don't update this line to match a new finding; fix the finding.
- **Never run `nixfmt` tree-wide.** It reflows every file and wipes the hand-aligned
  comment columns this config relies on for readability.
- **`nix store diff-closures /nix/var/nix/profiles/system-{N,N+1}-link`** after a switch
  catches closure growth before it shows up as idle power.

## Finding things

**`MAINTAINERS` is the topic → file map — start there.** It uses the Linux kernel's
format (`F:` file pattern, `S:` status, `T:` doc, `W:` warning), so it greps:
`grep -A8 'GÜÇ' MAINTAINERS`, `grep -B3 'F:.*sched' MAINTAINERS`. It carries the
warnings that would otherwise cost you a measurement session to rediscover (which EC
selectors self-revert, which basenames can't be renamed, what's BIOS-locked).
`README.md` has the tree map and the hardware table.

The tree is named **by topic, not by purpose** — `system/kernel/sched.nix`, not
`gaming.nix`. Four layers with FHS semantics (`system/`, `usr/`, `home/`, `lib/`);
README draws the map, and the rule that matters here is this one:

`system/` and `usr/` are NixOS modules, `home/` is a Home Manager module. They are
**separate eval contexts and cannot import each other** — mixing them is a hard error,
not a lint. A topic that touches both therefore gets two files
(`system/kernel/sched.nix` + `home/apps/games.nix`), and `lib/` exists precisely because
plain data (theme, schemes, wallpapers) has to be readable from both sides.

### Renaming rule — this one bites

`${./foo}` copies a path into the store and **the store path's name is the basename**.
So:

- **`.nix` module files rename freely** — they're only `import`ed; their paths never
  enter a derivation.
- **Data files/dirs reached via `${./…}` or `src = ./…` may MOVE but NOT be renamed.**
  Currently: `system/arch/aerox16/acpi/*`, `keyboard-rgb/src/`, `home/desktop/wm/*.lua`,
  `home/desktop/theme/*`, `bar/waybar-themes/`, `bar/waybar-mono*.css`,
  `launcher/rofi-themes/`, `launcher/rofi-mono-overrides.rasi`, `lib/schemes/*.yaml`,
  `lib/wallpapers/*`.
- **`builtins.readFile ./x` does NOT bind the basename** — it inlines the *content* at
  eval time, no store copy, no derivation name. That's the only reason
  `bar/waybar-style.css` and `notify/swaync-style.css` are absent from the list above
  while their neighbours are on it; check *how* a data file is consumed before assuming
  it's pinned.
- **Comments inside `''…''` strings are NOT Nix comments** — they're script text and
  they hash. A typo fix inside `wmi.nix`'s `postPatch` recompiles the out-of-tree
  kernel module and rehashes initrd. (Learned the expensive way, 31 Jul 2026.)

### Proving a move didn't change anything

Moving/renaming/reordering modules? The `drvPath` before/after procedure is the
`verifying-a-refactor` skill (`.claude/skills/verifying-a-refactor/`).

## Architecture

**Two entry points sharing one Home Manager tree** (`flake.nix`):
- `nixosConfigurations.nixos` — the real system: `configuration.nix` + Stylix +
  `home-manager.nixosModules.home-manager` with
  `home-manager.users.zixar = import ./home.nix`.
- `homeConfigurations."zixar"` — a standalone HM path over the *same* `home.nix`, used
  only to iterate on HM-side config faster via `hms` without a full system rebuild.
  Stylix is imported by hand here (`lib/theme-standalone.nix`) since there's
  no NixOS module to propagate it. The `osConfig`/`extraSpecialArgs` plumbing gotcha
  (why it must be passed manually here) is documented inline in `flake.nix` itself.

Keeping both paths reading identical `home.nix` is deliberate — don't add
HM config that only one of the two entry points can see.

### Desktop: Hyprland + ly (display manager), themed by Stylix

The desktop is a single session — Hyprland 0.56 (Lua config) + Matugen dynamic
theming (Waybar/Rofi/SwayNC/awww/Cava) — toggled by `desktop.hyprland.enable = true;`
in `configuration.nix`. The flag is a safety valve, not an A/B switch: turning it
off leaves the system without a working session, since ly has nothing else to
offer.

The full design doc — the SUPER+T wallpaper→matugen theme chain, why `withUWSM = true`
is mandatory (the session file exists even without it but fails with "Unit not
found"), the Lua config integration — is `Documentation/desktop.md`; read it before
touching the rice. The rice-internal gotchas (`AQ_DRM_DEVICES` placement, `withUWSM`,
session-target binding, matugen's source-color-index requirement) live in
`home/desktop/CLAUDE.md`, which loads automatically when you work in
that directory. Waybar's 16-theme system and the vendored rofi theme — the design, the
shared monochrome palette, and rofi 2.0's gradient parser trap — are in
`Documentation/desktop.md` + `home/desktop/CLAUDE.md`.
The HM side follows the system flag automatically via `osConfig` — never add a second
toggle. This works on both the embedded and standalone HM paths only because of the
flake's `extraSpecialArgs.osConfig` pass-through, so changes to `flake.nix` can
silently break it.

The **display manager is ly** (`system/desktop/login.nix`), a TUI greeter on the TTY —
its theming and the `defaultSession` trap are in `system/desktop/CLAUDE.md`.

**Stylix is the single source of truth for colors.** The base data — palette, opacity,
fonts, cursor — lives in `lib/theme.nix`, which is a plain *function*, not a module, so
both entry points can consume it: `system/desktop/theme.nix` imports it and layers the
NixOS-only target overrides on top, `lib/theme-standalone.nix` imports it for the
standalone HM path. Custom base16 palettes live in `lib/schemes/*.yaml`; switching is a
one-line change of `palette` in `lib/theme.nix` (currently `kanagawa-dragon`) + rebuild —
the wallpaper is keyed off the same variable.
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
self-drawn chrome needs a per-app setting instead — is in `Documentation/desktop.md`'s
"Pencere süslemesi politikası" section; read it before re-litigating "make app X
borderless".

Runtime-written, HM-managed config files (Vesktop's `settings.json`) need the
"mutable-copy trick": after `linkGeneration`, the HM symlink is replaced with a writable
copy so the app can write to it at runtime, and stale `*.hm-backup` files are cleaned
*before* `checkLinkTargets` runs (it errors on them if they're stale). See the
`home.activation.vesktop*` blocks in `home/apps/vesktop.nix` for the working pattern —
replicate it exactly if adding a new runtime-mutated config elsewhere; getting the
activation-script ordering wrong is the most common way this repo's `hms`/rebuild breaks.

### Power management — the 4.28W idle budget is a hard constraint

`system/kernel/{power,power-display}.nix` + `system/arch/aerox16/wmi.nix` implement an idle-power budget
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
added under `system/` or `home/apps/games.nix` must not run or poll while
idle** — see the design constraint comment at the top of `system/kernel/sched.nix`
("pil/idle tabanı 4.28W GERİLEMEZ"). scx_lavd, zram priority, gamemode hooks etc. are all
gated to only activate during an actual gaming session (`game-perf.service`), never at
boot.

`system/arch/aerox16/wmi.nix` builds an out-of-tree kernel module
(`aorus-laptop`, fetched from GitHub) plus uses `acpi_call` for raw WMI/EC writes
(fan curve, dGPU Dynamic Boost budget via NPCF.ACBT) that the upstream driver doesn't
expose yet. This is fragile, DSDT/EC-version-specific, hand-reverse-engineered
territory — the reasoning and measured selector values are logged in
`Documentation/aerox16/wmi-ec.md`; consult it (and the memory files) before changing WMBD
selector values.

AC/battery-dependent behavior is applied via a udev rule on `ACAD`
(`power_supply` online/offline) triggering a oneshot systemd service, not polling —
follow this pattern for any new AC-state-dependent tuning rather than a timer.

### Gaming stack

`system/kernel/sched.nix` (system layer: gamemode, scx_lavd scheduler, ntsync,
zram, `game-perf.service`) + `home/apps/games.nix` (HM layer: the `gamerun` shell
wrapper and MangoHud config) together implement the launch chain documented in
`Documentation/gaming.md`. Steam launch options are `gamerun %command%`; `gamerun` is a
`pkgs.writeShellScriptBin` wrapper handling dGPU PRIME offload, DLSS 4.5 env vars,
Reflex, ntsync, and CPU pinning (`GR_PIN`), then `exec`s `gamemoderun`, whose
start/stop hooks drive `game-perf.service` (scx_lavd + the WMI 0xED perf profile on AC).

`gamerun` has **three** callers, not one — its env contract is load-bearing for all of
them, so read them before changing what it exports:

| Caller | Entry point | Note |
|---|---|---|
| Steam | launch options `gamerun %command%` | the documented path |
| `home/apps/minecraft.nix` | `mc-run` → `gamerun`, via Prism's `WrapperCommand` | adds MC-only OpenGL env first, so it can't leak into Steam |
| `home/apps/emu.nix` | `emu-run {rpcs3\|shadps4}` → `gamerun` | native Vulkan; the DLSS/Reflex/Proton vars are inert-but-harmless here |

The CPU power policy during gaming is **GPU-priority** (2026-07-18): `game-perf` sets
PPD to `balanced`, **not** `performance`, so the shared NVIDIA Dynamic Boost budget
(ACBT 80W) favors the dGPU instead of starving it — full rationale is in
`system/kernel/sched.nix`'s inline comments (CPU-bound titles opt back in with
`GR_CPUMAX=1 gamerun …`). Undervolting the CPU is **platform-locked** on this Gigabyte
board (see `Documentation/aerox16/undervolt.md`), so capping its power appetite is the
only lever; 100°C is by-design (Zen5 mobile Tjmax), not a fault. When touching this chain, update
`Documentation/gaming.md`'s launch-options table to match.

### Networking — zapret and Mullvad are mutually exclusive

`system/net/core.nix` is the base (NetworkManager, systemd-resolved as a cache-only
stub, BBR + fq + TCP Fast Open, regdomain TR, and a wired→WiFi-off arbiter built as an
NM dispatcher script plus a boot oneshot — not a poller, same rule as the power layer).

Turkish ISP DPI is worked around by **zapret** (`system/net/censorship.nix`, 1 Aug 2026):
an `nfqws` daemon fed by its own `inet zapret` nftables table (OUTPUT hook at mangle
priority, `queue flags bypass to 200`, so the packet takes the normal kernel path if
nfqws is down). It starts at boot but costs nothing idle — it only runs when a packet
arrives, so the 4.28 W budget is untouched.

**This replaced Mullvad, and the two cannot both be on** (`system/net/vpn.nix` keeps
Mullvad at `enable = false`). Both manipulate output packets; the nfqueue rule collides
with tun0/default-route. To go back, flip `vpn.nix` on and take `censorship.nix` out —
there is no clean way to keep both.

The desync strategy in `censorship.nix` is **measured, not guessed** — `blockcheck` output
against a blocked SNI is what picks it, because Turkish DPI is selective (a strategy
that works on YouTube can still fail on a blacklisted domain). Verify a single domain
with `sudo blockcheck example.com`, and keep the comment in the file matching the args
directly below it.

**Encrypted DNS lives in the same file, on purpose** (8 Aug 2026). nfqws rescues the
traffic; it does nothing about DNS, so a hijacked plain UDP/53 answer still sends you to
the wrong address. `censorship.nix` therefore also runs `dnscrypt-proxy` (DoH):
app → `127.0.0.53` (resolved stub + cache) → `127.0.0.2` (dnscrypt) → HTTPS to
Cloudflare/Google. Two traps live in that block:

- **`services.resolved.settings.Resolve.Domains = [ "~." ]` is load-bearing.** Without
  it resolved prefers NetworkManager's per-link DHCP DNS — the ISP's server — and the
  whole DoH chain is bypassed. The cost is that captive portals (hotel/airport WiFi)
  work *by* DNS hijacking, so they cannot complete while it's set.
- **Never hand-write `sources` / `minisign_key`.** The module's `upstreamDefaults = true`
  merges upstream's TOML, which already carries the resolver list, the signing key and a
  `/var/cache/dnscrypt-proxy/…` path matching the unit's `CacheDirectory`. The merge is
  shallow (`jq add`), so defining `sources` yourself also deletes upstream's
  `[sources.relays]`.

The predecessor of this block, `system/net/dns.nix`, was deleted in the same commit: it
had never been in any import list, so it had never been evaluated, and it carried three
fatal errors (a `services.resolved.dns` option that does not exist, `":53"` ports in
`fallbackDns`, and a corrupted `minisign_key`). **A Nix file that nothing imports is not
"pending", it is untested** — check `configuration.nix`/`home.nix` before trusting one.

### Docs directory

`Documentation/` holds durable, hand-maintained investigation logs (not code comments).
Treat them as living lab notebooks: extend them when you add a measurement or change a
documented behavior, don't let the code and the doc drift apart.

| Path | Holds |
|---|---|
| `aerox16/wmi-ec.md` | WMI/EC reverse-engineering measurements — the selector values |
| `aerox16/power.md` | how the 4.28 W idle baseline was measured |
| `aerox16/undervolt.md` | why Curve Optimizer is platform-locked |
| `aerox16/keyboard-rgb.md` | the HID LampArray finding |
| `aerox16/test-plan.md`, `aerox16/dsdt.dsl.txt` | validation checklist, decompiled DSDT |
| `desktop.md`, `gaming.md`, `1password.md` | design docs / user-facing references |
| `upstream/` | reports written to be sent upstream |
| `archive/` | **FROZEN** — paths and statuses inside are deliberately stale. Do not "fix" them. |
