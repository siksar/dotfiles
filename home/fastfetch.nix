{ config, pkgs, lib, ... }:
{
  # ========================================================================
  # FASTFETCH - Fast System Information Tool
  # ========================================================================
  
  programs.fastfetch = {
    enable = true;
    
    settings = {
      logo = {
        type = "auto";
        color = {
          "1" = "blue";
          "2" = "white";
        };
      };
      
      display = {
        separator = " → ";
        color = {
          keys = "blue";
          title = "magenta";
        };
      };
      
      modules = [
        {
          type = "title";
          format = "{user-name}@{host-name}";
        }
        {
          type = "separator";
          string = "─";
        }
        {
          type = "os";
          key = " OS";
        }
        {
          type = "host";
          key = "󰌢 Host";
        }
        {
          type = "kernel";
          key = " Kernel";
        }
        {
          type = "uptime";
          key = " Uptime";
        }
        {
          type = "packages";
          key = "󰏖 Packages";
        }
        {
          type = "shell";
          key = " Shell";
        }
        {
          type = "wm";
          key = " WM";
        }
        {
          type = "terminal";
          key = " Terminal";
        }
        {
          type = "terminalfont";
          key = " Font";
        }
        {
          type = "cpu";
          key = " CPU";
        }
        {
          type = "gpu";
          key = "󰢮 GPU";
          hideType = "integrated";
        }
        {
          type = "memory";
          key = "󰍛 Memory";
        }
        {
          type = "disk";
          key = "󰋊 Disk";
          folders = "/";
        }
        {
          type = "battery";
          key = "󰁹 Battery";
        }
        {
          type = "separator";
          string = "─";
        }
        {
          type = "colors";
          paddingLeft = 2;
          symbol = "circle";
        }
      ];
    };
  };
  
  # Remove macchina if it was previously installed
  home.packages = lib.mkAfter [
    pkgs.fastfetch
  ];
}
