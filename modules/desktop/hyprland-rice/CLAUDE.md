# Hyprland rice — mechanics that bite

Loaded only when working under `modules/desktop/hyprland-rice/`. The always-loaded
summary and the cross-cutting rules (the `osConfig` toggle contract) live in the root
`CLAUDE.md`; the full design doc is `docs/hyprland-rice.md` — read it before touching
this directory.

- `AQ_DRM_DEVICES` **must** stay in `environment.sessionVariables` (not in Hyprland
  config — aquamarine reads it before the config is parsed), and it points at the
  udev symlink `/dev/dri/hypr-igpu` because the value cannot contain `:` (aquamarine
  splits on it, so by-path PCI names break). This keeps the dGPU node closed —
  same D3cold rationale as GNOME's `mutter-device-ignore`.
- `withUWSM = true` is mandatory. The session desktop file is installed even without
  it, but then dies with "Unit not found" because the uwsm systemd units are absent.
- Rice services (waybar, swaync, awww) bind to `hyprland-session.target`, never
  `graphical-session.target` — the latter would start them inside GNOME too.
- Color ownership is split: matugen owns the rice components
  (`stylix.targets.{hyprland,waybar,rofi,swaync,cava}.enable = false`), Stylix keeps
  everything else. Matugen's outputs are runtime-written and deliberately *not*
  HM-managed, so the vesktop mutable-copy trick is not needed for them.
- Every matugen invocation must pass a source-color index or select one itself —
  matugen 4.x otherwise prompts interactively and dies with "not a terminal" when
  run from services/hooks, producing no color files at all.
