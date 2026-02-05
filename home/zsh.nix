{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    
    shellAliases = {
      ll = "ls -la --color=auto";
      la = "ls -A --color=auto";
      l = "ls -CF --color=auto";
      
      # NixOS
      rebuild = "cd /etc/nixos && git add . && git commit -m 'auto' || true && sudo nixos-rebuild switch --flake .#nixos";
      zixswitch = "cd /etc/nixos && git add . && git commit -m 'home' || true && home-manager switch --flake .#zixar -b backup";
      fullrebuild = "rebuild && zixswitch";
      cleanup = "sudo nix-collect-garbage -d && sudo nix-store --optimize";
      
      # Editors
      v = "nvim";
      vim = "nvim";
      
      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline -10";
      
      # Apps
      hypr = "nvim ~/.config/hypr/hyprland.conf";
    };

    initContent = ''
      if [[ -z $FASTFETCH_RAN ]]; then
        export FASTFETCH_RAN=1
        fastfetch
      fi
      
      mkcd() { mkdir -p "$1" && cd "$1"; }
      extract() {
        if [ -f "$1" ]; then
          case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz)  tar xzf "$1" ;;
            *.tar.xz)  tar xJf "$1" ;;
            *.bz2)     bunzip2 "$1" ;;
            *.gz)      gunzip "$1" ;;
            *.tar)     tar xf "$1" ;;
            *.zip)     unzip "$1" ;;
            *.7z)      7z x "$1" ;;
            *)         echo "'$1' cannot be extracted" ;;
          esac
        else
          echo "'$1' is not a valid file"
        fi
      }
    '';
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    
    settings = {
      format = "[](#d65d0e)$os$username[](bg:#d79921 fg:#d65d0e)$directory[](fg:#d79921 bg:#689d6a)$git_branch$git_status[](fg:#689d6a bg:#458588)$c$elixir$elm$golang$gradle$haskell$java$julia$nodejs$nim$rust$scala[](fg:#458588 bg:#b16286)$docker_context[](fg:#b16286)\\n$character";

      os = {
        disabled = false;
        style = "bg:#d65d0e fg:#fbf1c7";
      };

      "os.symbols" = {
        Windows = " ";
        Ubuntu = " ";
        Macos = " ";
        Alpine = " ";
        Arch = " ";
        Debian = " ";
        EndeavourOS = " ";
        Fedora = " ";
        FreeBSD = " ";
        Gentoo = " ";
        Linux = " ";
        Manjaro = " ";
        Mint = " ";
        NixOS = " ";
        OpenBSD = " ";
        Pop = " ";
        Raspbian = " ";
        Redhat = " ";
        RedHatEnterprise = " ";
        SUSE = " ";
        Unknown = " ";
      };

      username = {
        show_always = false;
        style_user = "bg:#d65d0e fg:#fbf1c7";
        style_root = "bg:#d65d0e fg:#fbf1c7";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:#282828 bg:#d79921";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = "…/";
      };
      
      "directory.substitutions" = {
        "Documents" = " ";
        "Downloads" = " ";
        "Music" = " ";
        "Pictures" = " ";
      };

      git_branch = {
        symbol = "";
        style = "bg:#689d6a";
        format = "[[ $symbol $branch ](fg:#282828 bg:#689d6a)]($style)";
      };

      git_status = {
        style = "bg:#689d6a";
        format = "[[($all_status$ahead_behind )](fg:#282828 bg:#689d6a)]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:#458588";
        format = "[[ $symbol ($version) ](fg:#fbf1c7 bg:#458588)]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:#458588";
        format = "[[ $symbol ($version) ](fg:#fbf1c7 bg:#458588)]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:#458588";
        format = "[[ $symbol ($version) ](fg:#fbf1c7 bg:#458588)]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:#b16286";
        format = "[[ $symbol $context ](fg:#fbf1c7 bg:#b16286)]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:#b16286";
        format = "[[  $time ](fg:#fbf1c7 bg:#b16286)]($style)";
      };

      character = {
        success_symbol = "[➜](bold #d65d0e)";
        error_symbol = "[➜](bold #cc241d)";
      };
    };
  };
}
