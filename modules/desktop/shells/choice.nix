# Rice seçimi — home.nix'te tek kelimelik değişiklik + `nh home switch`
# (alias: hms) ile aktif kabuk değişir. Üç kabuk modülü de her zaman import
# edilir; içerikleri bu seçeneğe göre mkIf ile açılır/kapanır.
{ lib, ... }:

{
  options.rice.shell = lib.mkOption {
    type        = lib.types.enum [ "caelestia" "dms" "noctalia" ];
    default     = "caelestia";
    description = "Aktif masaüstü kabuğu (bar/launcher/kilit/OSD).";
  };
}
