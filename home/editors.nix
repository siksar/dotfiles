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
        "C-d" = ["half_page_down" "align_view_center"];
        "C-u" = ["half_page_up" "align_view_center"];
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
  # NEOVIM - Full featured editor with Neo-tree
  # ========================================================================
  programs.neovim = {
    enable = true;
    defaultEditor = false; # Helix is main editor, nvim for file browsing
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    
    plugins = with pkgs.vimPlugins; [
      # File tree
      neo-tree-nvim
      plenary-nvim
      nvim-web-devicons
      nui-nvim
      
      # Theme
      tokyonight-nvim
      
      # LSP
      nvim-lspconfig
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      luasnip
      cmp_luasnip
      
      # Syntax
      nvim-treesitter.withAllGrammars
      
      # UI
      lualine-nvim
      bufferline-nvim
      indent-blankline-nvim
      
      # Git
      gitsigns-nvim
      
      # Fuzzy finder
      telescope-nvim
    ];
    
    extraLuaConfig = ''
      -- Leader key
      vim.g.mapleader = " "
      
      -- Options
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.cursorline = true
      vim.opt.expandtab = true
      vim.opt.shiftwidth = 2
      vim.opt.tabstop = 2
      vim.opt.termguicolors = true
      vim.opt.mouse = "a"
      vim.opt.clipboard = "unnamedplus"
      vim.opt.signcolumn = "yes"
      
      -- Theme
      require("tokyonight").setup({
        style = "night",
        transparent = true,
      })
      vim.cmd("colorscheme tokyonight-night")
      
      -- Neo-tree setup - Opens in root directory
      require("neo-tree").setup({
        close_if_last_window = true,
        window = {
          width = 30,
        },
        filesystem = {
          follow_current_file = {
            enabled = true,
          },
          use_libuv_file_watcher = true,
        },
      })
      
      -- Auto-open Neo-tree on startup for directory
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          if vim.fn.argc() == 1 and vim.fn.isdirectory(vim.fn.argv()[1]) == 1 then
            vim.cmd("Neotree show")
          end
        end,
      })
      
      -- Keymaps
      vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", { silent = true })
      vim.keymap.set("n", "<leader>w", ":w<CR>", { silent = true })
      vim.keymap.set("n", "<leader>q", ":q<CR>", { silent = true })
      vim.keymap.set("n", "<C-h>", "<C-w>h")
      vim.keymap.set("n", "<C-l>", "<C-w>l")
      vim.keymap.set("n", "<C-j>", "<C-w>j")
      vim.keymap.set("n", "<C-k>", "<C-w>k")
      
      -- Telescope
      local telescope = require("telescope")
      telescope.setup{}
      vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>", { silent = true })
      vim.keymap.set("n", "<leader>fg", ":Telescope live_grep<CR>", { silent = true })
      vim.keymap.set("n", "<leader>fb", ":Telescope buffers<CR>", { silent = true })
      
      -- Lualine
      require("lualine").setup({
        options = {
          theme = "tokyonight",
        },
      })
      
      -- Bufferline
      require("bufferline").setup{}
      
      -- Gitsigns
      require("gitsigns").setup()
      
      -- Treesitter
      require("nvim-treesitter.configs").setup({
        highlight = { enable = true },
        indent = { enable = true },
      })
      
      -- LSP Setup
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      
      -- Nil (Nix)
      lspconfig.nil_ls.setup({ capabilities = capabilities })
      -- Rust
      lspconfig.rust_analyzer.setup({ capabilities = capabilities })
      -- Python
      lspconfig.pyright.setup({ capabilities = capabilities })
      -- TypeScript
      lspconfig.ts_ls.setup({ capabilities = capabilities })
      -- Lua
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      })
      
      -- Completion
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })
    '';
  };

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