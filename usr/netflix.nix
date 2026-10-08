# Netflix — Widevine için Chrome app-mode (Zen'de 1080p+ DRM çalışmıyor).
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.netflix ];
}
