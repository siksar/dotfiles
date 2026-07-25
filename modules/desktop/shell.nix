{ ... }:

{
  programs.starship = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";

      directory = {
        style = "bold blue";
        truncation_length = 4;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
        style = "purple";
        format = "[$symbol$branch]($style) ";
      };

      git_status = {
        style = "yellow";
        format = "[$all_status$ahead_behind]($style)";
      };

      nix_shell = {
        symbol = " ";
        style = "cyan";
        format = "[$symbol$state]($style) ";
      };

      cmd_duration = {
        min_time = 2000;
        style = "yellow";
        format = "[ $duration]($style) ";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold cyan)";
      };
    };
  };

  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "nixos_small";
        padding = { top = 1; left = 2; right = 3; };
        # ANSI renkleri: tema geçişinde logo da boyanır
        color = { "1" = "blue"; "2" = "cyan"; };
      };
      display = {
        separator = "  ";
        color = { keys = "blue"; };
      };
      modules = [
        { type = "os"; key = "󱄅"; }
        { type = "kernel"; key = ""; }
        { type = "wm"; key = ""; }
        { type = "terminal"; key = ""; }
        { type = "uptime"; key = "󰅐"; }
        { type = "memory"; key = "󰍛"; }
        "break"
        { type = "colors"; paddingLeft = 4; symbol = "circle"; }
      ];
    };
  };

  # Fastfetch her yeni terminalde (iç içe kabuklarda ve SSH'ta değil).
  programs.bash.initExtra = ''
    if [[ $- == *i* ]] && [ "$SHLVL" -eq 1 ] && [ -z "$SSH_CONNECTION" ] \
       && [ -n "$WAYLAND_DISPLAY$DISPLAY" ]; then
      command -v fastfetch >/dev/null && fastfetch
    fi
  '';
}
