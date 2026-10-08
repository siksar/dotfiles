{ ... }:

{
  services.geoclue2 = {
    enable = true;
    # Demo agent kapalı; bir tüketici eklenirse geri aç + appConfig.<servis> = { isAllowed = true; isSystem = false; }.
    enableDemoAgent = false;
  };
}
