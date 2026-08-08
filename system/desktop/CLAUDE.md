# system/desktop — session, login, theme

Loaded only when working under `system/desktop/`. The cross-cutting rules (the
`desktop.hyprland.enable` toggle contract, Stylix as the single source of truth for
colors) live in the root `CLAUDE.md`; the rice's HM-side gotchas are in
`home/desktop/CLAUDE.md`; the full design doc is `Documentation/desktop.md`.

## Display manager: ly

The **display manager is ly** (`login.nix`), a TUI greeter on the TTY.
ly 1.4.1 takes 32-bit `0xSSRRGGBB` truecolor, so it's themed by feeding
`config.lib.stylix.colors` (kanagawa-dragon) directly into
`services.displayManager.ly.settings` (Stylix has no ly target).
`services.displayManager.defaultSession = "hyprland-uwsm"` (`configuration.nix`)
picks the working session entry: the `hyprland` package also installs a plain
"Hyprland" desktop file that does **not** work here (no uwsm systemd units without
`withUWSM = true`), and ly otherwise lists both.
