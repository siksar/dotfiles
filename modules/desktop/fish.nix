# fish kabuğu (vyrx-dev/dotfiles portu, eskiden sway rice'a bağlıydı).
# users.nix'te users.users.zixar.shell = pkgs.fish (sistem katmanı, login shell).
{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      # NixOS iş akışı (vyrx'in pacman/paru'sunun karşılığı)
      nb = "nh os switch";
      hms = "nh home switch -b hm-backup";
      ngc = "nh clean all";
      nsh = "nix shell nixpkgs#";
      nfu = "nix flake update";

      # Dosya/dizin (eza)
      ls = "eza --icons";
      l = "eza --icons -l";
      ll = "eza --icons -la";
      lt = "eza --icons --tree";

      # git
      lg = "lazygit";
      gs = "git status";
      gp = "git pull";

      # Uygulamalar
      zz = "yazi";
      open = "nautilus .";
      c = "codium .";
      rip = "yt-dlp -x --audio-format mp3";
      t = "topgrade";
    };

    shellAliases = {
      cat = "bat";
      find = "fd";
      grep = "rg";
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
