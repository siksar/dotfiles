{ config, pkgs, ... }:
{
  programs.nushell = {
    enable = true;
    
    # Environment variables
    environmentVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    # Shell Aliases - only nushell-specific ones
    # Most aliases are defined globally in home.shellAliases
    shellAliases = {
      # Nushell-specific compatibility aliases
      conf = "z /etc/nixos"; # Using zoxide
      
      # System info aliases
      neofetch = "fastfetch";
    };
    
    # Extra Config
    extraConfig = ''
      $env.config = {
        show_banner: false,
        ls: {
          use_ls_colors: true,
          clickable_links: true,
        },
        rm: {
          always_trash: true, # Safety first!
        },
        table: {
          mode: "rounded", # Aesthetic table borders
        },
        # Integration with other tools
        completions: {
          external: {
            enable: true,
            max_results: 100,
          }
        }
      }
      
      # Custom Commands (Replacements for complex aliases)
      def sys-rebuild [] {
        cd /etc/nixos
        git add .
        git commit -m 'auto'
        sudo nixos-rebuild switch --flake /etc/nixos#nixos
      }
      
      # fullrebuild as a proper nushell command (not alias!)
      # Custom command to rebuild system and home-manager safely (fixing the auto-run issue)
      def fullrebuild [] {
        print "Rebuilding NixOS System..."
        sudo nixos-rebuild switch --flake /etc/nixos#nixos
        print "Rebuilding Home Manager..."
        home-manager switch --flake /etc/nixos#zixar -b backup
      }

      # Custom command for Home Manager only + Git Add (Fixes dirty tree/untracked files)
      def sys-home [] {
        print "Staging changes in /etc/nixos for Flakes..."
        cd /etc/nixos
        try { git add . } catch { print "Git add failed or nothing to add" }
        print "Rebuilding Home Manager..."
        home-manager switch --flake .#zixar -b backup
      }

      def sys-full [] {
        sys-rebuild
        home-manager switch --flake /etc/nixos#zixar
      }
      
      def sys-clean [] {
        sudo nix-collect-garbage -d
        sudo nix-store --optimize
      }
      
      # Zoxide/Starship/Carapace hooks are auto-added
      
      # Run Fastfetch (System Fetch) on startup
      fastfetch
    '';
  };
  
  # Carapace - Multi-shell completion tailored for Nushell
  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };
}
