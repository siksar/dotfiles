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
