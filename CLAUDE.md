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

### Branches — one line, not a fan (renamed 16 Aug 2026)

**`zixar` is the working branch and the GitHub default** (it was `rice/caelestia-v2`
until 16 Aug 2026; the old remote branch was deleted after verifying both refs pointed
at the same commit). Work happens here; there is nothing to merge *into*.

Every other branch is a **checkpoint on this same line — all four are strict ancestors
of `zixar`**, so nothing is diverged, nothing is unmerged, and none of them is "the
other half" of anything. They are bookmarks for reading old states, and the honest way
to reach one is its distance back from `zixar`:

| Branch | Back from `zixar` | What that state is |
|---|---|---|
| `claude-md-audit` | 8 | **last state of the hand-rolled waybar rice** (9 Aug 2026) |
| `rice/gnome` | 16 | earlier waybar-rice state (5 Aug 2026) |
| `rice/caelestia` | 41 | Caelestia already in, but **old repo layout** (13 Jul 2026) |
| `master` | 75 | oldest checkpoint (2 Jul 2026) |

The trap this table exists to kill: the branch *names* do not describe their contents.
`rice/caelestia` does **not** hold the pre-Caelestia rice — it holds Caelestia in the
pre-reorg tree. The pre-Caelestia rice is on `claude-md-audit`, whose name suggests
something else entirely. Verify with `git ls-tree -r --name-only <branch>` before
trusting a branch name; that is how the wrong pointer sat in this file until 16 Aug 2026.

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
- **`bash scripts/verify-context.sh` is the executable gate** — both evals (system + HM),
  statix, deadnix-against-baseline, plus a dated ground-truth block (nixpkgs rev, hyprland
  version, kernel, both drvPaths). ~13 s. A `Stop` hook in `.claude/settings.local.json`
  runs it automatically whenever the turn leaves an uncommitted `.nix` change, and blocks
  on failure; on a clean tree it costs 6 ms. The `PostToolUse` parse hook beside it is a
  *different* gate and cannot replace this one — see the rule below.
- **A finding derived from grep/regex/reading is not a finding until something was run.**
  On 15 Aug 2026 a textual audit of this tree produced 31 confident hits — orphan modules,
  dead `./` refs, stale doc paths, a missing systemd unit — and **every one was false**
  (the regex matched `./../lib/x` inside `../../lib/x`; prose shorthand like `power.nix`
  read as a dead path; `geo-weather-sync` was already documented as removed in a `W:`
  line). Live eval settled all 31. So: verify by execution, then report. This is also why
  no doc-linter lives in `scripts/` — it would manufacture exactly that noise.

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
some things have to be readable from both sides — plain data (theme, schemes,
wallpapers) but also shared package-building functions: `lib/gamerun.nix` is a
`{ pkgs }: pkgs.writeShellScriptBin …` function (same calling convention as
`lib/theme.nix`) imported by both `usr/steam.nix` (`programs.steam.extraPackages`,
puts it in Steam's FHS sandbox) and `home/apps/games.nix` (`home.packages`, puts
it on the normal user PATH).

### Renaming rule — this one bites

`${./foo}` copies a path into the store and **the store path's name is the basename**.
So:

- **`.nix` module files rename freely** — they're only `import`ed; their paths never
  enter a derivation.
- **Data files/dirs reached via `${./…}` or `src = ./…` may MOVE but NOT be renamed.**
  Currently: `system/arch/aerox16/acpi/*`, `keyboard-rgb/src/`, `home/desktop/wm/*.lua`,
  `home/desktop/caelestia/schemes/*.txt`, `home/desktop/caelestia/templates/*`,
  `lib/schemes/*.yaml`, `lib/wallpapers/*`.
- **`builtins.readFile ./x` does NOT bind the basename** — it inlines the *content* at
  eval time, no store copy, no derivation name, so a file consumed this way is exempt
  from the rule above. No file in the tree currently relies on this exemption (the
  waybar/swaync rice that used to was removed 9 Aug 2026, replaced by Caelestia) —
  check *how* a data file is consumed before assuming it's pinned if you reintroduce it.
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

### Desktop: Hyprland + ly (display manager), themed by Caelestia + Stylix

The desktop is a single session — Hyprland (Lua config) + **Caelestia**, a
Quickshell-based shell providing bar/launcher/notifications/lock/idle + its own
runtime Material You theme engine — toggled by `desktop.hyprland.enable = true;`
in `configuration.nix`. The flag is a safety valve, not an A/B switch: turning it
off leaves the system without a working session, since ly has nothing else to
offer. Caelestia replaced a hand-rolled waybar+rofi+swaync+matugen+hyprlock+hypridle
rice on 9 Aug 2026 (clean cutover, no transition toggle). That rice is readable as prior
art on **`claude-md-audit`** (tip `2fe6ee9`, 9 Aug 2026) — *not* on `rice/caelestia`,
which this file claimed until 16 Aug 2026 and which actually holds Caelestia in the
pre-reorg layout. The deletion commit is `bdaf58c` (15 Aug 2026), so `bdaf58c^` is the
same state if you prefer a SHA to a branch name. Prior art only — the tree layout
predates the `system/ usr/ home/ lib/` reorg, so nothing there is mergeable.

The full design doc — the Caelestia IPC surface, the SUPER+T wallpaper→scheme chain, why
`withUWSM = true` is mandatory (the session file exists even without it but fails with
"Unit not found"), the Lua config integration — is `Documentation/desktop.md`; read it
before touching the rice. The rice-internal gotchas (`AQ_DRM_DEVICES` placement,
`withUWSM`, session-target binding, Caelestia's fixed 8-entry bar / no plugin system /
package-only custom schemes) live in `home/desktop/CLAUDE.md`, which loads
automatically when you work in that directory.
**Caelestia has no binary cache** (unlike this repo's other third-party inputs) — every
`flake update` rebuilds quickshell (its own git.outfoxxed.me pin, not nixpkgs's) and Qt6
from source; keep the input pinned and update deliberately.
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
boot. The Serpantinum session (`system/desktop/serpantinum.nix` +
`home/desktop/serpantinum/`) is an explicit exception to this rule, not a regression of
it: it is not the default session, it is a quarantined second ly entry, and it costs
nothing unless a login explicitly picks it — details in `home/desktop/CLAUDE.md`.

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

**CPU scheduling — Zen5/Zen5c hybrid, and the scheduler DOES know** (`system/kernel/cores.nix`,
corrected 16 Aug 2026): this CPU's fast (Zen5: `0,2,4,6`+SMT, 5.09GHz) and efficiency
(Zen5c: `1,3,5,7`+SMT, 3.5GHz) cores are fully visible to the scheduler — `amd_hfi` is bound to
`AMDI0104:00`, ITMT is on (`sched_itmt_enabled` = `Y`), and `sched_core_priority` carries
Zen5 196/203 vs Zen5c 135 (full evidence: `Documentation/aerox16/cpu-hybrid.md`).
**The ITMT interface lives in debugfs, not `/proc/sys`** — `/sys/kernel/debug/x86/`, root-only;
the 10 Aug 2026 "scheduler is blind" claim came from probing paths that no longer exist, and
`prefcore = disabled` is deliberate upstream behavior on designs that have workload
classification, not a missing piece. So a short single-thread burst lands on a Zen5 core
*by design, not by coin flip*, and rides `power-display.nix`'s AC-time `scaling_max_freq`/boost
restore straight to 5GHz. `cores.nix` pins `systemd.settings.Manager.CPUAffinity` to
Zen5c-only, so the whole desktop (fork/exec inheritance) runs there by default and 5GHz becomes
structurally unreachable outside a game. The mask is soft (`sched_setaffinity`, not cgroup
`AllowedCPUs`) — `taskset` always punches through it: `gamerun` does so unconditionally (see
Gaming stack below), and the fish alias `aia` (`home/shell/fish.nix`) is the escape hatch for
one-off heavy jobs (`aia cargo build`). `nix-daemon` is exempted directly in `cores.nix` so builds
keep all 16 CPUs.

### Gaming stack

`system/kernel/sched.nix` (system layer: gamemode, scx_lavd scheduler, ntsync, zram,
`game-perf.service`) + `lib/gamerun.nix` (the `gamerun` wrapper itself — a plain
`{ pkgs }:` function, same convention as `lib/theme.nix`) together implement the launch
chain documented in `Documentation/gaming.md`. `home/apps/games.nix` puts it on the HM
PATH (`home.packages`); `usr/steam.nix` puts it inside Steam's own FHS sandbox
(`programs.steam.extraPackages`) — **both are required, not redundant**, and both resolve
to the same derivation (`flake.nix`'s `useGlobalPkgs = true`).

**gamerun was completely dead until 10 Aug 2026.** Steam runs launch options inside its
own FHS/pressure-vessel sandbox via `/bin/sh -c`, whose `PATH` is only `/usr/bin:/bin`;
the Home Manager profile gamerun used to live in was invisible from inside that sandbox,
so every launch silently failed with `gamerun: command not found` (confirmed in
`~/.local/share/Steam/logs/console-linux.txt`) and everything downstream — PRIME offload,
gamemode, `game-perf.service`, scx_lavd, the 0xED perf profile, fan turbo — never fired
for a single Steam session. `usr/steam.nix`'s `extraPackages` is the fix; if gamerun ever
seems to have no effect again, check for `command not found` in that log first, before
assuming a downstream part of the chain is broken.

Steam launch options are `gamerun %command%` — **`%command%` is mandatory**: Steam only
treats the string as a wrapper if it's present; without it, the string is silently
appended as a game argument instead (no error). `gamerun` handles dGPU PRIME offload and,
by default, opts back into the full 16-CPU pool (`taskset -c 0-15`, punching through the
Zen5c-only desktop mask from `cores.nix` above — `GR_PIN=big/fast/<list>` narrows it
further for single-thread-bound sim games). Because it went untested for so long, riskier
DLSS/vendor-hiding env vars are opt-in rather than default-on (`GR_NVONLY`, `GR_DLSS`,
`GR_CACHE` — see `lib/gamerun.nix`'s header for what each covers and why). It then
`exec`s `gamemoderun`, whose start/stop hooks drive `game-perf.service` (scx_lavd + the
WMI 0xED perf profile on AC).

`gamerun` has **three** callers, not one — its env contract is load-bearing for all of
them, so read them before changing what it exports:

| Caller | Entry point | Note |
|---|---|---|
| Steam | launch options `gamerun %command%` | via `usr/steam.nix`'s FHS `extraPackages` — the path that was broken |
| `home/apps/minecraft.nix` | `mc-run` → `gamerun`, via Prism's `WrapperCommand` | adds MC-only OpenGL env first, so it can't leak into Steam |
| `home/apps/emu.nix` | `emu-run {rpcs3\|shadps4}` → `gamerun` | native Vulkan; the DLSS/Reflex/Proton vars are inert-but-harmless here |

The CPU power policy during gaming is **GPU-priority** (2026-07-18): `game-perf` sets
PPD to `balanced`, **not** `performance`, so the shared NVIDIA Dynamic Boost budget
(ACBT 80W) favors the dGPU instead of starving it — full rationale is in
`system/kernel/sched.nix`'s inline comments (CPU-bound titles opt back in with
`GR_CPUMAX=1 gamerun …`). Undervolting the CPU is **platform-locked** on this Gigabyte
board (see `Documentation/aerox16/undervolt.md`), so capping its power appetite is the
only lever; 100°C is by-design (Zen5 mobile Tjmax), not a fault. `system/arch/aerox16/wmi.nix`'s
`gigabyte-power-profile.service` must not write `fan_mode` while `game-perf.service` is
active — it used to unconditionally reset the turbo fan on every AC-plug/resume event,
silently killing it mid-session (fixed 10 Aug 2026). When touching this chain, update
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
**NextDNS**, the personal profile the router was already handing out over *plain* UDP.
Four traps live in that block:

- **`127.0.0.54` is not a free address — it is systemd-resolved's second listener**
  (the proxy stub; resolved holds `.53` and `.54` together). Binding it dies with
  `address already in use`, and pointing `DNS=` at it aims resolved at itself, which it
  silently drops — the symptom is `resolvectl status` showing no `DNS Servers` under
  Global while queries quietly fall back to per-link DHCP DNS. Don't use `5353` either
  (mDNS).
- **`services.resolved.settings.Resolve.Domains = [ "~." ]` is load-bearing.** Without
  it resolved prefers NetworkManager's per-link DHCP DNS — the ISP's server — and the
  whole DoH chain is bypassed. The cost is that captive portals (hotel/airport WiFi)
  work *by* DNS hijacking, so they cannot complete while it's set.
- **The settings merge is shallow.** `upstreamDefaults = true` puts upstream's TOML
  *under* ours via `jq add`, so any top-level key you define replaces upstream's whole
  table of that name. That is used deliberately here: `sources = { }` switches off the
  resolver-list download (a `raw.githubusercontent.com` fetch at boot — a prime blocking
  target in TR — that would loop against `Restart=always`). Know which way you're using
  it before you add a key.
- **`require_nolog` / `require_nofilter` must stay `false`** with NextDNS: it filters and
  logs by design, and leaving them true makes dnscrypt disqualify its only server.

dnscrypt takes **no raw DoH URLs** — servers are declared as DNS stamps. The stamp here
was generated against the spec, decoded back to verify, and the endpoint was proven with
a live RFC 8484 query before being wired in. Changing the profile means regenerating the
stamp; it cannot be hand-edited (length-prefixed base64url).

The predecessor of this block, `system/net/dns.nix`, was deleted in the same commit: it
had never been in any import list, so it had never been evaluated, and it carried three
fatal errors (a `services.resolved.dns` option that does not exist, `":53"` ports in
`fallbackDns`, and a corrupted `minisign_key`). **A Nix file that nothing imports is not
"pending", it is untested** — check `configuration.nix`/`home.nix` before trusting one.
The mechanical version of that check is `scripts/verify-context.sh`, and this file is the
reason it exists: `nix-instantiate --parse` accepts `services.resolved.dns = [ … ];`
without a word, because the bug is semantic, not syntactic. Only eval sees it — which is
also why the parse hook and the Stop hook are two gates, not one gate twice.

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
