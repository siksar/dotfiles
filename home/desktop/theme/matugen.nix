# Matugen tema motoru — duvar kağıdı→renk zincirinin HM katmanı.
#
# Zincir: SUPER+T → wallpaper-picker → theme-apply → matugen → şablonlar →
# waybar/rofi/swaync/cava/hyprlock/terminal/klavye. Şablonlar bu dizinde
# (theme/*), motor scriptleri engine.nix'te.
#
# UYARI: matugen ÇAĞRISI HER ZAMAN --source-color-index İSTER (4.x). Yoksa
# aday rengi etkileşimli sorar, TTY'siz bağlamda "not a terminal" ile ölür ve
# HİÇ renk dosyası üretmez → waybar colors.css bulamayıp start-limit-hit'e düşer.
{ config, lib, pkgs, ... }:

let
  cfg = config.desktop.hyprland;
  cfgHome = config.xdg.configHome;
  engine = import ./engine.nix { inherit pkgs lib config; };
  inherit (engine) theme-apply wallpaper-picker theme-sequences-apply
                   defaultWallpaper matugenArgs;
in
{
  config = lib.mkIf cfg.enable {
    # Tema duvar kağıtları (recursive: kullanıcı dizine kendi dosyasını da
    # atabilir). SUPER+T'nin wallpaper-picker'ı ve --random burayı okur.
    home.file."Pictures/Wallpapers" = {
      source = ../../../lib/wallpapers;
      recursive = true;
    };

    home.packages = [
      pkgs.matugen # 4.0.0 — Material You (HCT) renk üretimi
      pkgs.awww # 0.12.1 — animasyonlu duvar kağıdı daemon'u (eski adı swww)
      pkgs.cava # 0.10.7 — ses görselleştirici (autostart YOK: idle bütçesi)
      pkgs.libnotify
      pkgs.playerctl # bazı waybar temalarının custom/media modülü
      theme-apply
      wallpaper-picker
      theme-sequences-apply
    ];

    # Yeni terminaller tema paletini bash başlangıcında alır (HYPRLAND_INSTANCE_
    # SIGNATURE guard'ı: yalnız Hyprland oturumunda, TTY/başka bağlamda hiç
    # çalışmasın). mkBefore ŞART — shell.nix'in fastfetch'i bu satırdan SONRA
    # koşmalı ki logo/renk halkaları tema paletiyle çizilsin.
    programs.bash.initExtra = lib.mkBefore ''
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        ${theme-sequences-apply}/bin/theme-sequences-apply
      fi
    '';

    xdg.configFile = {
      "matugen/config.toml".text = ''
        # HM üretir — elle düzenleme home.nix tarafında yapılır.
        # Duvar kağıdını matugen DEĞİL theme-apply (swww) basar; matugen
        # yalnız renk dosyalarını yazar, post_hook'lar bileşenleri tazeler.
        [config]

        [templates.hypr]
        input_path = '${cfgHome}/matugen/templates/hypr-colors.lua'
        output_path = '${cfgHome}/hypr/colors.lua'
        post_hook = 'hyprctl reload >/dev/null 2>&1 || true'

        [templates.waybar]
        input_path = '${cfgHome}/matugen/templates/waybar-colors.css'
        output_path = '${cfgHome}/waybar/colors.css'
        post_hook = 'systemctl --user try-restart waybar.service || true'

        [templates.rofi]
        input_path = '${cfgHome}/matugen/templates/rofi-colors.rasi'
        output_path = '${cfgHome}/rofi/colors.rasi'
        # hook yok — rofi her açılışta dosyayı taze okur

        [templates.swaync]
        input_path = '${cfgHome}/matugen/templates/swaync-colors.css'
        output_path = '${cfgHome}/swaync/colors.css'
        post_hook = 'swaync-client --reload-css >/dev/null 2>&1 || true'

        [templates.cava]
        input_path = '${cfgHome}/matugen/templates/cava-config'
        output_path = '${cfgHome}/cava/config'
        post_hook = 'pkill -USR2 -x cava || true'

        # Klavye aydınlatması — duvar kağıdının baskın rengine döner.
        # Olay-güdümlü: yalnız tema değişince tek bir yazma olur, idle'da
        # hiçbir şey dönmez (4.28W bütçesi). Animasyon çalışıyorsa döngü
        # durumu 0.5 sn'de bir tazelediği için renk canlı geçer.
        [templates.keyboard]
        input_path = '${cfgHome}/matugen/templates/keyboard-color'
        output_path = '${cfgHome}/kbd-rgb/color'
        post_hook = 'kbd-rgb set "$(cat ${cfgHome}/kbd-rgb/color)" >/dev/null 2>&1 || true'

        [templates.terminal]
        input_path = '${cfgHome}/matugen/templates/terminal-sequences'
        output_path = '${cfgHome}/theme-switcher/sequences'
        post_hook = '${theme-sequences-apply}/bin/theme-sequences-apply --all || true'

        # hyprlock.conf `source` ile bunu en başta okur (hyprlang $değişken).
        # hook yok — hyprlock her açılışta dosyayı taze okur.
        [templates.hyprlock]
        input_path = '${cfgHome}/matugen/templates/hyprlock-colors.conf'
        output_path = '${cfgHome}/hypr/hyprlock-colors.conf'
      '';

      "matugen/templates/hypr-colors.lua".source = ./hypr-colors.lua;
      "matugen/templates/waybar-colors.css".source = ./waybar-colors.css;
      "matugen/templates/rofi-colors.rasi".source = ./rofi-colors.rasi;
      "matugen/templates/swaync-colors.css".source = ./swaync-colors.css;
      "matugen/templates/cava-config".source = ./cava-config;
      "matugen/templates/terminal-sequences".source = ./terminal-sequences;
      "matugen/templates/keyboard-color".source = ./keyboard-color;
      "matugen/templates/hyprlock-colors.conf".source = ./hyprlock-colors.conf;
    };

    #### awww (eski adı swww) — duvar kağıdı daemon'u (HM'de hazır modülü yok) ####
    systemd.user.services.awww = {
      Unit = {
        Description = "awww wallpaper daemon (Hyprland oturumu)";
        PartOf = [ "hyprland-session.target" ];
        After = [ "hyprland-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        ExecStart = "${pkgs.awww}/bin/awww-daemon";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "hyprland-session.target" ];
    };

    #### İlk kurulum tohumu ####
    # Renk dosyaları hiç yoksa matugen'i rice'ın kendi varsayılan duvar
    # kağıdıyla (defaultWallpaper — Stylix'ten bağımsız) bir kez koştur —
    # ilk Hyprland girişinde waybar/swaync renksiz başlamasın.
    # post_hook'lar oturum dışında zararsız (hepsi `|| true` korumalı).
    home.activation.hyprRiceSeedColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -e "${cfgHome}/hypr/colors.lua" ]; then
        verboseEcho "hyprland-rice: ilk renk tohumu (matugen + rice varsayılan duvar kağıdı)"
        mkdir -p "${cfgHome}/hypr" "${cfgHome}/waybar" "${cfgHome}/rofi" \
                 "${cfgHome}/swaync" "${cfgHome}/cava"
        run ${lib.getExe pkgs.matugen} -c "${cfgHome}/matugen/config.toml" \
          image "${defaultWallpaper}" ${matugenArgs} --source-color-index 0 \
          || verboseEcho "matugen tohumu başarısız — ilk girişte theme-apply --restore telafi eder"
      fi
    '';
  };
}
