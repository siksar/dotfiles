# Netflix — Widevine DRM'li Chrome app-mode sarmalayıcısı.
# Bağımlılık uyarısı: paket google-chrome'u closure'a çeker (Widevine CDM yalnız
# orada); Firefox/Zen ile 1080p üstü DRM akışı çalışmadığı için ayrı duruyor.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.netflix ];
}
