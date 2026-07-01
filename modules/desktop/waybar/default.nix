{ osConfig, pkgs, ... }:

let
  bg     = "#${osConfig.desktop.theme.colors.bg}";
  fg     = "#${osConfig.desktop.theme.colors.fg}";
  accent = "#${osConfig.desktop.theme.colors.accent}";

  # custom/battery-wh: tooltip'te Wh göster (BAT1 sysfs: charge_now × voltage_now)
  batteryWh = pkgs.writeShellScriptBin "battery-wh" ''
    BAT=/sys/class/power_supply/BAT1
    status=$(cat "$BAT/status" 2>/dev/null || echo Unknown)
    current_now=$(cat "$BAT/current_now" 2>/dev/null || echo 0)
    voltage_now=$(cat "$BAT/voltage_now" 2>/dev/null || echo 0)
    charge_now=$(cat "$BAT/charge_now" 2>/dev/null || echo 0)
    charge_full=$(cat "$BAT/charge_full" 2>/dev/null || echo 1)

    pct=$(awk "BEGIN{printf \"%d\", ($charge_now/$charge_full)*100}")
    [ "$pct" -gt 100 ] && pct=100

    wh_now=$(awk "BEGIN{printf \"%.1f\", $charge_now*$voltage_now/1e12}")
    wh_full=$(awk "BEGIN{printf \"%.1f\", $charge_full*$voltage_now/1e12}")
    power=$(awk "BEGIN{printf \"%.2f\", $current_now*$voltage_now/1e12}")

    if [ "$current_now" -gt 100000 ]; then
      if [ "$status" = "Charging" ]; then
        mins=$(awk "BEGIN{printf \"%d\", ($charge_full-$charge_now)*60/$current_now}")
        time_str=$(printf '%dh %02dm dolacak' $((mins/60)) $((mins%60)))
        power_arrow="↑"
      else
        mins=$(awk "BEGIN{printf \"%d\", $charge_now*60/$current_now}")
        time_str=$(printf '%dh %02dm kaldı' $((mins/60)) $((mins%60)))
        power_arrow="↓"
      fi
    else
      time_str="Tam şarj"
      power_arrow=""
    fi

    if   [ "$status" = "Full" ] || [ "$pct" -ge 100 ]; then icon="󰂅"
    elif [ "$status" = "Charging" ]; then
      if   [ "$pct" -le 10 ]; then icon="󰢜"
      elif [ "$pct" -le 20 ]; then icon="󰂆"
      elif [ "$pct" -le 30 ]; then icon="󰂇"
      elif [ "$pct" -le 40 ]; then icon="󰂈"
      elif [ "$pct" -le 50 ]; then icon="󰢝"
      elif [ "$pct" -le 60 ]; then icon="󰂉"
      elif [ "$pct" -le 70 ]; then icon="󰢞"
      elif [ "$pct" -le 80 ]; then icon="󰂊"
      elif [ "$pct" -le 90 ]; then icon="󰂋"
      else                         icon="󰂅"
      fi
    else
      if   [ "$pct" -le 10 ]; then icon="󰁺"
      elif [ "$pct" -le 20 ]; then icon="󰁻"
      elif [ "$pct" -le 30 ]; then icon="󰁼"
      elif [ "$pct" -le 40 ]; then icon="󰁽"
      elif [ "$pct" -le 50 ]; then icon="󰁾"
      elif [ "$pct" -le 60 ]; then icon="󰁿"
      elif [ "$pct" -le 70 ]; then icon="󰂀"
      elif [ "$pct" -le 80 ]; then icon="󰂁"
      elif [ "$pct" -le 90 ]; then icon="󰂂"
      else                         icon="󰁹"
      fi
    fi

    if [ "$status" = "Full" ]; then
      css="full"
      tooltip="Tam şarj   $wh_full Wh"
    elif [ "$status" = "Charging" ]; then
      css="charging"
      tooltip="$power W$power_arrow   $wh_now / $wh_full Wh\n$time_str"
    else
      css="discharging"
      tooltip="$power W$power_arrow   $wh_now / $wh_full Wh\n$time_str"
    fi

    printf '{"text":"%s","tooltip":"%s","class":"%s","percentage":%d}\n' \
      "$icon" "$tooltip" "$css" "$pct"
  '';
in
{
  programs.waybar = {
    enable = true;

    settings = [{
      layer    = "top";
      position = "top";
      height   = 26;
      spacing  = 0;

      "modules-left"   = [ "hyprland/workspaces" ];
      "modules-center" = [ "clock" ];
      "modules-right"  = [ "network" "pulseaudio" "cpu" "custom/battery-wh" ];

      "hyprland/workspaces" = {
        on-click = "activate";
        format = "{icon}";
        format-icons = {
          default  = "○";
          active   = "●";
          urgent   = "◉";
        };
        persistent-workspaces = {
          "1" = [];
          "2" = [];
          "3" = [];
          "4" = [];
          "5" = [];
        };
      };

      clock = {
        format     = "{:%H:%M}";
        format-alt = "{:%A %d %B %Y}";
        tooltip    = false;
      };

      "custom/battery-wh" = {
        exec           = "${batteryWh}/bin/battery-wh";
        "return-type"  = "json";
        interval       = 30;
        states         = { warning = 20; critical = 10; };
        tooltip        = true;
      };

      network = {
        format              = "{icon}";
        format-wifi         = "󰤨";
        format-ethernet     = "󰀂";
        format-disconnected = "󰤮";
        "tooltip-format-wifi"         = "{essid} {signalStrength}%";
        "tooltip-format-ethernet"     = "Ethernet";
        "tooltip-format-disconnected" = "Bağlantı yok";
        interval = 30;
      };

      pulseaudio = {
        format       = "{icon}";
        format-muted = "";
        format-icons = {
          default = [ "" "" "" ];
        };
        "on-click"       = "pavucontrol";
        scroll-step      = 5;
        "tooltip-format" = "{volume}%";
      };

      cpu = {
        format     = "󰍛";
        interval   = 30;
        "on-click" = "alacritty -e btop";
        "tooltip-format" = "{usage}%";
      };
    }];

    style = ''
      * {
        background-color: transparent;
        color: ${fg};
        border: none;
        border-radius: 0;
        min-height: 0;
        font-family: 'JetBrainsMono Nerd Font', monospace;
        font-size: 12px;
      }

      window#waybar {
        background-color: ${bg};
        border-bottom: 1px solid rgba(255,255,255,0.05);
      }

      .modules-left   { margin-left: 8px; }
      .modules-right  { margin-right: 8px; }

      #workspaces button {
        all: initial;
        color: ${fg};
        padding: 0 6px;
        margin: 0 1px;
        min-width: 9px;
        opacity: 0.5;
      }
      #workspaces button.active  { opacity: 1; color: ${accent}; }
      #workspaces button.urgent  { color: #f7768e; opacity: 1; }

      #clock { margin: 0 8px; }

      #custom-battery-wh,
      #network,
      #pulseaudio,
      #cpu {
        min-width: 12px;
        margin: 0 7px;
      }

      #custom-battery-wh.warning  { color: #e0af68; }
      #custom-battery-wh.critical { color: #f7768e; }

      tooltip {
        background-color: ${bg};
        border: 1px solid rgba(255,255,255,0.1);
        padding: 4px 8px;
      }
    '';
  };
}
