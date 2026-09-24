# Starship prompt (renkleri Stylix'ten gelir — elle renk verme).
{ ... }:

{
  programs.starship = {
    enable = true;
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
      # ── Logo geçmişi, iki adım ────────────────────────────────────────────
      # 1) Berserk damgası (elle çizilmiş ASCII resim) denendi, "oturmadı" —
      #    29 Tem'de builtin `nixos_small` kar tanesine dönüldü.
      # 2) 2 Eyl 2026: kullanıcı "ASCII tarzı nixos YAZAN" bir logo istedi. Bu
      #    öncekinden farklı bir şey: resim değil, YAZI sanatı. Aşağıdaki figlet
      #    `slant` fontuyla üretildi (pinlenmiş nixpkgs'ten:
      #    `nix build .#nixosConfigurations.nixos.pkgs.figlet` — registry'nin
      #    nixpkgs'ini çözeceği için `nix run nixpkgs#figlet` KULLANILMADI).
      #
      # type = "data" ŞART: `source` artık bir logo ADI değil, gömülü metin.
      # "builtin" veya varsayılan "auto" bırakılırsa fastfetch bu metni önce
      # kütüphanede arar, bulamaz, sonra dosya adı sanar ve logo TAMAMEN kaybolur
      # (hata vermeden). `data` ayrıca $1/$2 renk kodu ikamesi yapar — aşağıdaki
      # iki tonlu geçiş (üst satırlar mavi, alt satırlar camgöbeği) buna dayanıyor.
      #
      # Nix `''…''` dizesi bu sanat için GÜVENLİ, tesadüfen değil: içinde ne `${`
      # ne de `''` geçiyor; tek ters bölü (`\/`, `\_`, `\____`) indented string'de
      # zaten literaldir (kaçış yalnız `''\` ile başlar). Sanatı değiştirirsen bu
      # üç şeyi tekrar kontrol et.
      #
      # 27 sütun × 5 satır. Bu iki sayı aşağıdaki modül listesiyle BİRLİKTE
      # ayarlandı (bkz. oradaki "Yerleşim: A" notu) — sanatı değiştirirsen
      # bilgi satırı sayısını da gözden geçir, yoksa dikey ortalama kayar.
      logo = {
        type = "data";
        source = ''
          $1          _
          $1   ____  (_)  ______  _____
          $1  / __ \/ / |/_/ __ \/ ___/
          $2 / / / / />  </ /_/ (__  )
          $2/_/ /_/_/_/|_|\____/____/
        '';
        padding = {
          top = 2;
          left = 2;
          right = 4;
        };
        color = {
          "1" = "blue";
          "2" = "cyan";
        };
      };
      display = {
        separator = "  ";
        color.keys = "blue";
      };

      # ── Yerleşim: "A" — sol logo + ÇERÇEVESİZ liste (kullanıcı seçimi, 2 Eyl) ──
      # Önceki hâli 18 satırlık kutu çizgili bir panel'di (╭─ … ╰───) ve builtin
      # kar tanesi logosuyla dengeliydi. Yazı logosuna geçince o denge bozuldu:
      # 5 satırlık wordmark'ın yanında 13 satır boşlukta sarkıyordu.
      #
      # fastfetch showcase'i (Discussion #971) + gerçek dotfiles tarandı; iki
      # yerleşik desen var ve İKİSİ DE bu dengeyi zorunlu tutuyor:
      #   1. Sol logo kullananların HEPSİ sanatı panel yüksekliğine kadar uzatıyor.
      #   2. Kısa sanat kullananlar paneli de kısaltıp çerçeveyi TAMAMEN atıyor
      #      ve `break` modülleriyle dikey ortalama yapıyor (ashish0kumar deseni).
      # Seçilen 2. desen. Bu yüzden `{#separator}│ …` önekleri ve ╭╰ satırları
      # gitti — anahtar artık yalnız bir Nerd Font ikonu, etiket metni bile yok.
      #
      # BAŞTAKİ VE SONDAKİ `break` DEKORATİF DEĞİL: logonun `padding.top = 2`
      # değeriyle birlikte bilgi bloğunu logoya göre dikey ortalayan şey onlar.
      # Modül eklersen/çıkarırsan ortalama kayar — logoyu 5 satır kabul edip
      # bilgi satırı sayısını 9 civarında tut.
      #
      # DÜŞÜRÜLEN SATIRLAR (bilinçli, denge için): Terminal, GPU, ve
      # Sistem/Donanım/Oturum alt başlıkları. Geri istenirse her biri bir satır.
      modules = [
        "break"
        {
          type = "title";
          format = "{#1}{user-name}{#}@{#1}{host-name}";
        }
        {
          type = "os";
          key = "󱄅 ";
        }
        {
          type = "kernel";
          key = "󰌢 ";
        }
        {
          type = "wm";
          key = "󰧨 ";
        }
        {
          type = "shell";
          key = "󱆃 ";
        }
        {
          type = "memory";
          key = "󰍛 ";
        }
        {
          type = "uptime";
          key = "󰅐 ";
        }
        "break"
        {
          type = "colors";
          symbol = "circle";
        }
      ];
    };
  };

  # ── Fastfetch açılışta — İKİ kabuk için, ikisi de BURADA ────────────────────
  # Aynı kararın iki evi olmasın diye fish tarafı da bu dosyada duruyor
  # (home/shell/fish.nix'te yalnız bir işaret yorumu var). programs.fish
  # .interactiveShellInit `types.lines`, yani fish.nix'teki tanımla çakışmadan
  # birleşir.
  #
  # 2 Eyl 2026'ya kadar SADECE bash tarafı vardı ve giriş kabuğu fish olduğu için
  # fastfetch terminal açılışında HİÇ ÇALIŞMIYORDU (sessizce — hata yok, çıktı yok).
  programs.bash.initExtra = ''
    if [[ $- == *i* ]] && [ "$SHLVL" -eq 1 ] && [ -z "$SSH_CONNECTION" ] \
       && [ -n "$WAYLAND_DISPLAY$DISPLAY" ]; then
      command -v fastfetch >/dev/null && fastfetch
    fi
  '';

  # fish karşılığı. `status is-interactive` guard'ı GEREKMİYOR: HM üretilen
  # config.fish'te interactiveShellInit'i zaten `status is-interactive; and
  # begin … end` içine sarıyor (doğrulandı).
  #
  # SHLVL GUARD'I BİLEREK TAŞINMADI — bash'ten kopyalamak sessiz bir hata olurdu.
  # Ölçüldü (fish 4.8.1, 2 Eyl 2026):
  #     SHLVL yokken   bash → 1    fish → BOŞ
  #     SHLVL=1 iken   bash → 2    fish → 1
  #     iç içe                      fish → 1  (hiç artmıyor)
  # Yani fish SHLVL'e DOKUNMUYOR, yalnız miras alıyor. Sonuç iki yönlü kötü:
  #   1. İç içe fish'i yakalayamaz — guard'ın tek amacı buydu, işe yaramıyor.
  #   2. SHLVL tanımsız gelen bir başlatma yolunda `test "" -eq 1` hata verir ve
  #      fastfetch TAMAMEN susar — düzeltmeye çalıştığımız hatanın aynısı.
  # Gerçek terminallerde ölçülen değer 1 (cosmic-term ve ghostty; SDDM'in
  # başlattığı login fish'ten miras). Yani guard olsa da bir şey kazandırmazdı.
  programs.fish.interactiveShellInit = ''
    if test -z "$SSH_CONNECTION"
        and test -n "$WAYLAND_DISPLAY$DISPLAY"
        and command -q fastfetch
        fastfetch
    end
  '';
}
