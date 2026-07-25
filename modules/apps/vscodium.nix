# VSCodium — VS Code'un telemetrisiz/markasız derlemesi (HM)
# Tema + font Stylix'ten otomatik gelir (stylix.targets.vscodium:
# profiles.default'a Stylix tema eklentisi + font userSettings'i gömer) —
# burada renk/font AYARLAMA.
#
# Ayar felsefesi:
#   - Kalıcı ayar → aşağıdaki userSettings'e yaz (rebuild'e dayanır).
#   - GUI'den yapılan ayar → çalışır (mutable-copy sayesinde) ama bir sonraki
#     hms/rebuild'de Stylix+userSettings tabanına sıfırlanır; kalıcı olacaksa
#     buraya taşı.
#   - Eklentiler: tek profil olduğundan mutableExtensionsDir=true (varsayılan) →
#     GUI'den Open VSX ile kurulum serbest, rebuild silmez.
{ lib, ... }:

{
  programs.vscodium = {
    enable = true;
    profiles.default = {
      # Paket nix'ten gelir; uygulama içi güncelleme kontrolü anlamsız
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
    };
  };

  # Stylix userSettings gömdüğü için settings.json HM symlink'i olur; VSCodium
  # GUI ayar editörü de bu dosyaya yazar → symlink yerine mutable-copy
  # (vesktop.nix deseni), bayat backup checkLinkTargets'tan önce silinir.
  home.activation.vscodiumCleanBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    run rm -f "$HOME/.config/VSCodium/User/settings.json.hm-backup"
  '';
  home.activation.vscodiumMutableConfigs = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    f="$HOME/.config/VSCodium/User/settings.json"
    if [ -L "$f" ]; then
      run cp --remove-destination "$(readlink -f "$f")" "$f"
      run chmod u+w "$f"
    fi
  '';
}
