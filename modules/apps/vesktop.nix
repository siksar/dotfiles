# Vesktop — Vencord gömülü Discord istemcisi
# Tema Stylix'ten otomatik gelir (stylix targets.vesktop: stylix.css'i
# üretir ve enabledThemes'e kendisi ekler) — burada tema AYARLAMA.
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

  # Vesktop settings.json'larını runtime'da kendisi de yazar → HM symlink'i
  # yerine mutable-copy (nixy deseni), bayat backup'lar checkLinkTargets'tan
  # önce silinir.
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
