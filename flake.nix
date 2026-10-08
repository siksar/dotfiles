{
  description = "NixOS Flake Configuration with unstable channel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-index haftalık veritabanı + comma; follows güvenli (fetchurl).
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Helium: nixpkgs'te yok; upstream'de binary cache yok → follows güvenli.
    helium-browser = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Proton-CachyOS. follows EKLEME: cache hash'leri kendi nixpkgs pin'ine bağlı.
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    # CachyOS çekirdeği (xddxdd): BORE + znver4, attic'ten iner. follows EKLEME.
    # legacyPackages.linuxPackages-cachyos-* KULLANMA: kendi pin'i NVIDIA'yı düşürür;
    # doğrusu power.nix'teki pkgs.linuxPackagesFor <çekirdek>.
    cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel";


    # aero_eg61h: bu makinenin WMI/platform sürücüsü (yerel git deposu, flake değil).
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
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.zixar = import ./home.nix;
          }
        ];
      };

      # Stylix burada elle import edilir (gömülüde NixOS modülünden propagate olur).
      homeConfigurations."zixar" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs { inherit system; config = nixpkgsConfig; };
        # osConfig standalone yolda yok; geçirilmezse `osConfig.x or false` sessizce false
        # olur ve bayrağa bağlı HM dosyaları düşer.
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
