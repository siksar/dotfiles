# Hyprland oturum servisleri; hepsi UWSM'in Hyprland hedefine bağlı (default.nix).
{ config, lib, pkgs, osConfig ? { }, ... }:

let
  enabled = osConfig.desktop.hyprland.enable or false;
  inherit (config.lib.stylix) colors;
  scripts = import ./scripts.nix { inherit pkgs; };
  inherit (config.stylix) fonts;
  isl = import ./island.nix;

  launcherCss = pkgs.writeText "hypr-launcher.css" (
    lib.concatStrings (map (n: "@define-color ${n} #${colors.${n}};\n")
      [ "base00" "base01" "base02" "base03" "base04" "base05" "base06" "base07"
        "base08" "base09" "base0A" "base0B" "base0C" "base0D" "base0E" "base0F" ])
    + ''
      @define-color island alpha(@base00, 0.90);
      @define-color tile alpha(@base02, 0.55);
      @define-color tile-hover alpha(@base03, 0.55);
    ''
    + builtins.readFile ./launcher/style.css
  );
  launcherConfig = pkgs.writeText "hypr-launcher.json" (builtins.toJSON {
    css = launcherCss;
    inherit (isl) header;
    inherit (isl.launcher) rowHeight iconSize restWidth leadMs closeLead;
    inherit (isl) spring;
    signal = 10;
    iconTheme = "Adwaita";
    modes = lib.mapAttrs (name: m: m // {
      apps = {
        placeholder = "Uygulama, pencere ya da komut ara…";
        chip = "Başlat";
        footer = [ [ "↵" "aç" ] [ "Tab" "eylemler" ] [ "=" "hesapla" ] [ ">" "komut" ] [ "Esc" "kapat" ] ];
      };
      clip = {
        placeholder = "Panoda ara…";
        chip = "Pano";
        footer = [ [ "↵" "kopyala" ] [ "⇧ Del" "sil" ] [ "Esc" "kapat" ] ];
      };
      power = {
        placeholder = "Güç…";
        chip = "Güç";
        footer = [ [ "↵" "seç" ] [ "Esc" "vazgeç" ] ];
      };
    }.${name}) isl.launcher.modes;
    bin = {
      uwsmApp = "${pkgs.uwsm}/bin/uwsm-app";
      uwsm = lib.getExe pkgs.uwsm;
      wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";
      cliphist = lib.getExe pkgs.cliphist;
      systemctl = "${pkgs.systemd}/bin/systemctl";
      loginctl = "${pkgs.systemd}/bin/loginctl";
      makoctl = "${pkgs.mako}/bin/makoctl";
      dnd = lib.getExe scripts.dnd;
      nightLight = lib.getExe scripts.nightLight;
      screenshot = lib.getExe scripts.screenshot;
      colorPicker = "${lib.getExe pkgs.hyprpicker} --autocopy --format=hex";
    };
  });

  hyprctl = "${osConfig.programs.hyprland.package or pkgs.hyprland}/bin/hyprctl";
  dpms = state: "${hyprctl} dispatch 'hl.dsp.dpms({ action = \"${state}\" })'";
  brightnessctl = lib.getExe pkgs.brightnessctl;
  loginctl = "${pkgs.systemd}/bin/loginctl";

  # Yalnız PİLDE uyku. Ayrı betik: hypridle config'i hyprlang, `$(…)` değişken sanılır.
  suspendOnBattery = pkgs.writeShellScript "hypr-idle-suspend" ''
    [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = 0 ] || exit 0
    exec ${pkgs.systemd}/bin/systemctl suspend
  '';
in
lib.mkIf enabled {
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        immediate_render = true; # kilit ilk karede çizilsin (uyku öncesi yarış)
      };
      animations.enabled = true;

      background = {
        blur_passes = 3;
        blur_size = 7;
        brightness = 0.55;
        vibrancy = 0.17;
      };

      input-field = {
        monitor = "";
        size = "340, 54";
        position = "0, -140";
        halign = "center";
        valign = "center";
        outline_thickness = 2;
        rounding = 16;
        dots_size = 0.22;
        dots_spacing = 0.35;
        dots_center = true;
        fade_on_empty = false;
        font_family = fonts.sansSerif.name;
        placeholder_text = "<i>Parola</i>";
        fail_text = "<i>$FAIL · $ATTEMPTS</i>";
      };

      # Etiket rengi Stylix dışında → base05 elle bağlı.
      label = [
        {
          monitor = "";
          text = "$TIME";
          font_size = 96;
          font_family = fonts.sansSerif.name;
          color = "rgb(${colors.base05})";
          position = "0, 160";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "cmd[update:3600000] date +'%A, %-d %B'";
          font_size = 20;
          font_family = fonts.sansSerif.name;
          color = "rgba(${colors.base05}cc)";
          position = "0, 60";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };

  # 4 dk kararma → 5 dk kilit → 5.5 dk ekran kapalı → 15 dk uyku (yalnız pilde).
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${lib.getExe config.programs.hyprlock.package}";
        before_sleep_cmd = "${loginctl} lock-session"; # kapak kapanınca da kilitli uyan
        after_sleep_cmd = dpms "on";
        ignore_dbus_inhibit = false;
      };
      listener = [
        {
          timeout = 240;
          on-timeout = "${brightnessctl} -s set 10%";
          on-resume = "${brightnessctl} -r";
        }
        {
          timeout = 240;
          on-timeout = "${lib.getExe scripts.kbdIdle} off";
          on-resume = "${lib.getExe scripts.kbdIdle} on";
        }
        {
          timeout = 300;
          on-timeout = "${loginctl} lock-session";
        }
        {
          timeout = 330;
          on-timeout = dpms "off";
          on-resume = dpms "on";
        }
        {
          timeout = 900;
          on-timeout = "${suspendOnBattery}";
        }
      ];
    };
  };

  # package = null BİLEREK: HM paketi D-Bus aktivasyon dosyasını profile koyar, mako
  # GNOME/COSMIC'te bildirim adını kapabilirdi. Yerine yalnız Hyprland hedefli birim.
  services.mako = {
    enable = true;
    package = null;
    settings = with colors; {
      anchor = "top-right";
      layer = "overlay";
      width = 400;
      height = 200;
      outer-margin = 12;
      margin = "8";
      padding = "14,18";
      border-size = 1;
      border-radius = 16;
      background-color = lib.mkForce "#${base00}D9";
      border-color = lib.mkForce "#${base03}8C";
      text-color = lib.mkForce "#${base05}";
      font = lib.mkForce "${fonts.sansSerif.name} 11";
      # '%%': mako biçiminde çıplak % belirteç sayılır, config hiç yüklenmez (3 Eki 2026).
      format = "<span size='small' alpha='60%%'>%a</span>\\n<b>%s</b>\\n%b";
      default-timeout = 6000;
      max-visible = 5;
      max-history = 50;
      sort = "-time";
      markup = true;
      actions = true;
      icons = true;
      icon-location = "left";
      max-icon-size = 40;
      group-by = "app-name,summary";
      progress-color = lib.mkForce "over #${base0D}66";

      "urgency=low" = {
        background-color = lib.mkForce "#${base00}D9";
        border-color = lib.mkForce "#${base02}8C";
        text-color = lib.mkForce "#${base04}";
      };
      "urgency=critical" = {
        background-color = lib.mkForce "#${base00}EB";
        border-color = lib.mkForce "#${base08}";
        text-color = lib.mkForce "#${base05}";
        border-size = 2;
        default-timeout = 0;
      };

      "mode=do-not-disturb".invisible = 1;
      "mode=do-not-disturb category=osd".invisible = 0;
      "mode=do-not-disturb urgency=critical".invisible = 0;

      "category=osd" = {
        anchor = "bottom-center";
        outer-margin = "0,0,96,0";
        width = 300;
        height = 64;
        padding = "16,24";
        border-radius = 32;
        format = "<b>%s</b>";
        font = "${fonts.sansSerif.name} 12";
        text-alignment = "center";
        default-timeout = 1200;
        history = 0;
        group-by = "category";
        icons = false;
        progress-color = "over #${base0D}59";
      };
    };
  };

  systemd.user.services.mako = {
    Unit = {
      Description = "mako bildirim daemon'u (yalnız Hyprland oturumu)";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "dbus";
      BusName = "org.freedesktop.Notifications";
      ExecStart = lib.getExe pkgs.mako;
      ExecReload = "${pkgs.mako}/bin/makoctl reload";
      Restart = "on-failure";
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };

  # Claude sesli asistan: arka planda hazır Chromium; tuş soket2'ye olay yayar (lua/voice.lua).
  systemd.user.services.claude-voice = {
    Unit = {
      Description = "Claude sesli asistan (Copilot tuşu) — yalnız Hyprland oturumu";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
      ConditionEnvironment = [ "WAYLAND_DISPLAY" "HYPRLAND_INSTANCE_SIGNATURE" ];
    };
    Service = {
      ExecStart = "${lib.getExe scripts.claudeVoice} --daemon";
      Restart = "always";
      RestartSec = 1;
      # 75 = başka bir örnek çalışıyor (voice.py ALONE): yeniden deneme anlamsız.
      RestartPreventExitStatus = 75;
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };

  services.cliphist = {
    enable = true;
    allowImages = true;
    extraOptions = [ "-max-items" "500" ];
  };

  # nm-applet autostart'ını gölgele (Hidden=true): waybar ağ modülünün tekrarı.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Network
    Hidden=true
  '';

  # Polkit ajanı yoksa Hyprland'de her polkit isteği sessizce reddedilir.
  services.hyprpolkitagent.enable = true;

  services.hyprsunset = {
    enable = true;
    settings.profile = [
      {
        time = "7:00";
        identity = true;
      }
      {
        time = "21:00";
        temperature = 4500;
      }
    ];
  };

  systemd.user.services.hypr-launcher = {
    Unit = {
      Description = "hypr-launcher — adanın başlatıcısı (yalnız Hyprland oturumu)";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
      ConditionEnvironment = [ "WAYLAND_DISPLAY" "HYPRLAND_INSTANCE_SIGNATURE" ];
    };
    Service = {
      ExecStart = "${lib.getExe scripts.launcher} --config ${launcherConfig}";
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}
