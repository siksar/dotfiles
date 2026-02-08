{ config, pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = false;
    enableNushellIntegration = true;
    shellWrapperName = "y";

    settings = {
      mgr = {
        show_hidden = false;
        sort_by = "alphabetical";
        sort_sensitive = false;
        sort_reverse = false;
        sort_dir_first = true;
        linemode = "none";
        show_symlink = true;
      };

      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        cache_dir = "${config.xdg.cacheHome}";
        image_filter = "lanczos3";
        image_quality = 90;
        sixel_fraction = 15;
      };
    };

    theme = {
      mgr = {
        cwd = { fg = "#d79921"; }; 
        hovered = { fg = "#282828"; bg = "#d79921"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "#d79921"; italic = true; };
        find_position = { fg = "#b16286"; bg = "reset"; bold = true; };
        marker_selected = { fg = "#98971a"; bg = "#98971a"; };
        marker_copied = { fg = "#d79921"; bg = "#d79921"; };
        marker_cut = { fg = "#cc241d"; bg = "#cc241d"; };
        tab_active = { fg = "#282828"; bg = "#a89984"; };
        tab_inactive = { fg = "#a89984"; bg = "#3c3836"; };
        border_style = { fg = "#504945"; };
      };

      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "#504945"; bg = "#504945"; };

        mode_normal = { fg = "#282828"; bg = "#d79921"; bold = true; };
        mode_select = { fg = "#282828"; bg = "#b16286"; bold = true; };
        mode_unset = { fg = "#282828"; bg = "#928374"; bold = true; };

        progress_label = { fg = "#ebdbb2"; bold = true; };
        progress_normal = { fg = "#458588"; bg = "#3c3836"; };
        progress_error = { fg = "#cc241d"; bg = "#3c3836"; };

        permissions_t = { fg = "#458588"; };
        permissions_r = { fg = "#d79921"; };
        permissions_w = { fg = "#cc241d"; };
        permissions_x = { fg = "#98971a"; };
        permissions_s = { fg = "#665c54"; };
      };
      
      filetype = {
        rules = [
          { mime = "image/*"; fg = "#d3869b"; }
          { mime = "video/*"; fg = "#b16286"; }
          { mime = "audio/*"; fg = "#d79921"; }
          { mime = "application/zip"; fg = "#b16286"; }
          { mime = "application/tar"; fg = "#b16286"; }
          { mime = "application/java-archive"; fg = "#b16286"; }
          { mime = "application/pdf"; fg = "#458588"; }
          { name = "*"; is = "orphan"; fg = "#cc241d"; }
          { name = "*"; is = "exec"; fg = "#98971a"; }
        ];
      };
    };
  };
}
