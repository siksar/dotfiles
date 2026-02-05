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
      v = "hx";
      vim = "hx";
      
      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline -10";
      
      # Apps
      hypr = "hx ~/.config/hypr/hyprland.conf";
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
}
