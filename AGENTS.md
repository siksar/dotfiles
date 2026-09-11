# Repository Guidelines

## Project Structure & Module Organization

This repository is a flake-based NixOS configuration for the `nixos` host and
`zixar` user. `configuration.nix` and `home.nix` are the system and Home
Manager entry points; `system/` contains NixOS modules, `home/` contains Home
Manager modules, and `usr/` contains system-wide application modules. Shared
data and helpers belong in `lib/` (themes, schemes, wallpapers, and scripts).
Hardware-specific AERO X16 code is under `system/arch/aerox16/`. Operational
scripts live in `scripts/`, while experiments and measurement records live in
`Documentation/`. Start file discovery with `MAINTAINERS` and the tree map in
`README.md`.

## Build, Test, and Development Commands

Run the system update with `nh os switch`. For a build-only
check, use:

```bash
nixos-rebuild build --flake /home/zixar/nixos-zixar#nixos
```

Activate a validated system with `sudo nixos-rebuild switch --flake /home/zixar/nixos-zixar#nixos`.
For Home Manager-only iteration, use `nh home switch -b hm-backup` (alias:
`hms`). There is no test suite: build, activation, and manual checks are the
project’s validation workflow. Hardware, power, thermal,
and WMI changes must also be measured using the relevant `Documentation/aerox16/`
plan.

Use `statix check .` and `deadnix .` for linting. Run `bash scripts/verify-context.sh`
for the repository’s combined evaluation and lint gate. Do not run `nixfmt`
tree-wide; it destroys intentional comment alignment.

## Coding Style & Naming Conventions

Use topic-based paths (`system/kernel/`, `system/net/`, `home/apps/`) and keep
system and Home Manager modules in their respective evaluation contexts. Match
existing Nix formatting and explanatory comments; comments and commit messages
are generally Turkish. Preserve basenames of data files consumed through
`${./...}` or `src = ./...`, because they can become derivation names.

## Testing Guidelines

There are no unit-test or coverage requirements. Validate Nix changes with the
build and `verify-context.sh`; validate runtime behavior after `switch` by
checking the affected service/session and, for hardware work, recording actual
sensor or power measurements.

## Commit & Pull Request Guidelines

Recent commits use concise Conventional Commit-style prefixes such as
`feat(power):`, `fix(wmi):`, `docs(cpu):`, and `chore(apps):`; retain that
pattern and describe the changed topic precisely. Pull requests should explain
the motivation, list validation commands and manual measurements, link related
issues when applicable, and include screenshots or logs for visible or
hardware-behavior changes. Keep unrelated formatting or generated-file changes
out of the review.

## Configuration and Safety

Review `CLAUDE.md` and any nested `CLAUDE.md` before editing their directories.
Keep the flake inputs pinned and treat `hardware-configuration.nix` as generated.
Changes to boot, ACPI, GPU, power, or display-manager code should be tested with
a recovery generation available before switching.
