# Sway rice — mechanics that bite

Loaded only when working under `modules/desktop/sway-rice/`. The always-loaded summary
and the cross-cutting rules (the `osConfig` toggle contract) live in the root
`CLAUDE.md`; the full design doc, the deviations from upstream vyrx-dev/dotfiles, and
the complete keybind table are in `docs/sway-rice.md` — read it before touching this
directory.

- `keybinds.nix` is the single source for the sway `keybindings` attrset AND the Mod+G
  cheatsheet data — never add a bind directly in `hm.nix`'s `extraConfig`.
- `WLR_DRM_DEVICES` goes in `programs.sway.extraSessionCommands` (not
  `environment.sessionVariables`) — same D3cold rationale as the Hyprland rice's
  `AQ_DRM_DEVICES`, but scoped so it never leaks into GNOME/Hyprland.
- **`xdg.portal.*` options are GLOBAL, not scoped by `mkIf cfg.enable`.** Setting
  `xdg.portal.wlr.enable = true` inside this module's `config` block does NOT confine
  it to the Sway session — the `xdg-desktop-portal-wlr.service` user unit it installs is
  gated only by `ConditionEnvironment=WAYLAND_DISPLAY`, so it starts in GNOME/Hyprland
  too. This actually happened (27 Tem 2026): the leaked wlr portal caused an epoll
  busy-loop in `xdg-desktop-portal-hyprland` (2 çekirdek sürekli boost) — see
  `docs/xdp-hyprland-busyloop.md` for the full investigation. Same lesson as the
  `WLR_DRM_DEVICES` item above, one layer up the stack. Screen sharing via the portal is
  now deliberately disabled in this rice as a result (`docs/sway-rice.md` has the
  reopen procedure and why the lost functionality was likely already broken anyway).
- `stylix.targets.noctalia` fires unconditionally the moment `programs.noctalia` exists
  (`options.programs ? noctalia`) and force-sets `theme.source = "custom"` — it **must**
  be disabled (alongside `sway`/`fuzzel`/`cava`) or the build fails with a conflicting
  definition against `noctalia.nix`'s `theme.source = "wallpaper"`.
- noctalia's own systemd user service binds to `config.wayland.systemd.target`
  (`graphical-session.target` by default, shared with GNOME) — `hm.nix` overrides it to
  `sway-session.target` with `lib.mkForce`, same pattern as the Hyprland rice's swaync
  override. HM's `wayland.windowManager.sway` module creates `sway-session.target` itself
  when `systemd.enable = true`; don't touch the shared `wayland.systemd.target` option
  globally — that would clash with the Hyprland rice's own service overrides.
- `checkConfig = false` is deliberate: the generated config `include`s
  `~/.config/sway/colors`, which does not exist at build time, so `sway --validate`
  would fail.
- **`noctalia config validate` does NOT catch misspelled setting names.** Unknown keys
  are WARNINGS and it still exits 0 (`✓ Config is valid (2 warning(s))`), so the HM
  module's build-time validation passes and the mistake only surfaces at runtime in
  the journal. It catches TOML syntax and bad *values*, not bad *keys*. Verify any new
  key against `noctalia config export full` (prints the complete merged schema) before
  trusting a green build — that command is the authority, not the docs.
- Template tokens are `{{colors.<role>.default.hex_stripped}}` — **no spaces inside the
  braces**, and `hex_stripped` carries no leading `#` (write it yourself). There is no
  `.hex` field; using it fails the whole render with "1 template error(s); output not
  written", which is silent apart from a journal WARN — the stale/seeded output file
  stays in place and everything *looks* fine. Valid roles are the ones noctalia's own
  builtin templates use (`<noctalia>/share/noctalia/assets/templates/`); `surface_container`,
  `surface_variant`, `outline_variant`, `error_container`, `on_error_container` are NOT
  among them. Copy from the builtin template for the app rather than inventing roles.
- **`theme.templates.enable_builtin_templates` MUST stay `false`.** It defaults to
  `true`, and noctalia's builtin template set covers apps Stylix/HM already own —
  ghostty, gtk3, gtk4, qt, btop, fuzzel, helix, starship, cava, foot, kitty,
  alacritty, emacs. Their `apply.sh` hooks edit the live dotfiles: ghostty's runs
  `sed -i -E 's/^theme\s*=.*/theme = noctalia/' ~/.config/ghostty/config`, and `sed -i`
  **replaces a symlink with a regular file**. That destroys HM's link; every later
  activation then finds a foreign file in the way, backs it up to `*.hm-backup`, and
  the *second* activation dies with "Existing file `…hm-backup` would be clobbered",
  taking down `home-manager-zixar.service` — which fails `nixos-rebuild switch/test`
  and `hms` alike. The Stylix ownership boundary is only real with this flag off.
  Cleanup after an incident: delete the stale `*.hm-backup` files AND the clobbered
  real file so HM can restore its symlink.
- Do not enable noctalia's builtin `sway` template either: its `apply.sh` appends an
  `include` line to `~/.config/sway/config`, which is HM's read-only store symlink. Our
  user template writes to `~/.config/sway/colors` (already included by `hm.nix`) instead.
- Never define a `mode "…"` block in `extraConfig`. HM's sway module already emits a
  default `resize` mode from `config.modes` (steps written `10 px`, with a space); a
  second block in `extraConfig` does not replace it, it overwrites binding-by-binding
  and sway greets every login with ten `Overwriting binding 'h' … from
  \`resize shrink width 10 px\`` warnings behind a red swaynag bar. Put modes in
  `swayBaseConfig.modes` instead. The same additive-not-replacing behaviour applies to
  anything HM's module generates on its own.
- Any `fuzzel --dmenu` list whose lines are wider than 30 characters MUST pass an
  explicit `--width`: fuzzel's default is 30 *characters*, so wider columns are simply
  cut off with no error. This silently hid every description in the Mod+G cheatsheet
  (`column -t` pads the key column to 32, so only keys were visible).
