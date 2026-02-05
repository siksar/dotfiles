{ config, pkgs, ... }:
{
  # ========================================================================
  # HELIX EDITOR (Rust based - Neovim alternatifi)
  # ========================================================================
  
  programs.helix = {
    enable = true;
    defaultEditor = true;
    
    settings = {
      theme = "tokyonight";
      
      editor = {
        line-number = "relative";
        mouse = true;
        bufferline = "multiple";
        cursorline = true;
        color-modes = true;
        
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        
        statusline = {
          left = ["mode" "spinner" "file-name" "read-only-indicator" "file-modification-indicator"];
          right = ["diagnostics" "selections" "register" "position" "file-encoding"];
        };
        
        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };
        
        indent-guides = {
          render = true;
          character = "▏";
        };
      };
      
      keys.normal = {
        space.w = ":w";
        space.q = ":q";
        "C-d" = ["half_page_down" "center"];
        "C-u" = ["half_page_up" "center"];
      };
    };
    
    languages = {
      language = [
        {
          name = "nix";
          auto-format = true;
          formatter = { command = "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt"; };
        }
        {
          name = "rust";
          auto-format = true;
        }
        {
          name = "python";
          auto-format = true;
          formatter = { command = "${pkgs.black}/bin/black"; args = ["-"]; };
        }
      ];
    };
  };

  # ========================================================================
  # VS CODE - KALDIRILDI
  # ========================================================================
  # ========================================================================
  # NEOVIM - KALDIRILDI (Helix kullanılıyor)
  # ========================================================================

  # ========================================================================
  # LSP SERVERS & TOOLS
  # ========================================================================
  home.packages = with pkgs; [
    # Nix
    nil
    nixpkgs-fmt
    
    # Python
    pyright
    black
    
    # Rust
    rust-analyzer
    
    # JavaScript/TypeScript
    nodePackages.typescript-language-server
    nodePackages.prettier
    
    # Lua (Helix için de faydalı olabilir)
    lua-language-server
    
    # General
    nodePackages.vscode-langservers-extracted
    
    # Markdown
    marksman
    
    # TOML
    taplo
    
    # YAML
    yaml-language-server
  ];
}