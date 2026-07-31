# Hyprland rice — mechanics that bite

Loaded only when working under `home/desktop/`. The always-loaded
summary and the cross-cutting rules (the `osConfig` toggle contract) live in the root
`CLAUDE.md`; the full design doc is `Documentation/desktop.md` — read it before touching
this directory.

## Layout

Five HM modules, all listed individually in `home.nix` and all gated on the same
`desktop.hyprland.enable` — the option itself is declared in `session.nix`.

| File | Owns |
|---|---|
| `session.nix` | WM (`extraLuaFiles` → `wm/`), hyprlock, hypridle, polkit agent, screenshot, `stylix.targets`, **the option declaration** |
| `theme/matugen.nix` | wallpaper dir, matugen config + templates, awww daemon, first-boot color seed, `bash.initExtra` |
| `theme/engine.nix` | **not a module** — a plain function returning `theme-apply` / `wallpaper-picker` / `theme-sequences-apply`. It exists because those scripts are needed by more than one module, and HM modules cannot see each other's `let` bindings. Import it: `import ./engine.nix { inherit pkgs lib config; }` |
| `bar/waybar.nix` | `programs.waybar`, the 16-theme launcher (`waybar-launch`/`waybar-theme`), `fan-status` |
| `launcher/rofi.nix` | `programs.rofi`, the rasi files, wallpaper grid |
| `notify/swaync.nix` | `services.swaync` |

Adding a package? Put it in the module that owns the feature, not in `session.nix`.
`home.packages` merges across modules — but note the **merge order follows the
`home.nix` import order**, so moving a package between modules changes the profile's
build order (harmless: same set, different `extra-dependencies`/`.manpath` ordering).

- `AQ_DRM_DEVICES` **must** stay in `environment.sessionVariables` (not in Hyprland
  config — aquamarine reads it before the config is parsed), and it points at the
  udev symlink `/dev/dri/hypr-igpu` because the value cannot contain `:` (aquamarine
  splits on it, so by-path PCI names break). This is the **only** thing keeping the
  dGPU node closed for D3cold now that GNOME's `mutter-device-ignore` udev rule is
  gone — don't remove it without a replacement.
- `withUWSM = true` is mandatory. The session desktop file is installed even without
  it, but then dies with "Unit not found" because the uwsm systemd units are absent.
- Rice services (waybar, swaync, awww) bind to `hyprland-session.target`, never
  `graphical-session.target` — the former only activates for this session, the
  latter is a generic systemd target that could later start these services in a
  context you didn't intend (a bare TTY session, a future second compositor).
- Color ownership is split three ways: Stylix is off for the rice components
  (`stylix.targets.{hyprland,waybar,rofi,swaync,cava}.enable = false`); matugen owns
  hyprland/swaync/cava/terminal (wallpaper-driven, runtime-written and deliberately
  *not* HM-managed, so the vesktop mutable-copy trick is not needed for them); and
  **waybar's 15 vendored themes + rofi both read the static `waybar-mono.css`**.
  Matugen still writes `~/.config/rofi/colors.rasi` — nothing reads it any more, it
  is kept as the one-line escape hatch back to dynamic rofi colors.
- Every matugen invocation must pass a source-color index or select one itself —
  matugen 4.x otherwise prompts interactively and dies with "not a terminal" when
  run from services/hooks, producing no color files at all.
- **Waybar's 16-theme system** (`bar/themes.nix`, `waybar-mono*.css`,
  `bar/omarchy-compat.nix`, `waybar-themes/<V>/`) runs themes straight from the
  Nix store via `waybar -c <dir>/config.jsonc -s <dir>/style.css` — it never touches
  HM's `~/.config/waybar/{config,style.css}` symlinks. Full design and the per-theme
  exceptions (V1/V1.5 lacked `@import` entirely, V3.Omegax merges two bars into one
  JSON array, V4.y collapses to just its "dock" variant) are in
  `Documentation/desktop.md`'s "Waybar çoklu tema sistemi" section — read it before
  touching a vendored theme or the palette.
- `waybar-mono-overrides.css` **must be appended after** each theme's own `style.css`
  content, never before — CSS is last-rule-wins at equal specificity, and the
  `!important` in the override only exists as a second line of defense, not a
  substitute for ordering.
- Any `@import` rewrite inside `bar/themes.nix`'s `mkTheme` must stay a relative
  → absolute path swap done via `substituteInPlace`, matching the reasoning already
  documented above for matugen's own templates: a relative import resolves against
  the store path at runtime, not the theme's source directory.
- Theme derivation names get non-ASCII characters stripped (`V3.Ω` → `V3.Omega` in
  both the vendored directory name and `themeNames`) — Nix store paths reject
  non-ASCII bytes.
- **rofi 2.0 cannot parse `@variable` inside `linear-gradient(...)`** — and it does not
  fail locally: the *entire* theme file is rejected and rofi silently falls back to its
  built-in Solarized **light** theme. This is why `launcher/themes.nix` bakes literal hexes
  in at build time via `@@name@@` placeholders instead of emitting rasi variables. The
  same `@variable` works fine everywhere outside a gradient (`mono-colors.rasi`, which
  `wallpaper-grid.rasi` imports, uses them). Verify any rasi change with
  `rofi -no-config -theme <file> -dump-theme` and check **stderr** — a clean stdout dump
  is not proof, the fallback dumps cleanly too.
- `rofi-mono-overrides.rasi` **must be appended after** the vendored upstream
  `rofi-themes/type-5/style-4.rasi`, never before — same last-rule-wins reasoning as
  `waybar-mono-overrides.css`. Merging is per-property, so the overrides only need to
  name the properties they change; upstream geometry survives.
- `programs.rofi.theme` must stay an absolute **path string**, never a derivation
  attrset — the HM module mistakes an attrset for a rasi tree ("Unhandled value type
  set"). Point it at `${cfgHome}/rofi/…` and install the store file via
  `xdg.configFile.<name>.source`.
- `systemd.user.services.waybar.Service.ExecStart = lib.mkForce "${waybar-launch}"`
  depends on HM's `programs.waybar` module still producing a unit named `waybar` with
  a `Service.ExecStart` key — if a future HM update restructures that module, this
  override can silently stop targeting the right thing. Verify after any HM bump.
