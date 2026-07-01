{ osConfig, pkgs, ... }:

let
  bg      = "#${osConfig.desktop.theme.colors.bg}";
  fg      = "#${osConfig.desktop.theme.colors.fg}";
  accent  = "#${osConfig.desktop.theme.colors.accent}";
in
{
  programs.waybar = {
    enable = true;
    package = pkgs.waybar;

    settings = [{
      layer    = "top";
      position = "top";
      height   = 26;
      spacing  = 0;

      "modules-left"   = [ "hyprland/workspaces" ];
      "modules-center" = [ "clock" ];
      "modules-right"  = [ "network" "pulseaudio" "cpu" "battery" ];

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

      # omarchy battery bar — ikon tabanlı, tooltip'te watt gösterir
      battery = {
        format-discharging = "{icon}";
        format-charging    = "{icon}";
        format-plugged     = "";
        format-full        = "󰂅";
        format-icons = {
          charging = [ "󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅" ];
          default  = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
        };
        "tooltip-format-discharging" = "{power:>1.0f}W↓  {capacity}%";
        "tooltip-format-charging"    = "{power:>1.0f}W↑  {capacity}%";
        "tooltip-format-plugged"     = "Tam şarj  {capacity}%";
        interval = 5;
        states = {
          warning  = 20;
          critical = 10;
        };
      };

      network = {
        format             = "{icon}";
        format-wifi        = "󰤨";
        format-ethernet    = "󰀂";
        format-disconnected = "󰤮";
        "tooltip-format-wifi"     = "{essid} {signalStrength}%";
        "tooltip-format-ethernet" = "Ethernet";
        "tooltip-format-disconnected" = "Bağlantı yok";
        interval = 5;
      };

      pulseaudio = {
        format       = "{icon}";
        format-muted = "";
        format-icons = {
          default = [ "" "" "" ];
        };
        "on-click"   = "pavucontrol";
        scroll-step  = 5;
        "tooltip-format" = "{volume}%";
      };

      cpu = {
        format   = "󰍛";
        interval = 5;
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

      #clock    { margin: 0 8px; }

      #battery,
      #network,
      #pulseaudio,
      #cpu {
        min-width: 12px;
        margin: 0 7px;
      }

      #battery.warning  { color: #e0af68; }
      #battery.critical { color: #f7768e; }

      tooltip {
        background-color: ${bg};
        border: 1px solid rgba(255,255,255,0.1);
        padding: 4px 8px;
      }
    '';
  };
}
