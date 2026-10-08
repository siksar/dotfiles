# fwupd + LVFS. Gigabyte BIOS LVFS'te yok (Q-Flash). Kurulum elle: fwupdmgr get-updates / update.
{ ... }:

{
  services.fwupd.enable = true;
}
