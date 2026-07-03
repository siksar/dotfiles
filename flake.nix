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

    # Caelestia — shell (bar/launcher/lock) + cli (runtime tema motoru)
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.caelestia-cli.follows = "caelestia-cli";
    };
    caelestia-cli = {
      url = "github:caelestia-dots/cli";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.caelestia-shell.follows = "caelestia-shell";
    };

    # nixpkgs'te olmayan uygulamalar
    helium-browser.url = "github:oxcl/nix-flake-helium-browser";

    # Yerel AI: NPU (XDNA2/FastFlowLM) + iGPU (Vulkan) + Lemonade sunucusu
    # DİKKAT: nixpkgs follows EKLEME — binary cache hash'leri pinli nixpkgs'e göre
    nix-amd-ai.url = "github:noamsto/nix-amd-ai";
    # claude-desktop artık resmî Linux .deb'inden yerel pakette:
    # modules/apps/claude-desktop-pkg.nix
  };

  outputs = inputs @ { nixpkgs, home-manager, stylix, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.config.permittedInsecurePackages = [
            "electron-39.8.10"
          ];
        }
        ./configuration.nix
        stylix.nixosModules.stylix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = { inherit inputs; };
          # Caelestia runtime'da yazdığı config'ler için güvenlik ağı
          home-manager.backupFileExtension = "hm-backup";
          home-manager.users.zixar = import ./home.nix;
        }
      ];
    };
  };
}
