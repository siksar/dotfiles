{ config, pkgs, lib, caelstia, ... }:
{
  # ========================================================================
  # CAELSTIA SHELL - Modern Wayland Desktop Shell
  # ========================================================================
  
  imports = [ caelstia.homeManagerModules.default ];
  
  programs.caelestia = {
    enable = true;
    
    # ====================================================================
    # SETTINGS (Imperative / GUI Managed)
    # ====================================================================
    # Leaving settings empty/minimal to allow GUI management as requested.
    settings = {
      # Basic defaults to ensure startup
      general = {
        language = "tr";
      };
      
      # Lock Screen Configuration (Replacing Hyprlock)
      lockScreen = {
        enabled = true;
        background = "screenshot"; # Or wallpaper
        blur = true;
      };
      
      # ==================================================================
      # TEMPLATES - Declarative Integration
      # ==================================================================
      templates = {
        enableUserTheming = true;
        activeTemplates = [
          "kitty"
          "gtk"
          "qt"
          "niri"
          "hyprland" # For socket integration
          # "hyprlock" # Disabled as we use Caelstia's lock screen
          "starship" # Assuming starship template exists
          "rofi"
          "waybar"
          "dunst"
          "btop"
          "vscode"
          "zen"
        ];
      };
      
      # User Templates Configuration (Paths)
      # Adapting from Noctalia's paths to Caelstia's (assuming similar structure)
      user-templates = {
        templates = {
          kitty = {
            input_path = "${config.home.homeDirectory}/.config/caelstia/templates/kitty.conf";
            output_path = "${config.home.homeDirectory}/.config/kitty/caelstia-theme.conf";
            post_hook = "killall -SIGUSR1 kitty";
          };
          starship = {
            input_path = "${config.home.homeDirectory}/.config/caelstia/templates/starship.toml";
            output_path = "${config.home.homeDirectory}/.config/caelstia/generated/starship.toml";
          };
          gtk3 = {
            input_path = "${config.home.homeDirectory}/.config/caelstia/templates/gtk3.css";
            output_path = "${config.home.homeDirectory}/.config/caelstia/generated/gtk3.css";
          };
          gtk4 = {
            input_path = "${config.home.homeDirectory}/.config/caelstia/templates/gtk4.css";
            output_path = "${config.home.homeDirectory}/.config/caelstia/generated/gtk4.css";
          };
          niri = {
            input_path = "${config.home.homeDirectory}/.config/niri/config.kdl";
            output_path = "${config.home.homeDirectory}/.config/niri/caelstia.kdl";
          };
        };
      };
    };
  };

  # ========================================================================
  # TEMPLATE FILES - Default templates
  # ========================================================================
  # We create these initial templates so Caelstia has something to work with.
  # Using the same logic as Noctalia for compatibility.

  xdg.configFile."caelstia/templates/kitty.conf".text = ''
    # Caelstia Template - Kitty Theme
    foreground {{foreground}}
    background {{background}}
    selection_foreground {{foreground}}
    selection_background {{primary}}
    cursor {{primary}}
    cursor_text_color {{background}}
    url_color {{secondary}}
    active_border_color {{primary}}
    inactive_border_color {{outline}}
    bell_border_color {{error}}
    active_tab_foreground {{onPrimary}}
    active_tab_background {{primary}}
    inactive_tab_foreground {{onSurfaceVariant}}
    inactive_tab_background {{surfaceVariant}}
    color0 {{surface}}
    color8 {{outline}}
    color1 {{error}}
    color9 {{error}}
    color2 {{tertiary}}
    color10 {{tertiary}}
    color3 {{secondary}}
    color11 {{secondary}}
    color4 {{primary}}
    color12 {{primary}}
    color5 {{tertiary}}
    color13 {{tertiary}}
    color6 {{secondary}}
    color14 {{secondary}}
    color7 {{onSurface}}
    color15 {{onSurface}}
  '';
  
  xdg.configFile."caelstia/templates/starship.toml".text = ''
    # Caelstia Template - Starship Prompt
    # (Simplified for Caelstia)
    format = """
    $directory\
    $git_branch\
    $git_status\
    $time\
    $line_break$character"""

    [directory]
    style = "fg:{{onSecondary}} bg:{{secondary}}"
    format = "[ $path ]($style)"

    [git_branch]
    style = "bg:{{tertiary}}"
    format = "[[ $symbol $branch ](fg:{{onTertiary}} bg:{{tertiary}})]($style)"

    [character]
    success_symbol = "[❯](bold {{primary}})"
    error_symbol = "[❯](bold {{error}})"
  '';

  xdg.configFile."caelstia/templates/gtk3.css".text = ''
    /* Caelstia Template - GTK3 Colors */
    @define-color accent_color {{primary}};
    @define-color accent_bg_color {{primary}};
    @define-color window_bg_color {{background}};
    @define-color window_fg_color {{foreground}};
  '';

  xdg.configFile."caelstia/templates/gtk4.css".text = ''
    /* Caelstia Template - GTK4 Colors */
    @define-color accent_color {{primary}};
    @define-color accent_bg_color {{primary}};
    @define-color window_bg_color {{background}};
    @define-color window_fg_color {{foreground}};
  '';

  # Create generated directory
  xdg.configFile."caelstia/generated/.keep".text = "";
}
