{
  description = "Zixar's NixOS Configuration";

  inputs = {
    # nixpkgs: NixOS 25.11 stable
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
 #    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
 #   antigravity.url = "path:/path/to/Google-Antigravity";
    # Home-manager: User-level packages
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";  # Aynı nixpkgs'i kullan
    };
  };
  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
# Modüllere argüman olarak geçiyoruz
      modules = [
        # Ana config - Bu zaten tüm modülleri import ediyor!
        # (nvidia.nix, desktop.nix, gaming.nix vs.)
        ./configuration.nix
        
        # Home-manager entegrasyonu
                  home-manager.nixosModules.home-manager
      {
 
	     home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "backup";  # ✅ Burada, üst seviye!
          
          # User config
          users.zixar = import ./home.nix;
        };
	}
      ];
    };
  };
}
