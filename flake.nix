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
    # claude-desktop artık resmî Linux .deb'inden yerel pakette:
    # modules/apps/claude-desktop-pkg.nix
  };

  outputs = inputs @ { nixpkgs, home-manager, stylix, ... }:
    let
      system = "x86_64-linux";
      nixpkgsConfig = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "electron-39.8.10"
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
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home.nix
          stylix.homeModules.stylix
          ./modules/desktop/stylix-standalone.nix
        ];
      };
    };
}
