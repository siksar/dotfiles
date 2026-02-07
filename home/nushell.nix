{ config, pkgs, ... }:
{
  programs.nushell = {
    enable = true;
    
    # Environment variables
    environmentVariables = {
      EDITOR = "hx";
      VISUAL = "hx";
    };

    # Shell Aliases (Ported from Zsh)
    shellAliases = {
      ll = "ls -la";  # Nu's ls is already colorful and structured
      la = "ls -a";
      
      # NixOS
      # NixOS aliases moved to functions in extraConfig for Nushell compatibility
      
      # Editors
      v = "nvim";
      vim = "nvim";
      vi = "nvim";
      
      # Git
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline -10";
      
      # Configs
      hypr = "hx ~/.config/hypr/hyprland.conf";
      conf = "z /etc/nixos"; # Using zoxide
      
      # Compatibility
      fastfetch = "macchina";
      neofetch = "macchina";
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
      
      # Run Macchina (System Fetch) on startup
      macchina
    '';
  };
  
  # Carapace - Multi-shell completion tailored for Nushell
  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };
}
