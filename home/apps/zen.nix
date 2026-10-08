{ inputs, ... }:

{
  imports = [ inputs.zen-browser.homeModules.default ];

  programs.zen-browser = {
    enable = true;
    policies = {
      DisableAppUpdate = true;
      DisableTelemetry = true;
    };
  };

  # Profil olmadan zen hedefi no-op + uyarı basıyor.
  stylix.targets.zen-browser.enable = false;

  # Tema için: mevcut profili HM'ye adıyla bağla (profileNames = [ "r1lawe90.Default Profile" ]);
  # zen profiles.ini'yi runtime'da yazar → mutable-copy gerekir.
}
