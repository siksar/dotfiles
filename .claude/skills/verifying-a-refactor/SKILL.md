---
name: verifying-a-refactor
description: Use when moving, renaming, or reordering files/modules in this flake and you need to prove the change altered nothing — compares drvPath before/after instead of building.
---

# Proving a move didn't change anything

Comparing `drvPath` before/after is cheaper than building and proves the whole build
graph:

```bash
git add -A   # MANDATORY — Nix only sees git-TRACKED files; an unstaged new path
             # fails with "file not found"
nix eval --raw .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath
nix eval --raw .#homeConfigurations.zixar.activationPackage.drvPath
```

Identical output = the move is provably safe. Different = diff the two `.drv` files and
find out *why* before proceeding; check `system-path` first, since an unchanged
`system-path` means the package set is intact and only generated files moved. Note that
**module import order is not a no-op**: list-type options (`services.udev.extraRules`
and friends) concatenate in evaluation order, so reordering imports legitimately changes
the closure even when nothing semantic changed.
