{
  description = "Zixar's NixOS Configuration - Gigabyte Aero X16 Optimized";

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
    
    # Nix Gaming - Optimizations for gaming
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # NixOS Hardware - Hardware-specific optimizations
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };
    
    # Chaotic Nyx - Bleeding edge packages (for AMD NPU drivers)
    chaotic = {
      url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Caelestia Shell - Modern Wayland Shell (Quickshell based)
    caelstia = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { 
    self, 
    nixpkgs, 
    home-manager, 
    hyprland, 
    noctalia, 
    zen-browser, 
    nix-gaming,
    nixos-hardware,
    chaotic,
    caelstia,
    ... 
  } @ inputs: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        allowBroken = false;
        # AMD NPU support
        permittedInsecurePackages = [];
      };
      overlays = [
        chaotic.overlays.default
      ];
    };
    
    # Special args for all modules
    specialArgs = { 
      inherit 
        inputs 
        hyprland 
        noctalia 
        zen-browser 
        nix-gaming 
        nixos-hardware 
        chaotic
        caelstia;
    };
  in {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules = [
        # Chaotic Nyx module for bleeding edge packages
        chaotic.nixosModules.default
        
        # Hardware optimizations for AMD laptops
        nixos-hardware.nixosModules.common-cpu-amd
        nixos-hardware.nixosModules.common-gpu-amd
        nixos-hardware.nixosModules.common-pc-laptop-ssd
        
        # Main configuration
        ./configuration.nix
        
        # Hyprland NixOS module
        hyprland.nixosModules.default
        
        # Gaming optimizations
        nix-gaming.nixosModules.pipewireLowLatency
        nix-gaming.nixosModules.platformOptimizations
      ];
    };
    
    homeConfigurations."zixar" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = specialArgs;
      modules = [
        ./home.nix
      ];
    };
    
    # Dev shell for Nix development with optimizations
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        nix-output-monitor
        nix-tree
        nix-diff
        nix-index
        nixpkgs-fmt
        statix
        deadnix
      ];
      shellHook = ''
        echo "🔧 NixOS Development Shell"
        echo "Available tools: nix-output-monitor, nix-tree, nix-diff, nix-index"
        echo "Build with: nom build .#nixosConfigurations.nixos.config.system.build.toplevel"
      '';
    };
  };
}
