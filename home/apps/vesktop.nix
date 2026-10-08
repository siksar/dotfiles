{ lib, ... }:

{
  programs.vesktop = {
    enable = true;
    settings = {
      tray = true;
      minimizeToTray = true;
    };
    vencord.settings = {
      useQuickCss = false;
    };
  };

  # Vesktop settings'i runtime'da yazar → mutable-copy.
  home.activation.vesktopCleanBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f "$HOME/.config/vesktop/settings.json.hm-backup" \
              "$HOME/.config/vesktop/settings/settings.json.hm-backup"
  '';
  home.activation.vesktopMutableConfigs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for f in "$HOME/.config/vesktop/settings.json" \
             "$HOME/.config/vesktop/settings/settings.json"; do
      if [ -L "$f" ]; then
        run cp --remove-destination "$(readlink -f "$f")" "$f"
        run chmod u+w "$f"
      fi
    done
  '';
}
