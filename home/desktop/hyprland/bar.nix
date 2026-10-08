# Waybar — üst kenara yapışık ada; üstüne gelince kontrol paneline, SUPER+Space'te
# başlatıcıya (session.nix) büyür. Ölçüler island.nix. exclusive=false: boşluk look.lua'da.
{ config, lib, pkgs, osConfig ? { }, ... }:

let
  enabled = osConfig.desktop.hyprland.enable or false;
  scripts = import ./scripts.nix { inherit pkgs; };

  hyprctl = "${osConfig.programs.hyprland.package or pkgs.hyprland}/bin/hyprctl";
  ws = sel: "${hyprctl} dispatch 'hl.dsp.focus({ workspace = \"${sel}\" })'";
  inherit (config.lib.stylix) colors;

  barFont = {
    package = pkgs.geist-font;
    name = "Geist";
  };

  isl = import ./island.nix;
  inherit (isl) fillet header;
  px = n: "${toString n}px";

  rowMargin = 13;
  tileMargin = 3;
  tilePadX = 14;
  tileMinWidth = (isl.panelWidth - 2 * rowMargin) / 3 - 2 * (tileMargin + tilePadX);

  launcherEvent = mode: "${hyprctl} dispatch 'hl.dsp.event(\"hypr-launcher ${mode}\")'";

  nmcli = "${pkgs.networkmanager}/bin/nmcli";
  btctl = "${pkgs.bluez}/bin/bluetoothctl";
  grep = "${pkgs.gnugrep}/bin/grep";

  # WAYBAR YAMALARI
  # 1) workspaces modülü eski `dispatch` sözdizimini yolluyor; Lua config hl.dispatch ister.
  #    --replace-fail: upstream değişince derleme düşer → yama gereksiz olabilir, kontrol et.
  # 2) waybar-island.patch: drawer yay fiziğiyle iki eksende büyür; pencere sabit boyut,
  #    giriş bölgesi adaya daraltılır; morph sınıfıyla başlatıcı boyutuna büyür.
  waybar = pkgs.waybar.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./waybar-island.patch ];
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/modules/hyprland/workspace.cpp \
        --replace-fail '"dispatch focusworkspaceoncurrentmonitor " + std::to_string(id())' \
                       '"dispatch hl.dsp.focus({ workspace = " + std::to_string(id()) + ", on_current_monitor = true })"' \
        --replace-fail '"dispatch workspace " + std::to_string(id())' \
                       '"dispatch hl.dsp.focus({ workspace = " + std::to_string(id()) + " })"' \
        --replace-fail '"dispatch focusworkspaceoncurrentmonitor name:" + name()' \
                       '"dispatch hl.dsp.focus({ workspace = \"name:" + name() + "\", on_current_monitor = true })"' \
        --replace-fail '"dispatch workspace name:" + name()' \
                       '"dispatch hl.dsp.focus({ workspace = \"name:" + name() + "\" })"'
    '';
  });

  workspaces = persistent: ignore: {
    format = "{name}";
    persistent-workspaces = lib.genAttrs persistent (_: [ ]);
    ignore-workspaces = ignore;
    on-scroll-up = ws "e-1";
    on-scroll-down = ws "e+1";
  };

  spacer = {
    format = " ";
    tooltip = false;
    expand = true;
  };

  # Simgeyle yazı arası EN SPACE (U+2002): Nerd Font glifi düz boşlukları yutuyor.
  tile = attrs: attrs // {
    expand = true;
    align = 0.0;
  };
in
lib.mkIf enabled {
  stylix.targets.waybar.addCss = false;
  # HM profilindeki bar fontu için fontconfig entegrasyonu şart.
  home.packages = [ barFont.package ];
  fonts.fontconfig.enable = true;

  # tray.target'a asılmasın: Requires=tray.target'lı bir servis GNOME'da barı açardı.
  systemd.user.services.waybar.Install.WantedBy = lib.mkForce [ config.wayland.systemd.target ];

  # Uyarı seviyesi: ada her boyutlanışta [info] basıyordu (journal'ın en büyük yazarı).
  systemd.user.services.waybar.Service.ExecStart =
    lib.mkForce "${waybar}/bin/waybar --log-level warning";

  programs.waybar = {
    enable = true;
    package = waybar;
    systemd.enable = true;

    settings.main = {
      layer = "top";
      position = "top";
      inherit (isl.window) width height;
      exclusive = false;
      spacing = 0;

      modules-center = [ "group/island" ];

      "group/head" = {
        orientation = "vertical";
        modules = [ "group/core" "custom/morph" ];
      };

      # hypr-launcher durum dosyası + SIGRTMIN+10 → yama adayı drawer.morph boyutuna büyütür.
      "custom/morph" = {
        exec = "cat \"$XDG_RUNTIME_DIR/hypr-launcher.json\" 2>/dev/null || echo '{\"text\": \" \"}'";
        return-type = "json";
        interval = "once";
        signal = 10;
        tooltip = false;
      };

      "group/island" = {
        orientation = "vertical";
        drawer = {
          children-class = "island-panel";
          inherit (isl) spring;
          morph = lib.mapAttrs (_: m: [ m.width m.height ]) isl.launcher.modes;
        };
        modules = [
          "group/head"
          "group/info"
          "group/toggles-a"
          "group/toggles-b"
          "group/volume"
          "group/light"
          "mpris"
          "group/stats"
        ];
      };

      "group/core" = {
        orientation = "horizontal";
        modules = [
          "custom/spacer#l"
          "hyprland/workspaces#left"
          "clock"
          "mpris#live"
          "custom/dnd#mini"
          "battery#alert"
          "hyprland/workspaces#right"
          "custom/spacer#r"
        ];
      };
      "group/info" = {
        orientation = "horizontal";
        modules = [ "custom/date" "tray" "custom/power" ];
      };
      "group/toggles-a" = {
        orientation = "horizontal";
        modules = [ "network" "bluetooth" "custom/dnd" ];
      };
      "group/toggles-b" = {
        orientation = "horizontal";
        modules = [ "custom/nightlight" "idle_inhibitor" "power-profiles-daemon" ];
      };
      "group/volume" = {
        orientation = "horizontal";
        modules = [ "pulseaudio#icon" "pulseaudio/slider" "pulseaudio#pct" ];
      };
      "group/light" = {
        orientation = "horizontal";
        modules = [ "backlight#icon" "backlight/slider" "backlight#pct" ];
      };
      "group/stats" = {
        orientation = "horizontal";
        modules = [ "battery" "temperature" "custom/fan" "cpu" "memory" "custom/dgpu" ];
      };

      "hyprland/workspaces#left" = workspaces [ "1" "2" ] [ "^([3-9]|\\d{2,})$" ];
      "hyprland/workspaces#right" = workspaces [ "3" "4" ] [ "^[12]$" ];

      # Görünmez yayıcı. format boş olsaydı modül gizlenir, genişlik almazdı.
      "custom/spacer#l" = spacer;
      "custom/spacer#r" = spacer;

      clock = {
        format = "{:%H:%M}";
        locale = "tr_TR.UTF-8";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "month";
          weeks-pos = "right";
          on-scroll = 1;
          format = {
            today = "<span color='#${colors.base0D}'><b><u>{}</u></b></span>";
            weeks = "<span color='#${colors.base03}'>{}</span>";
            weekdays = "<span color='#${colors.base0A}'><b>{}</b></span>";
          };
        };
        actions = {
          on-scroll-up = "shift_down";
          on-scroll-down = "shift_up";
        };
      };

      "mpris#live" = {
        format = "";
        format-playing = "󰎈";
        tooltip-format = "{artist} — {title}";
      };

      "custom/dnd#mini" = {
        exec = "${lib.getExe scripts.dnd} mini";
        return-type = "json";
        interval = "once";
        signal = 8;
        on-click = "${lib.getExe scripts.dnd} toggle";
      };

      "battery#alert" = {
        bat = "BAT1";
        interval = 60;
        states = {
          warning = 25;
          critical = 10;
        };
        format = "";
        format-charging = "";
        format-plugged = "";
        format-warning = "{icon} {capacity}%";
        format-critical = "{icon} {capacity}%";
        format-icons = [ "󰂎" "󰁺" "󰁻" ];
        tooltip-format = "{timeTo} · {power:.1f} W";
      };

      # Tarih clock#… ile değil: waybar chrono'su %-d tanımıyor.
      "custom/date" = {
        exec = "LC_TIME=tr_TR.UTF-8 ${pkgs.coreutils}/bin/date '+%A, %-d %B'";
        interval = 60;
        tooltip = false;
        expand = true;
        align = 0.0;
      };

      tray = {
        icon-size = 16;
        spacing = 10;
      };

      "custom/power" = {
        format = "⏻";
        tooltip-format = "Güç menüsü · SUPER+Esc";
        on-click = launcherEvent "power";
      };

      # Sol tık güvenli işi yapar; bağlantıyı koparanlar sağ tıkta.
      network = tile {
        format-wifi = "{icon}  {essid}";
        format-ethernet = "󰈀  Kablolu";
        format-linked = "󰈀  IP yok";
        format-disconnected = "󰤮  Bağlı değil";
        format-disabled = "󰤭  Wi-Fi kapalı";
        format-icons = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
        max-length = 18;
        tooltip-format-wifi = "{essid} · %{signalStrength} · {frequency} GHz\n{ipaddr}\nSol tık: Wi-Fi ayarları · Sağ tık: Wi-Fi'yi kapat";
        tooltip-format-ethernet = "{ifname} · {ipaddr}";
        tooltip-format-disconnected = "Bağlantı yok\nSol tık: Wi-Fi ayarları";
        tooltip-format-disabled = "Wi-Fi kapalı\nSağ tık: aç";
        # GNOME Ayarlar Wi-Fi paneli: GNOME dışında XDG_CURRENT_DESKTOP=GNOME şart.
        on-click = "env XDG_CURRENT_DESKTOP=GNOME uwsm-app -- ${pkgs.gnome-control-center}/bin/gnome-control-center wifi";
        on-click-right = "if [ \"$(${nmcli} radio wifi)\" = enabled ]; then ${nmcli} radio wifi off; else ${nmcli} radio wifi on; fi";
      };

      bluetooth = tile {
        format = "󰂯  Bluetooth";
        format-off = "󰂲  Bluetooth";
        format-disabled = "󰂲  Bluetooth";
        format-connected = "󰂱  {device_alias}";
        format-connected-battery = "󰂱  {device_alias} · {device_battery_percentage}%";
        max-length = 18;
        tooltip-format = "Bluetooth açık · {controller_alias}\nSol tık: cihazlar · Sağ tık: kapat";
        tooltip-format-off = "Bluetooth kapalı\nSağ tık: aç";
        tooltip-format-connected = "{device_enumerate}\nSol tık: cihazlar · Sağ tık: kapat";
        tooltip-format-enumerate-connected = "{device_alias}";
        tooltip-format-enumerate-connected-battery = "{device_alias} · %{device_battery_percentage}";
        on-click = "uwsm-app -- ${lib.getExe pkgs.overskride}";
        on-click-right = "if ${btctl} show | ${grep} -q 'Powered: yes'; then ${btctl} power off; else ${btctl} power on; fi";
      };

      "custom/dnd" = tile {
        exec = "${lib.getExe scripts.dnd} status";
        return-type = "json";
        interval = "once";
        signal = 8;
        on-click = "${lib.getExe scripts.dnd} toggle";
        on-click-right = "${pkgs.mako}/bin/makoctl dismiss --all";
      };

      "custom/nightlight" = tile {
        exec = "${lib.getExe scripts.nightLight} status";
        return-type = "json";
        interval = 60;
        signal = 11;
        on-click = "${lib.getExe scripts.nightLight} toggle";
      };

      idle_inhibitor = tile {
        format = "{icon}  Uyanık tut";
        format-icons = {
          activated = "󰅶";
          deactivated = "󰛊";
        };
        tooltip-format-activated = "Uyanık tut: açık — uyku ve kilit kapalı\nTıkla: normale dön";
        tooltip-format-deactivated = "Uyku ve kilit normal\nTıkla: ekranı uyanık tut";
      };

      power-profiles-daemon = tile {
        format = "{icon}";
        tooltip-format = "Güç profili: {profile} · sürücü: {driver}\nTıkla: sonraki profil";
        format-icons = {
          default = "󰾅  Dengeli";
          performance = "󰓅  Performans";
          balanced = "󰾅  Dengeli";
          power-saver = "󰾆  Tasarruf";
        };
      };

      "pulseaudio#icon" = {
        # Font Awesome aralığı (U+F02x) bu fontta çizilmiyor → Material Design glifleri.
        format = "{icon}";
        format-muted = "󰝟";
        format-bluetooth = "{icon}";
        format-icons = {
          headphone = "󰋋";
          default = [ "󰕿" "󰖀" "󰕾" ];
        };
        tooltip-format = "{desc}\nSol tık: sessiz · Sağ tık: mikser";
        on-click = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-click-right = "uwsm-app -- ${lib.getExe pkgs.pwvucontrol}";
      };
      "pulseaudio/slider" = {
        min = 0;
        max = 100;
        expand = true;
      };
      "pulseaudio#pct" = {
        format = "{volume}%";
        format-muted = "sessiz";
        align = 1.0;
        scroll-step = 5;
        max-volume = 100;
        tooltip = false;
      };

      "backlight#icon" = {
        device = "amdgpu_bl1";
        format = "{icon}";
        format-icons = [ "󰃞" "󰃟" "󰃠" ];
        tooltip = false;
      };
      "backlight/slider" = {
        device = "amdgpu_bl1";
        min = 5;
        max = 100;
        expand = true;
      };
      "backlight#pct" = {
        device = "amdgpu_bl1";
        format = "{percent}%";
        align = 1.0;
        tooltip = false;
      };

      mpris = {
        format = "{player_icon}  {dynamic}";
        format-paused = "{status_icon}  <i>{dynamic}</i>";
        dynamic-order = [ "title" "artist" ];
        dynamic-separator = "  ·  ";
        dynamic-len = 48;
        player-icons.default = "󰎈";
        status-icons.paused = "󰏤";
        tooltip-format = "{player}: {artist} — {title}\nSol tık: oynat/duraklat · Sağ tık: sonraki · Orta tık: önceki";
        on-click-right = "${lib.getExe pkgs.playerctl} next";
        on-click-middle = "${lib.getExe pkgs.playerctl} previous";
        align = 0.0;
      };

      battery = {
        bat = "BAT1";
        interval = 60;
        states = {
          warning = 25;
          critical = 10;
        };
        format = "{icon}  {capacity}%";
        format-charging = "󰂄  {capacity}%";
        format-plugged = "󰚥  {capacity}%";
        format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        tooltip-format = "{timeTo} · {power:.1f} W";
        expand = true;
        align = 0.0;
      };

      # hwmon numarası boot'a göre kayar → PCI yolundan bulunur.
      temperature = {
        hwmon-path-abs = "/sys/devices/pci0000:00/0000:00:18.3/hwmon";
        input-filename = "temp1_input";
        interval = 5;
        critical-threshold = 90;
        format = "{icon} {temperatureC}°";
        format-icons = [ "󰔏" "󰔏" "󰸁" "󰸁" ];
        tooltip-format = "CPU (Tctl): {temperatureC}°C";
      };

      "custom/fan" = {
        exec = lib.getExe scripts.fanStatus;
        return-type = "json";
        interval = 5;
        signal = 9;
        on-click = "${pkgs.systemd}/bin/systemctl start --no-block aero-fan-cycle.service; sleep 0.6; ${pkgs.systemd}/bin/systemctl --user kill --signal=SIGRTMIN+9 waybar.service";
      };

      cpu = {
        interval = 5;
        format = "󰍛 {usage}%";
        tooltip-format = "CPU {usage}% · yük {load}";
        on-click = "uwsm-app -- ghostty -e btop";
      };

      memory = {
        interval = 10;
        format = "󰘚 {percentage}%";
        tooltip-format = "RAM {used:0.1f} / {total:0.1f} GiB · swap {swapUsed:0.1f} GiB";
        on-click = "uwsm-app -- ghostty -e btop";
      };

      "custom/dgpu" = {
        exec = lib.getExe scripts.dgpuStatus;
        return-type = "json";
        interval = 5;
      };
    };

    # Arka bulanıklık: rules.lua "glass" layer_rule. Aynı renkler hypr-launcher CSS'inde (session.nix).
    style = lib.mkAfter ''
      @define-color island alpha(@base00, 0.90);
      @define-color tile alpha(@base02, 0.55);
      @define-color tile-hover alpha(@base03, 0.55);
      @define-color tile-on alpha(@base0D, 0.24);
      @define-color tile-on-hover alpha(@base0D, 0.34);

      * {
        /* Geist: dar ama ferah, rakamları sabit genişlikte (tnum) — saat
           dakika dönerken titremiyor; Inter'den daha "oturaklı", Figtree/Rubik
           kadar yuvarlak-oyuncak değil. Simgeler Nerd Font yedeğinden. */
        font-family: "${barFont.name}", "JetBrainsMono Nerd Font";
        font-size: 13px;
        font-feature-settings: "tnum";
        border: none;
        border-radius: 0;
        min-height: 0;
        box-shadow: none;
        text-shadow: none;
      }

      /* Pencere sabit ve saydam. İçbükey köşeler adayı taşıyan kutuda
         (.modules-center = ada + iki yanda ${px fillet}): sol/üst kare, merkezi
         alt köşede olan çeyrek daire dışında dolu → üst kenardan adanın
         yanına teğet inen yay. */
      window#waybar {
        background: transparent;
        color: @base05;
      }
      .modules-center {
        background-color: transparent;
        background-image:
          radial-gradient(circle ${px fillet} at 0% 100%, transparent ${px (fillet - 1)}, @island ${px fillet}),
          radial-gradient(circle ${px fillet} at 100% 100%, transparent ${px (fillet - 1)}, @island ${px fillet});
        background-size: ${px fillet} ${px fillet};
        background-position: left top, right top;
        background-repeat: no-repeat;
      }

      /* Ada içeriğini kırpan kap (yamadaki ScrolledWindow) — çerçevesiz, zeminsiz */
      #island scrolledwindow,
      #island viewport,
      #island overshoot,
      #island undershoot {
        background: none;
        border: none;
      }

      #island {
        margin: 0 ${px fillet};
        background: @island;
        border-radius: 0 0 ${px isl.radius} ${px isl.radius};
      }

      /* Başlatıcı dönüşümünün sinyal alıcısı: görünmez 1 px etiket. Boyutu
         CSS'ten değil, yamadan (drawer.morph) gelir. */
      #custom-morph {
        font-size: 1px;
        color: transparent;
        padding: 0;
        margin: 0;
        min-width: 0;
        min-height: 0;
      }

      /* ───── kapalı ada ───── */
      #custom-spacer {
        padding: 0;
        min-width: 0;
      }

      /* Kenar boşluğu açık/kapalı AYNI: yama kapanışın hedef genişliğini bu
         satırın doğal genişliğinden alıyor; değişseydi sonda birkaç px zıplardı. */
      #core {
        min-height: ${px header};
        padding: 0 10px;
      }

      #workspaces button {
        color: @base04;
        background: transparent;
        border-radius: 999px;
        margin: 4px 1px; /* saat satırı ${px header} */
        padding: 0 7px;
        min-width: 6px;
        font-size: 12px;
        font-weight: 500;
        transition: all 300ms cubic-bezier(0.22, 1, 0.36, 1);
      }
      #workspaces button.empty {
        color: alpha(@base04, 0.45);
      }
      #workspaces button.active {
        color: @base00;
        background: @base0D;
        padding: 0 11px;
        font-weight: 700;
      }
      #workspaces button.urgent {
        color: @base00;
        background: @base08;
      }
      #workspaces button:hover {
        color: @base05;
        background: alpha(@base0D, 0.22);
      }
      #workspaces button.active:hover {
        color: @base00;
        background: @base0D;
      }

      #clock {
        font-size: 14px;
        font-weight: 600;
        letter-spacing: 0.4px;
        padding: 0 14px;
        color: @base06;
      }

      /* Canlı işaretler: saatin sağında, küçük ve renkli. */
      #mpris.live {
        color: @base0B;
        font-size: 13px;
        padding: 0 8px 0 0;
      }
      #custom-dnd.mini {
        color: @base08;
        font-size: 13px;
        padding: 0 8px 0 0;
      }
      #battery.alert {
        padding: 0 8px 0 0;
        font-size: 12px;
        font-weight: 600;
      }
      #battery.alert.warning  { color: @base0A; }
      #battery.alert.critical { color: @base08; }

      /* ───── açılan panel ───── */
      #info {
        margin: 2px 16px 0 16px;
        padding: 9px 0 8px 2px;
        border-top: 1px solid alpha(@base03, 0.45);
      }
      #custom-date {
        font-size: 13px;
        font-weight: 600;
        color: @base05;
        padding: 0 16px 0 0;
      }
      #tray {
        padding: 0 10px 0 2px;
      }
      #tray > .needs-attention {
        background: alpha(@base08, 0.35);
        border-radius: 6px;
      }
      #custom-power {
        color: @base08;
        font-size: 13px;
        background: alpha(@base08, 0.12);
        border-radius: 999px;
        min-width: 26px;
        min-height: 26px;
        padding: 0;
        transition: background 250ms ease;
      }
      #custom-power:hover {
        background: alpha(@base08, 0.26);
      }

      /* Karolar: iki satır × üç; satır panelWidth'i (${px isl.panelWidth}) tam
         doldurur (bar.nix tileMinWidth). Açık olan vurgu renginde. */
      #toggles-a, #toggles-b {
        margin: 3px ${px rowMargin};
      }
      #toggles-a { margin-top: 4px; }
      #network, #bluetooth, #custom-dnd:not(.mini), #custom-nightlight,
      #idle_inhibitor, #power-profiles-daemon {
        background: @tile;
        color: @base05;
        border-radius: 14px;
        margin: 0 ${px tileMargin};
        padding: 10px ${px tilePadX};
        min-width: ${px tileMinWidth};
        font-weight: 500;
        transition: background 250ms ease, color 250ms ease;
      }
      #network:hover, #bluetooth:hover, #custom-dnd:not(.mini):hover, #custom-nightlight:hover,
      #idle_inhibitor:hover, #power-profiles-daemon:hover {
        background: @tile-hover;
      }
      /* Açık / bağlı */
      #network.wifi, #network.ethernet,
      #bluetooth.on, #bluetooth.connected,
      #custom-dnd.on:not(.mini), #custom-nightlight.on,
      #idle_inhibitor.activated,
      #power-profiles-daemon.performance, #power-profiles-daemon.power-saver {
        background: @tile-on;
        color: @base07;
      }
      #network.wifi:hover, #network.ethernet:hover,
      #bluetooth.on:hover, #bluetooth.connected:hover,
      #custom-dnd.on:not(.mini):hover, #custom-nightlight.on:hover,
      #idle_inhibitor.activated:hover,
      #power-profiles-daemon.performance:hover, #power-profiles-daemon.power-saver:hover {
        background: @tile-on-hover;
      }
      /* Kapalı / bağlantısız: soluk */
      #network.disconnected, #network.disabled, #network.linked,
      #bluetooth.off, #bluetooth.disabled {
        color: @base04;
      }
      /* Renkli durumlar: rahatsız etme kırmızımsı, gece ışığı sıcak, uyanık
         sarı, performans turuncu, tasarruf yeşil. */
      #custom-dnd.on:not(.mini)         { background: alpha(@base08, 0.22); }
      #custom-nightlight.on             { background: alpha(@base09, 0.22); }
      #idle_inhibitor.activated         { background: alpha(@base0A, 0.22); }
      #power-profiles-daemon.performance { background: alpha(@base09, 0.22); }
      #power-profiles-daemon.power-saver { background: alpha(@base0B, 0.20); }

      /* Kaydırıcılar */
      #volume, #light {
        margin: 2px 16px 0 16px;
        min-height: 30px;
      }
      #volume { margin-top: 8px; }
      #pulseaudio.icon, #backlight.icon {
        font-size: 15px;
        min-width: 22px;
        padding: 0 8px 0 2px;
        color: @base05;
      }
      #pulseaudio.icon.muted { color: @base03; }
      #pulseaudio.pct, #backlight.pct {
        font-size: 12px;
        color: @base04;
        min-width: 40px;
      }
      #pulseaudio-slider, #backlight-slider {
        padding: 0 6px;
      }
      #pulseaudio-slider trough, #backlight-slider trough {
        min-height: 6px;
        border-radius: 3px;
        background: alpha(@base03, 0.55);
      }
      #pulseaudio-slider highlight, #backlight-slider highlight {
        min-height: 6px;
        border-radius: 3px;
        background: @base0D;
      }
      #backlight-slider highlight {
        background: @base0A;
      }
      #pulseaudio-slider slider, #backlight-slider slider {
        min-width: 14px;
        min-height: 14px;
        margin: -4px 0;
        border-radius: 999px;
        background: @base06;
        box-shadow: 0 1px 3px alpha(@base00, 0.5);
        transition: background 200ms ease;
      }
      #pulseaudio-slider slider:hover, #backlight-slider slider:hover {
        background: @base07;
      }

      /* Medya kartı */
      #mpris:not(.live) {
        margin: 8px 16px 0 16px;
        padding: 9px 14px;
        border-radius: 14px;
        background: @tile;
        color: @base0B;
        transition: background 250ms ease;
      }
      #mpris:not(.live):hover {
        background: @tile-hover;
      }
      #mpris.paused:not(.live) {
        color: @base04;
      }

      /* Donanım satırı */
      #stats {
        margin: 10px 16px 12px 16px;
        padding-top: 9px;
        border-top: 1px solid alpha(@base03, 0.45);
      }
      #battery:not(.alert) {
        font-size: 12px;
        font-weight: 600;
        color: @base05;
        padding: 0 0 0 2px;
      }
      #temperature, #custom-fan, #cpu, #memory, #custom-dgpu {
        color: @base04;
        padding: 0 0 0 14px;
        font-size: 12px;
      }

      /* ───── durum renkleri ───── */
      #battery.charging:not(.alert),
      #battery.plugged:not(.alert) {
        color: @base0B;
      }
      #battery.warning:not(.charging):not(.alert) {
        color: @base0A;
      }
      #battery.critical:not(.charging):not(.alert) {
        color: @base08;
        font-weight: bold;
      }
      #temperature.critical {
        color: @base08;
      }
      /* Fan modu rengi: sessizden turboya soğuktan sıcağa */
      #custom-fan.quiet      { color: @base0C; }
      #custom-fan.balanced   { color: @base04; }
      #custom-fan.responsive { color: @base0D; }
      #custom-fan.gaming     { color: @base0A; }
      #custom-fan.turbo      { color: @base08; }
      #custom-dgpu {
        color: @base0A;
      }

      tooltip {
        background: alpha(@base00, 0.95);
        border: 1px solid alpha(@base03, 0.6);
        border-radius: 12px;
      }
      tooltip label {
        color: @base05;
        padding: 2px 4px;
      }
    '';
  };
}
