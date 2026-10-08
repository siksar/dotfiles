{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      nb = "nh os switch";
      hms = "nh home switch -b hm-backup";
      ngc = "nh clean all";
      nsh = "nix shell nixpkgs#";
      nfu = "nix flake update";

      ls = "eza --icons";
      l = "eza --icons -l";
      ll = "eza --icons -la";
      lt = "eza --icons --tree";

      lg = "lazygit";
      gs = "git status";
      gp = "git pull";

      zz = "yazi";
      open = "nautilus .";
      c = "nvim .";
      # `rip` streamrip binary'siyle çakışıyordu (abbr önce genişler).
      ytmp3 = "yt-dlp -x --audio-format mp3";
      t = "topgrade";
    };

    shellAliases = {
      cat = "bat";
      find = "fd";
      grep = "rg";
      # cores.nix Zen5c maskesini bilinçli deler.
      aia = "taskset -c 0-15";
    };

    interactiveShellInit = ''
      set fish_greeting
    '';

    functions = {
      y = ''
        # yazi: çıkarken en son bulunduğun dizine cd'le
        set tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set cwd (cat -- "$tmp"); and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
          cd -- "$cwd"
        end
        rm -f -- "$tmp"
      '';

      # rip sarmalayıcı: streamrip link.deezer.com/s/… linkini tanımıyor → gerçek URL'ye çözer.
      rip = ''
        set -l resolved
        for a in $argv
          if string match -q '*link.deezer.com/s/*' -- $a
            set -a resolved (${pkgs.curl}/bin/curl -sIL -o /dev/null -w '%{url_effective}' -- $a)
          else
            set -a resolved $a
          end
        end
        command rip $resolved
      '';
    };
  };

  programs.starship.enableFishIntegration = true;
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
  };

  home.packages = with pkgs; [ eza fd ripgrep bat duf ];
}
