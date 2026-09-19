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
      # codium Eylül 2026'da ağaçtan çıktı; kurulu tek editör nvim.
      c = "nvim .";
      # eskiden `rip` idi — home/apps/streamrip.nix eklendikten sonra çakıştı:
      # fish abbr komut pozisyonundaki kelimeyi ÇALIŞTIRILMADAN ÖNCE genişletir,
      # yani `rip <url>` yazınca streamrip'in `rip` binary'sine hiç sıra
      # gelmeden bu abbr'a dönüşüyordu (13 Eyl 2026).
      ytmp3 = "yt-dlp -x --audio-format mp3";
      t = "topgrade";
    };

    shellAliases = {
      cat = "bat";
      find = "fd";
      grep = "rg";
      # ağır iş → tüm 16 CPU. system/kernel/cores.nix masaüstünü VARSAYILAN
      # Zen5c'ye (verimlilik) kilitler; bu, o maskeyi bilinçli delmenin tek
      # görünür yolu. Kullanım: aia ffmpeg -i … / aia cargo build
      aia = "taskset -c 0-15";
    };

    # DİKKAT: bu seçeneğin İKİNCİ bir tanımı home/shell/starship.nix'te var —
    # açılıştaki fastfetch çağrısı. `types.lines` olduğu için ikisi birleşir,
    # çakışma yok. Fastfetch'i burada arama; bash karşılığıyla yan yana dursun
    # diye bilerek orada (aynı kararın iki evi olmasın).
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

      # streamrip'in `rip` binary'sini sarmalar (fonksiyon isim çakışmasında
      # PATH'teki binary'den önce çalışır — `command rip` en altta gerçek
      # binary'ye düşer). GEREKÇE: Deezer'ın paylaş linki (`link.deezer.com/s/…`)
      # streamrip'in parse_url.py regex'inde tanınmıyor — deezer.page.link/
      # dzr.page.link'i tanıyor, link.deezer.com'u tanımıyor ("Found invalid
      # url … skipping", 13 Eyl 2026, streamrip 2.2.0). Argümanlar arasında
      # böyle bir link varsa gerçek deezer.com URL'sine çözüp öyle iletir;
      # geri kalan her şey (config, search, id, …) değişmeden geçer.
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
