{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.cosmic;
in
{
  options.desktop.cosmic.enable = lib.mkEnableOption
    "COSMIC masaustu — VARSAYILAN oturum (defaultSession configuration.nix.te)";

  config = lib.mkIf cfg.enable {
    # Oturumu upstream modül kurar; greeter'ı açmaz (login.nix).
    services.desktopManager.cosmic.enable = true;

    # DRM guard: compositor iGPU'da kalsın. Sözdizimi: virgül + vendor:device (diğer oturumlardan farklı).
    # 0x1002:0x1114 = iGPU (65:00.0), 0x10de:0x2d19 = dGPU (64:00.0). HDMI dGPU'da → external-display.nix
    # dGPU'yu ekler. Sıra anlamlı (iGPU önce). DÜZ ATAMA: mux.nix mkForce ile ezer.
    environment.sessionVariables.COSMIC_DRM_ALLOW_DEVICES =
      if config.desktop.externalDisplay.enable then
        "0x1002:0x1114,0x10de:0x2d19"
      else
        "0x1002:0x1114";

    # Upstream'in mkDefault true açtıkları; tüketici yok.
    services.avahi.enable = false;

    services.orca.enable = false;

    # system76-scheduler: her oturumda koşan daemon (+220 MB execsnoop); CFS ayarları BORE'de etkisiz.
    services.system76-scheduler.enable = lib.mkForce false;

    # COSMIC çıkışında graphical-session.target inmiyor (portallar Requisite= ile tutuyor) →
    # sonraki GNOME girişi "already running" ile çöküyordu. PartOf oneshot ExecStop'ta indirir; --no-block ŞART.
    systemd.user.services.cosmic-session-cleanup = {
      description = "COSMIC çıkışında graphical-session.target'ı durdur";
      partOf = [ "cosmic-session.target" ];
      after = [ "cosmic-session.target" ];
      wantedBy = [ "cosmic-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${pkgs.systemd}/bin/systemctl --user --no-block stop graphical-session.target";
      };
    };

    # TEMA YÖNETİLMİYOR: ~/.config/cosmic altına Nix'ten HİÇBİR ŞEY yazma (store symlink'i ayar
    # GUI'sini sessizce bozar). Sistem varsayılanı gerekirse yalnız /share/cosmic/<ad>/v<N>/<key>.

    # Copilot tuşu = Super+Shift+F23. cosmic-comp kısayolu LEVEL 1 sembolüyle eşler → anahtar "F23"
    # (XF86Assistant sessizce çalışmaz); modifier listesi tam eşit olmalı. GUI'den özel kısayol eklemek
    # ya da ~/.local/share/cosmic/<id>/v1 dizini bu tanımı gölgeler.
    environment.systemPackages = [
      (pkgs.writeTextFile {
        name = "cosmic-custom-shortcuts";
        destination = "/share/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom";
        text = ''
          {
              (modifiers: [Super, Shift], key: "F23"): Spawn("github-copilot"),
          }
        '';
      })
    ];
  };
}
