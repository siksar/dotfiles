{
  description = "NixOS Flake Configuration with unstable channel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Stylix — taban tema katmanı (font, imleç, build-time renkler)
    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixpkgs'te olmayan uygulamalar
    # Zen browser (Firefox tabanlı)
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium (Chromium tabanlı, imputnet) — 3 Eyl 2026'da kullanıcı isteğiyle GERİ
    # eklendi. 2 Tem 2026'da (06db607) zaten buradaydı, 4 Tem'de Zen lehine
    # düşürülmüştü; gerekçe ve bugünkü bedeli home/apps/helium.nix'te yazılı.
    # nixpkgs'te YOK (pinli nixpkgs'te ne `helium` ne `helium-browser` var; ilgisiz
    # `arc-browser` aliası da "removed due to being unmaintained" fırlatıyor).
    # follows GÜVENLİ: upstream flake'te nixConfig/binary cache TANIMI YOK (kaynak
    # greplendi), yani kaçırılacak cache hash'i yok — nix-amd-ai/chaotic/cachyos-kernel
    # için geçerli "follows EKLEME" uyarısı buraya UYMAZ. Paket .deb'den dpkg+patchelf
    # ile açılıyor, kaynaktan derleme yok.
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Proton-CachyOS: Blackwell-sertleştirilmiş Proton (VK_EXT_descriptor_heap → Xid 109 fix,
    # vkd3d-proton #2914; DX12 donma #2793 workaround'u da burada test edilmiş). nixpkgs'de
    # paketli DEĞİL. DİKKAT: nixpkgs follows EKLEME — nix-amd-ai ile aynı gerekçe (binary cache
    # hash'leri chaotic'in pinli nixpkgs'ine göre; follows onları kaçırır).
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    # CachyOS çekirdeği (xddxdd) — BORE + Clang/ThinLTO + znver4 kod üretimi.
    # chaotic da CachyOS çekirdeği veriyor AMA config'inde CONFIG_SCHED_BORE YOK
    # (1 Eyl 2026'da configfile'ı indirilip greplendi) ve v3/v4/zen4 varyantı hiç yok;
    # BORE ve mimari-optimize derlemeler yalnız bu flake'te. Çekirdeğin üç çıktısı da
    # (out/dev/modules) attic'te doğrulandı (narinfo 200) → kaynaktan derleme yok.
    # DİKKAT: nixpkgs follows EKLEME — nix-amd-ai/chaotic ile aynı gerekçe.
    # DİKKAT: legacyPackages.linuxPackages-cachyos-* KULLANMA — o set xddxdd'nin kendi
    # nixpkgs pin'ini taşır ve NVIDIA'yı 610.57.04'ten 595.99.02'ye DÜŞÜRÜR (Blackwell).
    # Doğru kullanım power.nix'te: pkgs.linuxPackagesFor <çekirdek> → çekirdek buradan,
    # nvidia/acpi_call/aorus-laptop bizim pin'imizden.
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";


    # aero_eg61h — bu makinenin KENDİ WMI/platform sürücüsü + NixOS modülü.
    # `aorus-laptop`'ın yerini aldı (7 Eyl 2026): o sürücü ölçülmüş üç hata
    # taşıyordu (yazılabilir ama etkisiz pwm, sabit-sıfır temp2/temp3, ve
    # PECM+0x2C'ye eksik yazım yüzünden yanlış fan modu). Gerekçe ve ölçümler:
    # ~/aero-eg61h/docs/nixos-gecis.md
    #
    # flake = false: depo bir flake değil, modül dosya yoluyla import ediliyor.
    # Yerel git deposu; rev flake.lock'ta pinli, `nix flake update aero-eg61h`
    # ile bilerek güncellenir.
    aero-eg61h = {
      url = "git+file:///home/zixar/aero-eg61h";
      flake = false;
    };
  };

  outputs = inputs @ { nixpkgs, home-manager, stylix, ... }:
    let
      system = "x86_64-linux";
      nixpkgsConfig = {
        allowUnfree = true;
      };
    in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.config = nixpkgsConfig; }
          ./configuration.nix
          stylix.nixosModules.stylix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs; };
            # Kabukların runtime'da yazdığı config'ler için güvenlik ağı
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.zixar = import ./home.nix;
          }
        ];
      };

      # Standalone HM — kabuk değişimi için hızlı yol: `nh home switch -b hm-backup`
      # (alias: hms). Gömülü HM (nh os switch) ile AYNI home.nix'i okur → drift yok.
      # Stylix burada elle import edilir (gömülüde NixOS modülünden propagate olur).
      homeConfigurations."zixar" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; config = nixpkgsConfig; };
        # osConfig: gömülü HM'de home-manager NixOS modülü bunu otomatik geçirir;
        # standalone yolda YOKTUR. Geçirilmezse `osConfig.<bayrak> or false`
        # yazan her HM modülü sessizce false görür ve o bayrağa bağlı dosyaların
        # TAMAMI jenerasyondan düşer — hata vermeden. (17 Tem 2026'da tam olarak
        # bu oldu: `hms` sonrası masaüstü config'siz kaldı.)
        # Sistem config'ini burada elle geçir → iki yol aynı değerleri görür.
        extraSpecialArgs = {
          inherit inputs;
          osConfig = inputs.self.nixosConfigurations.nixos.config;
        };
        modules = [
          ./home.nix
          stylix.homeModules.stylix
          ./lib/theme-standalone.nix
        ];
      };
    };
}
