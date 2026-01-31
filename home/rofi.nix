{ config, pkgs, lib, ... }:
{
  # ========================================================================
  # ROFI - Application Launcher with Gruvbox Theme
  # ========================================================================
  
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;  # rofi-wayland merged into rofi in 25.11
    font = "JetBrainsMono Nerd Font 12";
    terminal = "${pkgs.kitty}/bin/kitty";
    
    extraConfig = {
      modi = "drun,run,window,filebrowser";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      drun-display-format = "{name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = " Apps";
      display-run = " Run";
      display-window = " Windows";
      display-filebrowser = " Files";
      sidebar-mode = false;
    };
    
    theme = let
      inherit (config.lib.formats.rasi) mkLiteral;
    in {
      # Gruvbox Colors
      "*" = {
        bg = mkLiteral "#282828";
        bg-alt = mkLiteral "#3c3836";
        bg-sel = mkLiteral "#504945";
        fg = mkLiteral "#ebdbb2";
        fg-alt = mkLiteral "#a89984";
        accent = mkLiteral "#d65d0e";  # Gruvbox Orange (matches rice)
        urgent = mkLiteral "#cc241d";
        
        background-color = mkLiteral "@bg";
        text-color = mkLiteral "@fg";
      };
      
      window = {
        width = mkLiteral "600px";
        border = mkLiteral "0px";
        border-color = mkLiteral "transparent";
        border-radius = mkLiteral "12px";
        padding = mkLiteral "0";
        background-color = mkLiteral "@bg";
      };
      
      mainbox = {
        padding = mkLiteral "20px";
        background-color = mkLiteral "transparent";
      };
      
      inputbar = {
        children = mkLiteral "[prompt, entry]";
        padding = mkLiteral "12px 15px";
        margin = mkLiteral "0 0 15px 0";
        background-color = mkLiteral "@bg-alt";
        border = mkLiteral "0px";
        border-color = mkLiteral "transparent";
        border-radius = mkLiteral "10px";
      };
      
      prompt = {
        padding = mkLiteral "0 10px 0 0";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@accent";
      };
      
      entry = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";
        placeholder = "Search...";
        placeholder-color = mkLiteral "@fg-alt";
      };
      
      listview = {
        columns = 1;
        lines = 8;
        scrollbar = false;
        fixed-height = true;
        background-color = mkLiteral "transparent";
        spacing = mkLiteral "5px";
      };
      
      element = {
        padding = mkLiteral "12px";
        background-color = mkLiteral "transparent";
        border-radius = mkLiteral "8px";
      };
      
      "element normal.normal" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";
      };
      
      "element normal.active" = {
        background-color = mkLiteral "@bg-sel";
        text-color = mkLiteral "@accent";
      };
      
      "element selected.normal" = {
        background-color = mkLiteral "@bg-sel";
        text-color = mkLiteral "@fg";
      };
      
      "element selected.active" = {
        background-color = mkLiteral "@bg-sel";
        text-color = mkLiteral "@fg";
      };
      
      "element alternate.normal" = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";
      };
      
      element-icon = {
        size = mkLiteral "28px";
        margin = mkLiteral "0 15px 0 0";
        background-color = mkLiteral "transparent";
      };
      
      element-text = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
      };
      
      message = {
        padding = mkLiteral "10px";
        background-color = mkLiteral "@bg-alt";
        border-radius = mkLiteral "8px";
      };
      
      textbox = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@fg";
      };
    };
  };
  
  # ========================================================================
  # ROFI SCRIPTS
  # ========================================================================
  
  # Power menu script
  home.file.".config/rofi/scripts/powermenu.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      
      # Gruvbox themed power menu
      
      uptime=$(uptime -p | sed 's/up //')
      
      shutdown="󰐥 Shutdown"
      reboot="󰜉 Reboot"
      suspend="󰤄 Suspend"
      lock="󰌾 Lock"
      logout="󰗼 Logout"
      
      options="$lock\n$suspend\n$logout\n$reboot\n$shutdown"
      
      selected=$(echo -e "$options" | rofi -dmenu \
        -p "  Uptime: $uptime" \
        -mesg "What do you want to do?" \
        -theme-str 'window {width: 350px;} listview {lines: 5;}')
      
      case "$selected" in
        $shutdown)
          systemctl poweroff
          ;;
        $reboot)
          systemctl reboot
          ;;
        $suspend)
          systemctl suspend
          ;;
        $lock)
          hyprlock
          ;;
        $logout)
          hyprctl dispatch exit
          ;;
      esac
    '';
  };
  
  # Window switcher helper
  home.file.".config/rofi/scripts/windows.sh" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      rofi -show window -theme-str 'window {width: 500px;}'
    '';
  };
  
  # ========================================================================
  # ROFIMOJI - Emoji Picker
  # ========================================================================
  home.packages = with pkgs; [
    rofimoji
  ];
  
  home.file.".config/rofimoji.rc".text = ''
    action = copy
    skin-tone = neutral
    selector = rofi
    clipboarder = wl-copy
    typer = wtype
    files = [emojis, math]
  '';
}
