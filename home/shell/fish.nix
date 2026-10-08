{ pkgs, ... }:

{
  programs.fish = {
    enable = true;

    shellAbbrs = {
      nb = "nh os switch";
      # hms burada YOK: home.nix'teki home.shellAliases.hms HM tarafından fish'e
      # de alias olarak iniyor; abbr kopyası aynı komutun ikinci eviydi.
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
      # `y` (yazi: çıkınca son dizine cd) burada YAZILMIYOR — HM'in yazi modülü
      # onu kendisi tanımlıyor (shellWrapperName = "y", stateVersion 26.05).
      # functions.<ad> `lines` tipinde olduğundan elle yazılan ikinci gövde HATA
      # VERMEDEN birleşiyordu: `y` yazinca yazi arka arkaya İKİ KEZ açılıyordu
      # (24 Eyl 2026, programs.fish.functions.y eval'iyle görüldü).

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

  # starship/zoxide/fzf'nin fish entegrasyonu AYRICA açılmıyor: HM'de her
  # enable*Integration seçeneğinin varsayılanı home.shell.enable*Integration
  # (= true). Açıkça yazmak drvPath'i değiştirmiyordu (24 Eyl 2026, ölçüldü).
  programs.zoxide.enable = true;
  programs.fzf.enable = true;

  home.packages = with pkgs; [ eza fd ripgrep bat duf ];
}
