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
      # Berserk damgası denemesi (elle ASCII) oturmadı — kullanıcı isteğiyle
      # fastfetch'in kendi builtin kütüphanesindeki NixOS logosuna dönüldü
      # (29 Tem). `fastfetch --list-logos` çıktısında "NixOS"/"NixOS_small"
      # aynı 49 sütunluk kar tanesi sanatına çözülüyor (bu sürümde ikisi de
      # özdeş) — isim büyük/küçük harfe duyarsız.
      logo = {
        source = "nixos_small";
        padding = {
          top = 1;
          left = 2;
          right = 3;
        };
        color = {
          "1" = "blue";
          "2" = "cyan";
        };
      };
      display = {
        separator = "  ";
        color = {
          keys = "blue";
          separator = "blue";
        };
      };
      modules = [
        {
          type = "title";
          format = "{#1}╭─ {#}{user-name-colored}{#1} ─────────────────";
        }

        {
          type = "custom";
          format = "{#1}│ {#}Sistem";
        }
        {
          type = "os";
          key = "{#separator}│  {#keys}󱄅 OS";
        }
        {
          type = "kernel";
          key = "{#separator}│  {#keys} Kernel";
        }
        {
          type = "wm";
          key = "{#separator}│  {#keys} WM";
        }
        {
          type = "shell";
          key = "{#separator}│  {#keys}󱆃 Kabuk";
        }
        {
          type = "terminal";
          key = "{#separator}│  {#keys} Terminal";
        }
        {
          type = "custom";
          format = "{#1}│";
        }

        {
          type = "custom";
          format = "{#1}│ {#}Donanım";
        }
        {
          type = "cpu";
          key = "{#separator}│  {#keys}󰻠 CPU";
        }
        {
          type = "gpu";
          key = "{#separator}│  {#keys}󰢮 GPU";
        }
        {
          type = "memory";
          key = "{#separator}│  {#keys}󰍛 Bellek";
        }
        {
          type = "custom";
          format = "{#1}│";
        }

        {
          type = "custom";
          format = "{#1}│ {#}Oturum";
        }
        {
          type = "uptime";
          key = "{#separator}│  {#keys}󰅐 Açık kalma";
        }
        {
          type = "custom";
          format = "{#1}│";
        }

        {
          type = "colors";
          key = "{#separator}│";
          symbol = "circle";
        }

        {
          type = "custom";
          format = "{#1}╰─────────────────────────────╯";
        }
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
