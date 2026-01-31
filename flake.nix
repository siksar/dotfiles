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
    
    # Noctalia Shell - Modern Wayland Desktop Shell
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { self, nixpkgs, home-manager, hyprland, noctalia, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      
      specialArgs = { inherit hyprland noctalia; };
      
      modules = [
        ./configuration.nix
        hyprland.nixosModules.default
      ];
    };

    homeConfigurations."zixar" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [];
      };
      extraSpecialArgs = { inherit hyprland noctalia; };
      modules = [
        ./home.nix
      ];
    };
  };
}
