# ============================================================================
# ZSH + STARSHIP YAPILANDIRMASI
# ============================================================================
# Bu dosya ZSH shell ve Starship prompt özelleştirmelerini içerir.
# Her bölüm detaylı Türkçe açıklamalarla dokümante edilmiştir.
#
# İÇİNDEKİLER:
# 1. ZSH Temel Ayarları
# 2. Shell Kısayolları (Aliases)
# 3. Başlangıç Kodları (initContent)
# 4. Starship Prompt Özelleştirme
# ============================================================================

{ config, pkgs, ... }:

{
  # ==========================================================================
  # ZSH TEMEL AYARLARI
  # ==========================================================================
  # ZSH, Bash'e alternatif güçlü bir shell'dir.
  # Daha iyi otomatik tamamlama, eklenti desteği ve özelleştirme sunar.
  # ==========================================================================
  
  programs.zsh = {
    # ------------------------------------------------------------------------
    # enable = true
    # ------------------------------------------------------------------------
    # ZSH'ı aktifleştirir. Home Manager ZSH için gerekli dosyaları oluşturur:
    # - ~/.zshrc (ana konfigürasyon)
    # - ~/.zshenv (environment variables)
    # ------------------------------------------------------------------------
    enable = true;
    
    # ------------------------------------------------------------------------
    # enableCompletion = true
    # ------------------------------------------------------------------------
    # TAB tuşuyla otomatik tamamlamayı aktifleştirir.
    # Örnek: "cd Doc" yazıp TAB'a basınca "cd Documents/" olur.
    # Komutlar, dosya yolları ve argümanlar için çalışır.
    # ------------------------------------------------------------------------
    enableCompletion = true;
    
    # ------------------------------------------------------------------------
    # autosuggestion.enable = true
    # ------------------------------------------------------------------------
    # Yazarken geçmiş komutlardan gri tonunda öneri gösterir.
    # Sağ ok tuşu (→) ile öneriyi kabul edebilirsin.
    # Örnek: "git" yazdığında "git status" önerebilir (eğer sık kullanıyorsan)
    # ------------------------------------------------------------------------
    autosuggestion.enable = true;
    
    # ------------------------------------------------------------------------
    # syntaxHighlighting.enable = true
    # ------------------------------------------------------------------------
    # Komutları yazarken renklendirme yapar:
    # - Geçerli komutlar: YEŞİL
    # - Geçersiz/yanlış komutlar: KIRMIZI
    # - Dizeler (quotes içi): SARI
    # - Yollar: MAVİ/CYAN
    # Hata yapmadan önce görsel geri bildirim sağlar!
    # ------------------------------------------------------------------------
    syntaxHighlighting.enable = true;
    
    # ========================================================================
    # SHELL KISAYOLLARI (ALIASES)
    # ========================================================================
    # Alias = Kısayol komut. Uzun komutları kısa hale getirir.
    # Örnek: "ll" yazmak "ls -la --color=auto" yazmakla aynı.
    # 
    # Format: alias-adı = "gerçek komut";
    # ========================================================================
    shellAliases = {
      # ----------------------------------------------------------------------
      # DOSYA LİSTELEME
      # ----------------------------------------------------------------------
      # ls komutunun çeşitli varyasyonları
      ll = "ls -la --color=auto";    # Uzun format + gizli dosyalar
      la = "ls -A --color=auto";     # Tüm dosyalar (. ve .. hariç)
      l = "ls -CF --color=auto";     # Kısa format, dizin işaretli
      
      # ----------------------------------------------------------------------
      # NIXOS KOMUTLARI
      # ----------------------------------------------------------------------
      # Sistem yönetimi için sık kullanılan komutlar
      # Git dirty uyarısını önlemek için auto-commit eklendi
      # Not: Submodule'ler için özel işlem yapılıyor
      
      # rebuild: Sistem rebuild + git auto-commit
      rebuild = ''
        cd /etc/nixos && \
        git add --all && \
        git diff --quiet && git diff --staged --quiet || \
        git commit -am "auto: $(date '+%Y-%m-%d %H:%M')" && \
        sudo nixos-rebuild switch --flake /etc/nixos#nixos
      '';
      
      # zixswitch: Home Manager switch + git auto-commit + backup
      # -b backup = Mevcut dosyaları .backup uzantısıyla yedekler
      zixswitch = ''
        cd /etc/nixos && \
        git add --all && \
        git diff --quiet && git diff --staged --quiet || \
        git commit -am "home: $(date '+%Y-%m-%d %H:%M')" && \
        home-manager switch --flake /etc/nixos#zixar -b backup
      '';
      
      # fullrebuild: Hem sistem hem home-manager rebuild
      fullrebuild = ''
        cd /etc/nixos && \
        git add --all && \
        git diff --quiet && git diff --staged --quiet || \
        git commit -am "full: $(date '+%Y-%m-%d %H:%M')" && \
        sudo nixos-rebuild switch --flake /etc/nixos#nixos && \
        home-manager switch --flake /etc/nixos#zixar -b backup
      '';
      
      # update: Flake güncelle + tam rebuild
      update = ''
        cd /etc/nixos && \
        sudo nix flake update && \
        git add --all && \
        git diff --quiet && git diff --staged --quiet || \
        git commit -am "update: flake $(date '+%Y-%m-%d')" && \
        sudo nixos-rebuild switch --flake /etc/nixos#nixos && \
        home-manager switch --flake /etc/nixos#zixar -b backup
      '';
      
      cleanup = "sudo nix-collect-garbage -d && sudo nix-store --optimize";
      # ↑ Eski nesilleri siler + disk alanı optimize eder
      
      # ----------------------------------------------------------------------
      # EDİTÖRLER
      # ----------------------------------------------------------------------
      v = "nvim";          # Neovim kısayolu
      vim = "nvim";        # vim yazınca da Neovim açılsın
      hx = "helix";        # Helix editör
      c = "code .";        # VS Code'u mevcut dizinde aç
      
      # ----------------------------------------------------------------------
      # GIT KISAYOLLARI
      # ----------------------------------------------------------------------
      gs = "git status";           # Repo durumu
      ga = "git add";              # Değişiklikleri stage'e ekle
      gc = "git commit";           # Commit oluştur
      gp = "git push";             # Değişiklikleri push et
      gl = "git log --oneline -10"; # Son 10 commit'i göster
      
      # ----------------------------------------------------------------------
      # UYGULAMALAR
      # ----------------------------------------------------------------------
      lm = "lmstudio";             # LM Studio
      
      # ----------------------------------------------------------------------
      # HYPRLAND
      # ----------------------------------------------------------------------
      hypr = "nvim ~/.config/hypr/hyprland.conf";  # Hyprland config düzenle
      
      # ----------------------------------------------------------------------
      # GÜÇ KONTROLÜ
      # ----------------------------------------------------------------------
      # Özel power-control script'leri için kısayollar
      gaming = "sudo power-control gaming";    # Oyun modu (yüksek performans)
      turbo = "sudo power-control turbo";      # Turbo mod (maksimum güç)
      tasarruf = "sudo power-control saver";   # Güç tasarrufu modu
      normal = "sudo power-control normal";    # Normal/dengeli mod
      "auto-power" = "sudo power-control auto"; # Otomatik mod
    };
    
    # ========================================================================
    # BAŞLANGIÇ KODLARI (initContent)
    # ========================================================================
    # Bu blok ZSH her başlatıldığında çalışır.
    # Custom fonksiyonlar, değişkenler ve başlangıç komutları buraya yazılır.
    #
    # '' ... '' = Nix'te çok satırlı string (multi-line string)
    # İçindeki kod doğrudan ~/.zshrc'ye yazılır.
    # ========================================================================
    initContent = ''
      # ----------------------------------------------------------------------
      # FASTFETCH OTOMATİK ÇALIŞTIR
      # ----------------------------------------------------------------------
      # Terminal açıldığında sistem bilgilerini gösterir.
      # FASTFETCH_RAN değişkeni ile sadece ilk terminal'de çalışır,
      # iç içe shell'lerde tekrar çalışmaz.
      # ----------------------------------------------------------------------
      if [[ -z $FASTFETCH_RAN ]]; then
        export FASTFETCH_RAN=1
        fastfetch
      fi
      
      # ----------------------------------------------------------------------
      # CUSTOM FONKSİYONLAR
      # ----------------------------------------------------------------------
      
      # mkcd: Dizin oluştur ve içine gir
      # Kullanım: mkcd yeni-proje
      # Normal: mkdir yeni-proje && cd yeni-proje
      mkcd() { mkdir -p "$1" && cd "$1"; }
      
      # extract: Her türlü arşivi aç
      # Kullanım: extract dosya.tar.gz
      # Dosya uzantısına göre doğru komutu otomatik seçer
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

  # ==========================================================================
  # STARSHIP PROMPT ÖZELLEŞTİRME
  # ==========================================================================
  # Starship, modern ve hızlı bir prompt temasıdır.
  # Rust ile yazılmıştır, çok hızlı ve özelleştirilebilir.
  #
  # Prompt = Shell'de komut yazdığın satırın başındaki kısım
  # Örnek: "zixar@nixos ~/Documents ❯ " 
  #        ↑ Bu kısım prompt'tur
  # ==========================================================================
  
  programs.starship = {
    # ------------------------------------------------------------------------
    # enable = true
    # ------------------------------------------------------------------------
    # Starship'i aktifleştirir.
    # Otomatik olarak ~/.config/starship.toml oluşturur.
    # ------------------------------------------------------------------------
    enable = true;
    
    # ------------------------------------------------------------------------
    # enableZshIntegration = true
    # ------------------------------------------------------------------------
    # Starship'i ZSH ile entegre eder.
    # ~/.zshrc'ye gerekli kodu otomatik ekler.
    # ------------------------------------------------------------------------
    enableZshIntegration = true;
    
    # ========================================================================
    # STARSHIP AYARLARI (settings)
    # ========================================================================
    settings = {
      # ----------------------------------------------------------------------
      # FORMAT - PROMPT ŞABLONU
      # ----------------------------------------------------------------------
      # Bu, prompt'un genel yapısını belirler.
      # Her $modül ismi bir Starship modülüne karşılık gelir.
      #
      # POWERLINE / FLAMA TARZI PROMPT
      # ==============================
      # Sivri uçlu segmentler için özel karakterler:
      #  = Sağa sivri uç (segment sonu)
      #  = Sola sivri uç (segment başı)
      #  = İnce ayırıcı (aynı arka plan içinde)
      #
      # Görünüm:
      #  🐧 ~/Documents   main  ❯
      # └──┘└────────────┘└────┘
      #  Tux    Dizin      Git
      #
      # NOT: Flama tarzı için her segment'in arka plan rengi olması
      # ve sonunda  karakteri ile bitirilmesi gerekir.
      #
      # KULLANILABILIR MODÜLLER:
      # $username     - Kullanıcı adı
      # $hostname     - Bilgisayar adı
      # $directory    - Mevcut dizin
      # $git_branch   - Git dalı
      # $git_status   - Git durumu
      # $cmd_duration - Son komutun çalışma süresi
      # $character    - Prompt'un son karakteri
      # $time         - Saat
      # $battery      - Pil durumu
      # $memory_usage - RAM kullanımı
      # $python       - Python virtual environment
      # $nodejs       - Node.js versiyonu
      # $rust         - Rust versiyonu
      # $nix_shell    - Nix shell aktif mi?
      # ----------------------------------------------------------------------
      
      # POWERLINE FLAMA FORMAT
      # Segment 1: Tux (Linux penguen) - Mavi arka plan
      # Segment 2: Dizin - Sarı arka plan
      # Segment 3: Git - Yeşil arka plan (sadece git repo'dayken görünür)
      # Her segment sivri uçla () bitiyor
      #
      # LINUX/TUX İKONLARI (Nerd Font):
      #  = Klasik Tux (nf-linux-tux)
      #  = Arch Linux
      #  = Debian
      # 󱄅 = NixOS
      #  = Ubuntu
      #  = Fedora
      format = ''
        [](fg:#458588)[󱄅 ](bg:#458588 fg:#ebdbb2)[](fg:#458588 bg:#d79921)$directory[](fg:#d79921 bg:#689d6a)$git_branch$git_status[](fg:#689d6a)$nix_shell$cmd_duration
        $character
      '';
      
      # ----------------------------------------------------------------------
      # CHARACTER - PROMPT SONU KARAKTERİ
      # ----------------------------------------------------------------------
      # Komut yazacağın yerin hemen önündeki karakter.
      # success_symbol: Önceki komut başarılı olduğunda
      # error_symbol: Önceki komut hata verdiğinde
      #
      # POPULER ALTERNATİFLER:
      # "❯"   - Varsayılan (Gruvbox orange)
      # "➜"   - Ok işareti
      # "λ"   - Lambda (Haskell fanları için)
      # ">"   - Klasik
      # "▸"   - Üçgen
      # "⟫"   - Çift ok
      # ""   - Powerline ok (flama tarzı için ideal)
      # ----------------------------------------------------------------------
      character = {
        success_symbol = "[❯](bold #d65d0e)";  # Gruvbox turuncu - başarılı
        error_symbol = "[❯](bold #cc241d)";    # Gruvbox kırmızı - hatalı
      };
      
      # ----------------------------------------------------------------------
      # DIRECTORY - DİZİN GÖSTERİMİ
      # ----------------------------------------------------------------------
      # Mevcut dizini gösterir.
      #
      # style: Renk ve stil
      # truncation_length: Kaç dizin gösterilecek (3 = son 3)
      # truncate_to_repo: Git repo kökünden itibaren mi kısaltılsın?
      #
      # RENK FORMATI: "[text](stil renk)"
      # Stiller: bold, italic, underline, dimmed
      # Renkler: red, green, blue, yellow, purple, cyan, white, black
      #          veya HEX: #rrggbb
      # ----------------------------------------------------------------------
      directory = {
        style = "fg:#1d2021 bg:#d79921";  # Koyu yazı, sarı arka plan (powerline)
        format = "[ $path ]($style)";      # Boşluklu format
        truncation_length = 3;       # Son 3 dizini göster
        truncate_to_repo = true;     # Git repo'dan itibaren kısalt
        home_symbol = "🏠";           # ~ yerine ev emoji'si
        read_only = " 🔒";            # Salt okunur diziler için ikon
      };
      
      # ----------------------------------------------------------------------
      # GIT BRANCH - GIT DALI
      # ----------------------------------------------------------------------
      # Aktif git dalını gösterir.
      #
      # symbol: Dal isminden önce gösterilen ikon
      # style: Yazı rengi/stili
      #
      # ALTERNATİF SEMBOLLER:
      # " "   - Dal ikonu (varsayılan)
      # "🌿"  - Yaprak
      # "🔀"  - Çatal
      # "⎇ "  - Alternatif
      # ----------------------------------------------------------------------
      git_branch = {
        symbol = "";
        style = "fg:#1d2021 bg:#689d6a";  # Koyu yazı, aqua arka plan (powerline)
        format = "[ $symbol $branch ]($style)";
      };
      
      # ----------------------------------------------------------------------
      # GIT STATUS - GIT DURUMU
      # ----------------------------------------------------------------------
      # Değişiklik, ekleme, silme durumlarını gösterir.
      #
      # ahead: Remote'dan önde (push yapılmamış commit var)
      # behind: Remote'dan geride (pull gerekli)
      # diverged: Hem önde hem geride (rebase/merge gerekli)
      #
      # DİĞER DURUMLAR (varsayılan değerler):
      # staged = "+"      - Stage'e eklenmiş değişiklik
      # modified = "!"    - Değiştirilmiş dosya
      # deleted = "✘"     - Silinmiş dosya
      # untracked = "?"   - Takip edilmeyen dosya
      # stashed = "$"     - Stash'lenmiş değişiklik
      # ----------------------------------------------------------------------
      git_status = {
        style = "fg:#1d2021 bg:#689d6a";  # Git branch ile aynı arka plan
        format = "[$all_status$ahead_behind]($style)";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        staged = "+";
        modified = "!";
        untracked = "?";
      };
      
      # ======================================================================
      # EKLEYEBİLECEĞİN EK MODÜLLER
      # ======================================================================
      # Aşağıdaki modülleri aktifleştirmek için yorum satırlarını kaldır:
      # ======================================================================
      
      cmd_duration = {
         # Uzun süren komutların süresini gösterir
         min_time = 2000;  # 2 saniyeden uzun komutlar için göster
         format = "took [$duration](bold yellow) ";
       };
      
      # time = {
      #   # Saati gösterir
      #   disabled = false;
      #   format = "[$time](bold white) ";
      #   time_format = "%H:%M";
      # };
      
       battery = {
         # Pil durumunu gösterir
         full_symbol = "🔋";
         charging_symbol = "⚡";
         discharging_symbol = "💀";
       };
      
       nix_shell = {
         # Nix shell içinde olduğunu gösterir
         symbol = "❄️ ";
         format = "via [$symbol$state]($style) ";
       };
      
      # username = {
      #   # Kullanıcı adını gösterir
      #   show_always = true;
      #   format = "[$user](bold green)@";
      # };
      
       hostname = {
         # Bilgisayar adını gösterir
         ssh_only = false;
         format = "[$hostname](bold blue) ";
      };
    };
  };
}
