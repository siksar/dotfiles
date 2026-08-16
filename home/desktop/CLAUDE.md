# Hyprland rice — mechanics that bite

Loaded only when working under `home/desktop/`. The always-loaded
summary and the cross-cutting rules (the `osConfig` toggle contract) live in the root
`CLAUDE.md`; the full design doc is `Documentation/desktop.md` — read it before touching
this directory.

## Layout

Two HM modules, both gated on `desktop.hyprland.enable` — the option itself is
declared in `session.nix`. (Replaced the old five-module waybar+rofi+swaync+matugen
rice on 9 Aug 2026 — see `Documentation/desktop.md` for what changed and why.)

| File | Owns |
|---|---|
| `session.nix` | WM (`extraLuaFiles` → `wm/`), the hyprpolkitagent user service, `gtk.iconTheme`, **the option declaration** |
| `caelestia/default.nix` | Everything else — Quickshell shell package + CLI, bar/launcher/notifications/lock/idle, runtime Material You theme engine, dGPU-safety env, mutable-copy trick for `shell.json` |

Adding a package? Put it in the module that owns the feature, not in `session.nix`.
`home.packages` merges across modules — but note the **merge order follows the
`home.nix` import order**, so moving a package between modules changes the profile's
build order (harmless: same set, different `extra-dependencies`/`.manpath` ordering).

- `AQ_DRM_DEVICES` **must** stay in `environment.sessionVariables` (not in Hyprland
  config — aquamarine reads it before the config is parsed), and it points at the
  udev symlink `/dev/dri/hypr-igpu` because the value cannot contain `:` (aquamarine
  splits on it, so by-path PCI names break). This protects the **compositor's** DRM fd
  only — it does NOT stop Caelestia's Qt/QML client from opening the NVIDIA node.
  That's what `programs.caelestia.systemd.environment`'s `__GLX_VENDOR_LIBRARY_NAME`/
  `__EGL_VENDOR_LIBRARY_FILENAMES` pins are for (`caelestia/default.nix`) — both layers
  are needed to keep the dGPU in D3cold.
- `withUWSM = true` is mandatory. The session desktop file is installed even without
  it, but then dies with "Unit not found" because the uwsm systemd units are absent.
- `programs.caelestia.systemd.target` **must** be `"hyprland-session.target"`, never
  the generic `graphical-session.target` — the former only activates for this session,
  the latter is a generic systemd target that could later start the shell in a context
  you didn't intend (a bare TTY session, a future second compositor).
- **Caelestia's HM module export is `homeManagerModules.default`.** Some third-party
  examples (including an older NixOS Wiki snippet) write `homeModules.default` — that
  attribute doesn't exist and produces an eval error, not a helpful one.
- **No binary cache.** `caelestia-shell`'s `flake.nix` has no `nixConfig` block, so
  quickshell (pinned to `git.outfoxxed.me` master, *not* nixpkgs's 0.3.0 — the QML API
  it needs isn't in a tagged release yet) and Qt6 build from source on every
  `flake update`. Keep the input pinned; update deliberately, not via a blind
  `nix flake update`.
- **The bar accepts exactly 8 hardcoded entry IDs** (`logo`, `workspaces`, `spacer`,
  `activeWindow`, `tray`, `clock`, `statusIcons`, `power`) — `bar.entries` in
  `plugin/src/Caelestia/Config/barconfig.hpp` / `modules/bar/Bar.qml`'s
  `DelegateChooser`. There is no `custom`/`exec` entry type, and the plugin system
  (`caelestia-dots/plugins`, `caelestia-dots/example-plugin`) is an empty repo with a
  `// Plugin support is not wired up yet` comment in the shell's own source — a bar
  module cannot be added without patching the QML. This is why the fan-mode indicator
  that used to live in waybar's `custom/fan` is gone; the `notify-send` toast
  `fan-mode-cycle.service` already sends (`system/arch/aerox16/wmi.nix`) is the whole
  UI now.
- **Custom color schemes are package-only, still.** `caelestia scheme set -n <name>`
  resolves only against `caelestia-cli`'s packaged `src/caelestia/data/schemes/`
  directory (`scheme.py get_scheme_names` — no user-level scheme dir exists upstream).
  The 7 schemes in `schemes/*.txt` are injected via a `postPatch` `overrideAttrs` on
  `caelestia-cli` (`caelestia/default.nix`) that copies them into that same tree before
  the Python wheel is built — mirrors upstream's own `default.nix`, which already
  mutates that directory in its `patchPhase`. Format: `key HEX` per line, one space,
  no `#`, no blank lines, 110 keys, fixed order (verified against
  `src/caelestia/data/schemes/everforest/medium/dark.txt`).
- **The 7 schemes are a byte-exact copy from the `rice/caelestia` branch, not a
  conversion from `lib/schemes/*.yaml`.** (`rice/caelestia` is not "abandoned" — it is a
  strict ancestor of `zixar`, 41 commits back, holding Caelestia in the pre-reorg layout.
  Do not confuse it with `claude-md-audit`, which holds the pre-Caelestia waybar rice;
  the branch names mislead in both directions — see the branch table in the root
  `CLAUDE.md`.) The base16 conversion the other
  direction (Caelestia → base16, done when that branch was archived) is lossy — 16 of
  110 keys survive, the other 94 (M3 container roles, the 12-step surface ramp, 8 of
  16 ANSI colours, KDE/success roles) are hand-authored and not recoverable by
  formula. If you need an 8th scheme, author it directly in the 110-key format or pull
  another one from `rice/caelestia:modules/desktop/caelestia/schemes/` — don't try to
  expand a base16 yaml back out.
- **User theme templates use a different placeholder syntax than the packaged
  ones.** `~/.config/caelestia/templates/*` (declared via `xdg.configFile`, discovered
  by directory convention — there's no config key listing them) use
  `{{ role.format }}` (`gen_replace_dynamic`, e.g. `{{ primary.hex }}`); the CLI's own
  bundled templates use `{{ $name }}` (`gen_replace`) — don't copy a packaged template
  as a starting point, the placeholders won't resolve. Output always lands at
  `~/.local/state/caelestia/theme/<same-basename>`, path not configurable.
- **`cli.settings.theme.postHook` fails silently** — the subprocess runs with
  `stderr=DEVNULL`. If the keyboard RGB sync (`templates/kbd-color` → `themePostHook`
  in `caelestia/default.nix`) stops updating after a scheme change, check
  `~/.local/state/caelestia/theme/kbd-color` exists and run the `kbd-rgb set` line by
  hand before assuming the theme engine itself is broken.
- **The mutable-copy trick applies to `~/.config/caelestia/shell.json`** — same
  pattern as `home/apps/vesktop.nix`'s vesktop settings: `checkLinkTargets` runs
  *before* `linkGeneration` and errors on a stale `.hm-backup`, so the cleanup
  activation script must be `entryBefore [ "checkLinkTargets" ]` and the
  symlink→writable-copy swap must be `entryAfter [ "linkGeneration" ]`. Needed because
  the shell's nexus GUI writes `shell.json` at runtime.
- **`caelestia scheme set -n dynamic`** is the closest equivalent to the old
  wallpaper→matugen chain — it derives a Material You palette from the current
  wallpaper. There's no visual grid picker like the old rofi `wallpaper-grid.rasi`;
  the nearest interactive equivalent is opening the launcher (`SUPER+SPACE`) and
  typing the `>wallpaper ` action prefix.
- **Deploy lock-screen changes via `nh os boot` + reboot, not `switch`** — `switch`
  patches a live session while Hyprland still holds the old Lua config in memory, an
  unrepresentative and riskier test than a real boot. `boot` leaves the current
  session untouched and only takes effect on reboot; if the new generation fails to
  produce a working session at all, the bootloader menu can still select the previous
  one — a stronger safety net than a live TTY, since it doesn't depend on the new
  session partially working.
- **Still test the lock with a second TTY held open before trusting it, right after
  the reboot.** Caelestia's own `WlSessionLock` + `PamContext` replaced hyprlock and
  its system-side `security.pam.services.hyprlock` entry (removed 9 Aug 2026) — a
  broken PAM path here locks you out with no fallback greeter, and `boot` doesn't
  exempt you from this: it just means recovery-of-last-resort is a bootloader
  rollback instead of a live-session fix. Verify with `caelestia shell lock lock`
  from a second TTY (`Ctrl+Alt+F2`); if PAM is broken and you get stuck,
  `systemctl --user stop caelestia` from that TTY drops the lock (the
  ext-session-lock protocol requires the compositor to unlock if the locking client
  dies).
- **Three separate writers already touch power-profiles-daemon**
  (`power-display.service`, `game-perf.service`, the ACAD udev rule) — Caelestia's bar
  has a `power` entry that can also write PPD via D-Bus if enabled. It's disabled
  (`bar.entries` in `caelestia/default.nix`) specifically to keep `power-display.service`
  the sole authority; don't re-enable it without updating that ownership story.
  **A fourth writer exists and is *not* disabled**: the Serpantinum session's battery
  popup ships a clickable profile switcher that shells out to `powerprofilesctl set`
  (upstream `scripts/quickshell/battery/BatteryPopup.qml`). It escapes the rule above
  because Serpantinum is quarantined — you only reach that button by explicitly picking
  that session in ly and then clicking it — and `power-display.service` re-asserts on the
  next AC/BAT transition, so the divergence is bounded rather than permanent. Recorded
  here (15 Aug 2026 swarm audit) so the ownership story stays complete; if it ever needs
  to go, `postPatch` in `home/desktop/serpantinum/default.nix` is where to strip it.

### Proving a move didn't change anything

Moving/renaming/reordering modules? The `drvPath` before/after procedure is the
`verifying-a-refactor` skill (`.claude/skills/verifying-a-refactor/`). It does not
apply to this rice's Caelestia cutover itself (that was an add+delete, not a move —
`drvPath` was expected to change).

## Serpantinum — karantinalı ikinci oturum

`serpantinum/default.nix` pins github.com/ilyamiro/serpantinum (a Quickshell/Hyprland
rice, the author's personal dotfiles — no `flake.nix`, on the author's own machine runs
out of store via `mkOutOfStoreSymlink "/etc/nixos/…"` + `rsync`) to commit
`5d4451f7ab55ddaced9ba350b6dba5dd2932aeb1`, applies a handful of patches (swww→awww
rename, missing/broken upstream autostart lines, missing keybinds for fan-mode-cycle and
keyboard-RGB brightness), and installs it as a **third, quarantined** ly session entry.
The existing Caelestia session (`defaultSession` still `hyprland-uwsm`) is not touched by
a single line.

### The quarantine boundary

Two Quickshell shells in the same tree both want the *same* Wayland surfaces —
layer-shell (bar/panels), `ext-session-lock-v1` (lock screen), the notification
D-Bus name. Running both unconditionally would fight over all three. The boundary that
prevents it: **the HM side of serpantinum never writes a global option** — anything that
would leak into the Caelestia session regardless of which one is actually running. Only
session-scoped files (`~/.config/hypr/serpantinum.conf`, `~/.config/hypr/scripts`,
`~/.config/matugen/*`) and the session wrapper script's own environment
(`serpantinum-session` — PATH, EGL env, first-run matugen) are quarantined to the
serpantinum session itself; everything else that upstream's config touched was either
patched out or never added.

| Upstream option | Why it was dropped/patched, not carried over |
|---|---|
| `services.hypridle.enable` | Global HM option — would start a second idle daemon fighting Caelestia's own `ext-idle-notify-v1` manager (5 min lock / 8 min DPMS) regardless of which session is active. |
| `services.easyeffects.enable` | Global HM option — would double-start the EasyEffects instance `home/apps/audio.nix` already owns for the Caelestia session. |
| `gtk.gtk3.extraCss` / `gtk.gtk4.extraCss` (matugen-generated) | GTK theming is global HM state — writing matugen's CSS here would silently override Stylix's GTK target (`lib/theme.nix`) the moment either session activates, not just serpantinum's. |
| `dconf.settings` cursor-theme | Global dconf state — would repoint the cursor theme system-wide, including inside the Caelestia session, not just while serpantinum is the active WM. |
| `home.sessionVariables` | Global env for the whole HM profile (both sessions inherit it via fork/exec) — serpantinum's EGL/vendor-library pins instead live in the session wrapper script's own environment, scoped to processes it launches. |

If a future edit to `serpantinum/default.nix` touches any of the five rows above, it has
broken the quarantine — revert it and move the setting into the session wrapper or a
session-scoped config file instead.

### What was and wasn't adapted

Adapted from upstream: `hyprpolkitagent` autostart (upstream's own polkit line was
broken/missing), the fan-mode-cycle keybind, the keyboard-RGB brightness keybind, the
EGL/vendor-library pins (same dGPU-safety concern as Caelestia's — see `AQ_DRM_DEVICES`
note above), and the swww→awww rename (upstream's wallpaper daemon call target changed
name upstream, unrelated to this repo).

Deliberately **not** adapted: the idle cost. Upstream's TopBar runs ~8 `inotifywait`
watchers at idle, 5 fetch↔wait ping-pongs (`battery_wait.sh`'s `timeout 10`), a
`dbus-monitor` respawn every 2s while no MPRIS player is active, and a once-a-second
clock repaint — none of it was rewritten to be idle-quiet. This is a conscious user
decision (not an oversight): the cost is real but paid only while this session is
selected, and the repo's "4.28W idle" rule binds the files both sessions share
(`system/kernel/{sched,power,cores}.nix`), not a session nobody is required to pick. See
`Documentation/desktop.md`'s "Serpantinum deneme oturumu" section for the full
before/after and the v2.0 re-evaluation criteria.

### Three traps found in a live session, 15 Aug 2026

- **The app menu (`SUPER+D`) does not read `XDG_DATA_DIRS`.**
  `applauncher/app_fetcher.py` hardcodes its scan list, and that list contains
  `~/.nix-profile/share/applications` (this path does exist on this system —
  `~/.nix-profile` symlinks to `~/.local/state/nix/profiles/profile`, populated by
  the *standalone* HM entry point this repo also drives via `hms`, root `CLAUDE.md`'s
  "Commands") and `/run/current-system/sw/share/applications`, but **not**
  `/etc/profiles/per-user/<user>/share/applications` — where every `home.packages`
  app from the *embedded* HM path lands on this system. 34 entries showed, 16 were
  invisible (measured by running the script patched vs unpatched: 34 → 50). Because
  the system packages *did* show, this reads as "one app is missing" rather than "a
  whole profile is". `postPatch` appends the one literal path. **If an HM app
  doesn't appear in the menu, check this list before anything else.** Note: the
  34 → 50 count is not a fixed fact — `~/.local/share/applications` accumulates
  desktop files as apps self-register there at runtime, so it drifts; a
  re-measurement on 15 Aug already returned 48 → 50 on the same patch.
- **The browser bind must call `zen-beta`, not `zen`.** That is the real binary name
  from `zen-browser-flake` (its desktop file is `zen-beta.desktop`, `Exec=zen-beta`).
  `bind = … exec, zen` fails silently — Hyprland hands the exec to `/bin/sh` and the
  `command not found` only reaches the session log. Note "beta" is Zen's *release*
  channel name (nightly is `twilight`), not an instability marker; the flake offers
  no other stable variant.
- **`SUPER+W`'s picker scans one directory, `-maxdepth 1`, and it must not be
  `~/Pictures/Wallpapers`.** That path is Caelestia's curated 16 and the two sessions
  should not share a list. The source is set by the single env var `WALLPAPER_DIR`
  in the session wrapper — read by *both* `qs_manager.sh` (`SRC_DIR`) and
  `WallpaperPicker.qml` (`Quickshell.env`), so there is no second place to configure
  it. It points at upstream's own wallpaper repo, pinned via
  `lib/serpantinum-wallpapers.nix` (319 images, ~429 MB store). The `-maxdepth 1` is
  why dropping a collection into a *subdirectory* of the wallpaper dir can never
  work — that was the actual cause of "most wallpapers are still missing".

Lock screen: serpantinum's `Lock.qml` never sets quickshell `PamContext`'s `config`
field, so it falls back to the quickshell default `"login"` (qml.hpp:130) — `/etc/pam.d/login`
already exists on this system, so no extra `security.pam.services` entry was needed for
this session (unlike Caelestia, whose removed `hyprlock` PAM entry is documented in
`system/desktop/CLAUDE.md`).

### /swarm denetiminde bulunan üç sessiz hata (15 Ağu 2026)

- **`exec-once = hyprpolkitagent` resolved to nothing.** `pkgs.hyprpolkitagent` ships
  no `bin/`, only `libexec/hyprpolkitagent` — the bare command name in `exec-once`
  never resolved, and every polkit prompt (including 1Password's system auth) was
  silently rejected. Fixed by pointing `exec-once` at the absolute
  `${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent` path. Deliberately **not** wired
  to Caelestia's own `hyprpolkitagent` systemd user service (`session.nix`) —
  `systemctl --user start`-ing it would make serpantinum depend on Caelestia's HM
  module, the same "two sessions don't lean on each other's files" boundary
  `lib/serpantinum-wallpapers.nix` enforces for the wallpaper repo.
- **Quickshell's color JSON lived in `/tmp`, and `/tmp` gets swept.** matugen's
  Quickshell output was `/tmp/qs_colors.json`; the default
  `/etc/tmpfiles.d/tmp.conf` rule (`q /tmp 1777 root root 10d`) plus the always-on
  `systemd-tmpfiles-clean.timer` deletes anything untouched for 10 days, and the
  first-launch guard (`system/desktop/serpantinum.nix`) only checks whether
  `~/.config/hypr/colors.conf` exists before skipping matugen — so once 10 days
  passed without picking a new wallpaper, the shell started with no palette. Output
  moved to `~/.local/state/serpantinum/qs_colors.json`. Deliberately **not** fixed
  by loosening the guard to "also run if the JSON is missing" — `matugen image
  <default>` would overwrite whatever palette the user last picked.
- **All four Print binds were dead — an all-or-nothing dependency gate.**
  `screenshot.sh`'s `REQUIRED_CMDS` check refuses to run at all unless every one of
  `gpu-screen-recorder`, `grim`, `satty`, `wl-copy`, `pactl`, `quickshell`,
  `zbarimg`, `python3` resolves; none of `grim`, `satty`, `pactl`, `zbarimg` were in
  `runtimeDeps` (`system/desktop/serpantinum.nix`), so screenshot/record/QR-scan
  all failed together. Fixed by adding `grim`, `satty`, `zbar` (provides
  `zbarimg`), `gpu-screen-recorder`, `pulseaudio` (for `pactl` — pipewire-pulse
  doesn't ship it) to `runtimeDeps`; ~24 MiB marginal closure, measured. `pactl` is
  also a dependency of six other scripts, not just this one (`volume_listener.sh`'s
  `exec-once`, plus the bluetooth/music/volume panels) — so the audio and bluetooth
  panels were silently broken too, not only Print.
