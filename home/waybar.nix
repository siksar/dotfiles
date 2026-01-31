{ config, pkgs, ... }:
{
  # ========================================================================
  # WAYBAR - Vertical Left-Side Bar (Screenshot Style)
  # ========================================================================
  
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    
    settings = {
      mainBar = {
        layer = "top";
        position = "left";
        width = 48;
        spacing = 4;
        margin-top = 0;
        margin-bottom = 0;
        margin-left = 0;
        
        modules-left = [
          "custom/logo"
          "hyprland/workspaces"
        ];
        modules-center = [];
        modules-right = [
          "tray"
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "battery"
          "clock"
        ];
        
        # NixOS Logo at top - clicks open app menu
        "custom/logo" = {
          format = "󱄅";
          tooltip = true;
          tooltip-format = "App Menu";
          on-click = "rofi -show drun -theme ~/.config/rofi/config.rasi";
        };
        
        # Workspaces - Colored circles
        "hyprland/workspaces" = {
          format = "{icon}";
          format-icons = {
            "1" = "●";
            "2" = "●";
            "3" = "●";
            "4" = "●";
            "5" = "●";
            "6" = "●";
            "7" = "●";
            "8" = "●";
            "9" = "●";
            "10" = "●";
            active = "●";
            default = "●";
            urgent = "●";
          };
          on-click = "activate";
          sort-by-number = true;
          all-outputs = true;
          persistent-workspaces = {
            "*" = 5;  # Show 5 workspaces by default
          };
        };
        
        # Clock with calendar tooltip
        clock = {
          format = "{:%H\n%M}";
          format-alt = "{:%d\n%m}";
          tooltip = true;
          tooltip-format = "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            weeks-pos = "left";
            on-scroll = 1;
            format = {
              months = "<span color='#d79921'><b>{}</b></span>";
              days = "<span color='#ebdbb2'>{}</span>";
              weeks = "<span color='#689d6a'>W{}</span>";
              weekdays = "<span color='#cc241d'>{}</span>";
              today = "<span color='#d65d0e'><b><u>{}</u></b></span>";
            };
          };
          actions = {
            on-click-right = "mode";
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };
        
        # CPU
        cpu = {
          format = "󰻠";
          tooltip = true;
          tooltip-format = "CPU: {usage}%\nLoad: {load}";
          interval = 2;
          on-click = "kitty -e htop";
        };
        
        # Memory
        memory = {
          format = "󰍛";
          tooltip = true;
          tooltip-format = "RAM: {used:0.1f}GB / {total:0.1f}GB ({percentage}%)";
          interval = 2;
          on-click = "kitty -e htop";
        };
        
        # Battery
        battery = {
          bat = "BAT0";
          interval = 30;
          states = {
            good = 80;
            warning = 30;
            critical = 15;
          };
          format = "{icon}";
          format-charging = "󰂄";
          format-plugged = "󰚥";
          format-icons = [ "󰂎" "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          tooltip-format = "{timeTo} ({capacity}%)";
        };
        
        # Network
        network = {
          format-wifi = "󰖩";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪";
          format-linked = "󰈀";
          tooltip = true;
          tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ipaddr}";
          tooltip-format-ethernet = "{ifname}\n{ipaddr}";
          tooltip-format-disconnected = "Disconnected";
          on-click = "nm-connection-editor";
        };
        
        # Audio
        pulseaudio = {
          format = "{icon}";
          format-muted = "󰖁";
          format-icons = {
            headphone = "󰋋";
            hands-free = "󰋎";
            headset = "󰋎";
            phone = "";
            portable = "";
            car = "";
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          tooltip = true;
          tooltip-format = "{desc}: {volume}%";
          on-click = "pavucontrol";
          on-click-right = "pamixer -t";
          scroll-step = 5;
        };
        
        # System tray
        tray = {
          icon-size = 18;
          spacing = 10;
        };
      };
    };
    
    # ====================================================================
    # SCREENSHOT STYLE - Attached to left, colored workspace circles
    # ====================================================================
    style = ''
      /* ====== GENERAL ====== */
      * {
        font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free";
        font-size: 16px;
        min-height: 0;
        border: none;
        border-radius: 0;
      }
      
      /* ====== MAIN BAR ====== */
      window#waybar {
        background: #1d2021;
        border-radius: 0;
        color: #ebdbb2;
      }
      
      window#waybar.hidden {
        opacity: 0.2;
      }
      
      /* ====== TOOLTIPS ====== */
      tooltip {
        background: #282828;
        border: 2px solid #d65d0e;
        border-radius: 8px;
        color: #ebdbb2;
      }
      
      tooltip label {
        color: #ebdbb2;
        padding: 5px;
      }
      
      /* ====== NIXOS LOGO ====== */
      #custom-logo {
        font-size: 26px;
        color: #ffffff;
        padding: 14px 14px 14px 8px;
        margin-bottom: 8px;
      }
      
      #custom-logo:hover {
        color: #ebdbb2;
      }
      
      /* ====== WORKSPACES - Colored Circles ====== */
      #workspaces {
        background: transparent;
        padding: 5px 0;
      }
      
      #workspaces button {
        padding: 8px 0;
        margin: 3px 0;
        min-width: 28px;
        min-height: 28px;
        background: transparent;
        border-radius: 50%;
        transition: all 0.3s ease;
        font-size: 10px;
      }
      
      /* Inactive workspace - small colored circles */
      #workspaces button:nth-child(1) {
        color: #cc241d;  /* Red */
      }
      #workspaces button:nth-child(2) {
        color: #d79921;  /* Yellow */
      }
      #workspaces button:nth-child(3) {
        color: #98971a;  /* Green */
      }
      #workspaces button:nth-child(4) {
        color: #458588;  /* Blue */
      }
      #workspaces button:nth-child(5) {
        color: #b16286;  /* Purple */
      }
      #workspaces button:nth-child(6) {
        color: #689d6a;  /* Aqua */
      }
      #workspaces button:nth-child(7) {
        color: #d65d0e;  /* Orange */
      }
      #workspaces button:nth-child(8) {
        color: #83a598;  /* Light blue */
      }
      #workspaces button:nth-child(9) {
        color: #b8bb26;  /* Light green */
      }
      #workspaces button:nth-child(10) {
        color: #fb4934;  /* Light red */
      }
      
      /* Active workspace - bigger circle */
      #workspaces button.active {
        font-size: 18px;
        min-width: 32px;
        min-height: 32px;
        text-shadow: 0 0 8px currentColor;
      }
      
      /* Keep colors on active */
      #workspaces button.active:nth-child(1) { color: #fb4934; }
      #workspaces button.active:nth-child(2) { color: #fabd2f; }
      #workspaces button.active:nth-child(3) { color: #b8bb26; }
      #workspaces button.active:nth-child(4) { color: #83a598; }
      #workspaces button.active:nth-child(5) { color: #d3869b; }
      #workspaces button.active:nth-child(6) { color: #8ec07c; }
      #workspaces button.active:nth-child(7) { color: #fe8019; }
      #workspaces button.active:nth-child(8) { color: #83a598; }
      #workspaces button.active:nth-child(9) { color: #b8bb26; }
      #workspaces button.active:nth-child(10) { color: #fb4934; }
      
      #workspaces button:hover {
        text-shadow: 0 0 8px currentColor;
      }
      
      #workspaces button.urgent {
        animation: urgent-pulse 1s ease infinite;
      }
      
      @keyframes urgent-pulse {
        from { opacity: 1; }
        to { opacity: 0.5; }
      }
      
      /* ====== MODULES ====== */
      #clock,
      #cpu,
      #memory,
      #battery,
      #network,
      #pulseaudio {
        padding: 10px 0;
        margin: 4px 0;
        color: #a89984;
        background: transparent;
        transition: all 0.3s ease;
        font-size: 18px;
      }
      
      #tray {
        padding: 10px 0;
        margin: 8px 0;
        margin-bottom: 12px;
      }
      
      /* Module hover effects */
      #clock:hover,
      #cpu:hover,
      #memory:hover,
      #battery:hover,
      #network:hover,
      #pulseaudio:hover {
        color: #ebdbb2;
      }
      
      /* ====== CLOCK ====== */
      #clock {
        color: #ebdbb2;
        font-weight: bold;
        font-size: 13px;
        padding: 10px 0;
      }
      
      /* ====== CPU ====== */
      #cpu {
        color: #98971a;
      }
      
      /* ====== MEMORY ====== */
      #memory {
        color: #458588;
      }
      
      /* ====== BATTERY ====== */
      #battery {
        color: #689d6a;
      }
      
      #battery.good {
        color: #689d6a;
      }
      
      #battery.warning {
        color: #d79921;
      }
      
      #battery.critical {
        color: #cc241d;
        animation: blink 1s linear infinite;
      }
      
      #battery.charging {
        color: #b8bb26;
      }
      
      @keyframes blink {
        to {
          color: #ebdbb2;
        }
      }
      
      /* ====== NETWORK ====== */
      #network {
        color: #b16286;
      }
      
      #network.disconnected {
        color: #cc241d;
      }
      
      /* ====== AUDIO ====== */
      #pulseaudio {
        color: #83a598;
      }
      
      #pulseaudio.muted {
        color: #928374;
      }
      
      /* ====== TRAY ====== */
      #tray {
        padding: 5px 0;
      }
      
      #tray > .passive {
        -gtk-icon-effect: dim;
      }
      
      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        color: #d65d0e;
      }
    '';
  };
}
