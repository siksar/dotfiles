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
        cwd = { fg = "#c9a554"; }; 
        hovered = { fg = "#222222"; bg = "#c9a554"; };
        preview_hovered = { underline = true; };
        find_keyword = { fg = "#c9a554"; italic = true; };
        find_position = { fg = "#bb7744"; bg = "reset"; bold = true; };
        marker_selected = { fg = "#5f875f"; bg = "#5f875f"; };
        marker_copied = { fg = "#c9a554"; bg = "#c9a554"; };
        marker_cut = { fg = "#b36d43"; bg = "#b36d43"; };
        tab_active = { fg = "#222222"; bg = "#c9a554"; };
        tab_inactive = { fg = "#c2c2b0"; bg = "#2a2a2a"; };
        border_style = { fg = "#666666"; };
      };

      status = {
        separator_open = "";
        separator_close = "";
        separator_style = { fg = "#666666"; bg = "#666666"; };

        mode_normal = { fg = "#222222"; bg = "#c9a554"; bold = true; };
        mode_select = { fg = "#222222"; bg = "#bb7744"; bold = true; };
        mode_unset = { fg = "#222222"; bg = "#666666"; bold = true; };

        progress_label = { fg = "#c2c2b0"; bold = true; };
        progress_normal = { fg = "#c9a554"; bg = "#222222"; };
        progress_error = { fg = "#b36d43"; bg = "#222222"; };

        permissions_t = { fg = "#5f875f"; };
        permissions_r = { fg = "#c9a554"; };
        permissions_w = { fg = "#b36d43"; };
        permissions_x = { fg = "#5f875f"; };
        permissions_s = { fg = "#666666"; };
      };
      
      filetype = {
        rules = [
          { mime = "image/*"; fg = "#c9a554"; }
          { mime = "video/*"; fg = "#bb7744"; }
          { mime = "audio/*"; fg = "#c9a554"; }
          { mime = "application/zip"; fg = "#bb7744"; }
          { mime = "application/tar"; fg = "#bb7744"; }
          { mime = "application/java-archive"; fg = "#bb7744"; }
          { mime = "application/pdf"; fg = "#78824b"; }
          { name = "*"; is = "orphan"; fg = "#b36d43"; }
          { name = "*"; is = "exec"; fg = "#5f875f"; }
        ];
      };
    };
  };
}
