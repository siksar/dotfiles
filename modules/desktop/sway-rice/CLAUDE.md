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
