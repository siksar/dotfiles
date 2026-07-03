# Firefox — Caelestia tema geçişini Pywalfox ile takip eder
# Akış: caelestia şema geçişi → user template'ten ~/.cache/wal/colors.json
# render edilir → postHook `pywalfox update` → eklenti tarayıcıyı canlı boyar.
{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    # Pywalfox eklentisini deklaratif kur (native host manifest'i HM tarafında:
    # modules/desktop/caelestia/default.nix — paket lib/mozilla dizini sunmadığı
    # için nativeMessagingHosts.packages kullanılamıyor)
    policies.ExtensionSettings."pywalfox@frewacom.org" = {
      installation_mode = "force_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/pywalfox/latest.xpi";
    };
  };
}
