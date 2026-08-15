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

    # Yerel AI: NPU (XDNA2/FastFlowLM) + iGPU (Vulkan) + Lemonade sunucusu
    # DİKKAT: nixpkgs follows EKLEME — binary cache hash'leri pinli nixpkgs'e göre
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";

    # Proton-CachyOS: Blackwell-sertleştirilmiş Proton (VK_EXT_descriptor_heap → Xid 109 fix,
    # vkd3d-proton #2914; DX12 donma #2793 workaround'u da burada test edilmiş). nixpkgs'de
    # paketli DEĞİL. DİKKAT: nixpkgs follows EKLEME — nix-amd-ai ile aynı gerekçe (binary cache
    # hash'leri chaotic'in pinli nixpkgs'ine göre; follows onları kaçırır).
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    # claude-desktop artık resmî Linux .deb'inden yerel pakette:
    # home/apps/claude-desktop-pkg.nix

    # Caelestia — Quickshell tabanlı masaüstü kabuğu (bar/launcher/bildirim/kilit/idle)
    # + cli (runtime Material You tema motoru). nixpkgs'te YOK, ikisi de kaynaktan
    # derlenir — Caelestia'nın flake.nix'inde nixConfig/binary cache YOK (nix-amd-ai/
    # chaotic'in aksine), o yüzden follows burada zararsız: kaçırılacak bir cache hash'i
    # yok, yalnız closure'daki nixpkgs'i tekilleştirir.
    # cli AYRI girdi (upstream'in kendi caelestia-shell.follows="" ile kırdığı döngüyü
    # burada TERSİNE kuruyoruz): özel şemaları (schemes/*.txt) pakete enjekte etmek için
    # cli-pkg'i override etmemiz gerekiyor — bkz. home/desktop/caelestia/default.nix.
    caelestia-cli = {
      url = "github:caelestia-dots/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.caelestia-cli.follows = "caelestia-cli";
      # quickshell'i follows ETME: upstream git.outfoxxed.me master'ı şart koşuyor
      # ("this has to be the git version, not the latest tagged version" — cli README).
      # nixpkgs'teki pkgs.quickshell 0.3.0'a düşürmek QML "Type X unavailable" çökmesi
      # verir; ayrı kalması bilinçli, Caelestia'nın kendi tasarımı.
    };
  };

  outputs = inputs @ { nixpkgs, home-manager, stylix, ... }:
    let
      system = "x86_64-linux";
      nixpkgsConfig = {
        allowUnfree = true;
        permittedInsecurePackages = [
          # İki electron uygulaması iki farklı sürüm pinliyor (ör. vesktop vs
          # claude-desktop); nixpkgs güncellemesiyle biri 40'a çıktı, diğeri 39'da.
          "electron-39.8.10"
          "electron-40.10.5"
        ];
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
        # osConfig: gömülü HM'de home-manager NixOS modülü otomatik geçirir;
        # standalone yolda YOK → rice/hm.nix'in `osConfig.desktop.hyprland.enable
        # or false` varsayılanı false'a düşüp TÜM hypr dosyalarını jenerasyondan
        # atıyordu (17 Tem gecesi hms sonrası Hyprland config'siz kaldı).
        # Sistem config'ini burada elle geçir → iki yol aynı bayrağı görür.
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
