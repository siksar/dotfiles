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
    # Zen Browser - Privacy-focused Firefox fork
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, home-manager, hyprland, noctalia, zen-browser, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit hyprland noctalia zen-browser; };
      modules = [
        ./configuration.nix
        # Hyprland NixOS module
        hyprland.nixosModules.default
        # Niri will be used from nixpkgs (programs.niri.enable)
      ];
    };
    homeConfigurations."zixar" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
        overlays = [];
      };
      extraSpecialArgs = { inherit hyprland noctalia zen-browser; };
      modules = [
        ./home.nix
      ];
    };
  };
}
