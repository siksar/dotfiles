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
    # dotDir - ZSH dosyalarının konumu
    # ------------------------------------------------------------------------
    # Yeni standart: XDG config dizini (~/.config/zsh)
    # Bu ayar gelecek sürümlerde varsayılan olacak
    # ------------------------------------------------------------------------
    dotDir = ".config/zsh";
    
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
      
      # ----------------------------------------------------------------------
      # STARSHIP TEMA KONTROLÜ
      # ----------------------------------------------------------------------
      # Eğer current.toml yoksa varsayılan olarak gruvbox-rainbow'u ayarla.
      # Bu kontrol sadece dosya yoksa çalışır.
      if [ ! -f "$HOME/.config/starship/current.toml" ]; then
        mkdir -p "$HOME/.config/starship"
        if [ -f "$HOME/.config/starship/themes/gruvbox-rainbow.toml" ]; then
           cp "$HOME/.config/starship/themes/gruvbox-rainbow.toml" "$HOME/.config/starship/current.toml"
           chmod +w "$HOME/.config/starship/current.toml"
        fi
      fi
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
    # Starship'i ZSH ile entegre eder.
    # ~/.zshrc'ye gerekli kodu otomatik ekler.
    # ------------------------------------------------------------------------
    enableZshIntegration = true;
    
    # ------------------------------------------------------------------------
    # envExtra - ORTAM DEĞİŞKENLERİ
    # ------------------------------------------------------------------------
    # Starship konfigürasyon dosyasını belirtiyoruz.
    # Bu sayede dinamik olarak theme-sync scripti ile değiştirebileceğiz.
    # ------------------------------------------------------------------------
    envExtra = ''
      export STARSHIP_CONFIG=$HOME/.config/starship/current.toml
    '';
    
    # ========================================================================
    # STARSHIP AYARLARI (settings)
    # ========================================================================
    # settings bloğu kaldırıldı - tema dosyalarında tanımlanacak
    # settings = { ... }
  };
  };
}
