{
  description = "Zixar's NixOS Configuration";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Hyprland - Latest features
    hyprland.url = "github:hyprwm/Hyprland";
    

  };
  
  outputs = { self, nixpkgs, home-manager, hyprland, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      specialArgs = { inherit hyprland; };
      
      modules = [
        ./configuration.nix
        

        
        # Hyprland NixOS module
        hyprland.nixosModules.default
      ];
    };

    # Standalone Home Manager Configuration
    homeConfigurations."zixar" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        # Include overlays if needed for home-manager specific packages
        overlays = [

        ];
      };
      extraSpecialArgs = { inherit hyprland; };
      modules = [
        ./home.nix
      ];
    };
  };
}
