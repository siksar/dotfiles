{ config, pkgs, ... }:
{
  # ========================================================================
  # VS CODE - KALDIRILDI (Neovim kullanılıyor)
  # ========================================================================
  
  # ========================================================================
  # NEOVIM
  # ========================================================================
  
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    
    plugins = with pkgs.vimPlugins; [
      # Package manager
      lazy-nvim
      
      # Core
      plenary-nvim
      nui-nvim
      
      # Theme
      tokyonight-nvim
      
      # UI
      lualine-nvim
      bufferline-nvim
      nvim-web-devicons
      indent-blankline-nvim
      
      # Treesitter
      nvim-treesitter.withAllGrammars
      nvim-treesitter-textobjects
      
      # LSP
      nvim-lspconfig
      mason-nvim
      mason-lspconfig-nvim
      
      # Completion
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp-cmdline
      luasnip
      cmp_luasnip
      friendly-snippets
      
      # Tools
      telescope-nvim
      telescope-fzf-native-nvim
      neo-tree-nvim
      gitsigns-nvim
      which-key-nvim
      comment-nvim
      nvim-autopairs
      nvim-surround
      toggleterm-nvim
      
      # Nix
      vim-nix
    ];
    
    extraLuaConfig = ''
      -- ====================================================================
      -- GENERAL SETTINGS
      -- ====================================================================
      vim.g.mapleader = " "
      vim.g.maplocalleader = " "
      
      local opt = vim.opt
      
      opt.number = true
      opt.relativenumber = true
      opt.tabstop = 2
      opt.shiftwidth = 2
      opt.expandtab = true
      opt.smartindent = true
      opt.wrap = false
      opt.cursorline = true
      opt.signcolumn = "yes"
      opt.termguicolors = true
      opt.showmode = false
      opt.clipboard = "unnamedplus"
      opt.splitright = true
      opt.splitbelow = true
      opt.ignorecase = true
      opt.smartcase = true
      opt.scrolloff = 8
      opt.sidescrolloff = 8
      opt.updatetime = 250
      opt.timeoutlen = 300
      opt.undofile = true
      opt.mouse = "a"
      
      -- Neovide font
      opt.guifont = "JetBrainsMono Nerd Font:h12"
      
      -- ====================================================================
      -- TOKYO NIGHT THEME
      -- ====================================================================
      require("tokyonight").setup({
        style = "night", -- The theme comes in three styles, `storm`, `moon`, a darker variant `night` and `day`
        light_style = "day", -- The theme is used when the background is set to light
        transparent = false, -- Enable this to disable setting the background color
        terminal_colors = true, -- Configure the colors for the neovim terminal
        styles = {
          -- Style to be applied to different syntax groups
          -- Value is any valid attr-list value for `:help nvim_set_hl`
          comments = { italic = true },
          keywords = { italic = true },
          functions = {},
          variables = {},
          -- Background styles. Can be "dark", "transparent" or "normal"
          sidebars = "dark", -- style for sidebars, see below
          floats = "dark", -- style for floating windows
        },
      })
      vim.cmd.colorscheme("tokyonight")
      
      -- ====================================================================
      -- LUALINE
      -- ====================================================================
      require("lualine").setup({
        options = {
          theme = "tokyonight",
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
        },
      })
      
      -- ====================================================================
      -- BUFFERLINE
      -- ====================================================================
      require("bufferline").setup({
        options = {
          mode = "buffers",
          diagnostics = "nvim_lsp",
          separator_style = "thin",
        },
      })
      
      -- ====================================================================
      -- TREESITTER (NixOS: grammars are managed by Nix)
      -- ====================================================================
      local ok, ts_configs = pcall(require, "nvim-treesitter.configs")
      if ok then
        ts_configs.setup({
          highlight = { enable = true },
          indent = { enable = true },
        })
      else
        -- Fallback: Just enable highlighting if configs module not found
        vim.api.nvim_create_autocmd("FileType", {
          callback = function()
            pcall(vim.treesitter.start)
          end,
        })
      end
      
      -- ====================================================================
      -- TELESCOPE
      -- ====================================================================
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          prompt_prefix = "   ",
          selection_caret = " ",
        },
      })
      
      -- ====================================================================
      -- NEOTREE - Enhanced with icons and git status
      -- ====================================================================
      require("neo-tree").setup({
        close_if_last_window = true,
        popup_border_style = "rounded",
        enable_git_status = true,
        enable_diagnostics = true,
        
        default_component_configs = {
          indent = {
            indent_size = 2,
            padding = 1,
            with_markers = true,
            indent_marker = "│",
            last_indent_marker = "└",
            highlight = "NeoTreeIndentMarker",
            with_expanders = true,
            expander_collapsed = "",
            expander_expanded = "",
            expander_highlight = "NeoTreeExpander",
          },
          icon = {
            folder_closed = "",
            folder_open = "",
            folder_empty = "",
            default = "",
          },
          modified = {
            symbol = "●",
            highlight = "NeoTreeModified",
          },
          name = {
            trailing_slash = false,
            use_git_status_colors = true,
          },
          git_status = {
            symbols = {
              added     = "✚",
              modified  = "",
              deleted   = "✖",
              renamed   = "󰁕",
              untracked = "",
              ignored   = "",
              unstaged  = "󰄱",
              staged    = "",
              conflict  = "",
            },
          },
        },
        
        window = {
          width = 32,
          mappings = {
            ["<space>"] = "none",
            ["<cr>"] = "open",
            ["o"] = "open",
            ["s"] = "open_split",
            ["v"] = "open_vsplit",
            ["t"] = "open_tabnew",
            ["a"] = "add",
            ["d"] = "delete",
            ["r"] = "rename",
            ["c"] = "copy",
            ["m"] = "move",
            ["q"] = "close_window",
            ["R"] = "refresh",
            ["?"] = "show_help",
            ["<"] = "prev_source",
            [">"] = "next_source",
          },
        },
        
        filesystem = {
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = false,
            hide_by_name = {
              ".git",
              "node_modules",
              "__pycache__",
            },
          },
          follow_current_file = {
            enabled = true,
          },
          use_libuv_file_watcher = true,
        },
        
        git_status = {
          window = {
            position = "float",
          },
        },
      })
      
      -- ====================================================================
      -- GITSIGNS - Enhanced with blame and navigation
      -- ====================================================================
      require("gitsigns").setup({
        signs = {
          add          = { text = "│" },
          change       = { text = "│" },
          delete       = { text = "_" },
          topdelete    = { text = "‾" },
          changedelete = { text = "~" },
          untracked    = { text = "┆" },
        },
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        current_line_blame = false,
        current_line_blame_opts = {
          virt_text = true,
          virt_text_pos = "eol",
          delay = 300,
        },
        current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> - <summary>",
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end
          -- Navigation
          map("n", "]c", function()
            if vim.wo.diff then return "]c" end
            vim.schedule(function() gs.next_hunk() end)
            return "<Ignore>"
          end, { expr = true, desc = "Next hunk" })
          map("n", "[c", function()
            if vim.wo.diff then return "[c" end
            vim.schedule(function() gs.prev_hunk() end)
            return "<Ignore>"
          end, { expr = true, desc = "Prev hunk" })
        end,
      })
      
      -- ====================================================================
      -- WHICH-KEY
      -- ====================================================================
      require("which-key").setup()
      
      -- ====================================================================
      -- COMMENT
      -- ====================================================================
      require("Comment").setup()
      
      -- ====================================================================
      -- AUTOPAIRS - Enhanced with cmp integration
      -- ====================================================================
      local npairs = require("nvim-autopairs")
      npairs.setup({
        check_ts = true,
        ts_config = {
          lua = { "string", "source" },
          javascript = { "string", "template_string" },
        },
        disable_filetype = { "TelescopePrompt", "spectre_panel" },
        fast_wrap = {
          map = "<M-e>",
          chars = { "{", "[", "(", '"', "'" },
          pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
          offset = 0,
          end_key = "$",
          keys = "qwertyuiopzxcvbnmasdfghjkl",
          check_comma = true,
          highlight = "PmenuSel",
          highlight_grey = "LineNr",
        },
      })
      -- Integrate autopairs with cmp
      local cmp_autopairs = require("nvim-autopairs.completion.cmp")
      local cmp = require("cmp")
      cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      
      -- ====================================================================
      -- TOGGLETERM - Terminal integration
      -- ====================================================================
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then
            return 15
          elseif term.direction == "vertical" then
            return vim.o.columns * 0.4
          end
        end,
        open_mapping = [[<c-\>]],
        hide_numbers = true,
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        direction = "float",
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = "curved",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal",
          },
        },
      })
      
      -- Custom terminals for NixOS
      local Terminal = require("toggleterm.terminal").Terminal
      
      local lazygit = Terminal:new({
        cmd = "lazygit",
        hidden = true,
        direction = "float",
        float_opts = { border = "rounded" },
      })
      
      function _LAZYGIT_TOGGLE()
        lazygit:toggle()
      end
      
      local nixos_rebuild = Terminal:new({
        cmd = "sudo nixos-rebuild switch",
        hidden = true,
        direction = "float",
        close_on_exit = false,
        float_opts = { border = "rounded" },
      })
      
      function _NIXOS_REBUILD()
        nixos_rebuild:toggle()
      end
      
      local nixos_test = Terminal:new({
        cmd = "sudo nixos-rebuild test",
        hidden = true,
        direction = "float",
        close_on_exit = false,
        float_opts = { border = "rounded" },
      })
      
      function _NIXOS_TEST()
        nixos_test:toggle()
      end
      
      -- ====================================================================
      -- LSP
      -- ====================================================================
      local lspconfig = require("lspconfig")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      
      -- Nix
      lspconfig.nil_ls.setup({ capabilities = capabilities })
      
      -- Lua
      lspconfig.lua_ls.setup({ capabilities = capabilities })
      
      -- Python
      lspconfig.pyright.setup({ capabilities = capabilities })
      
      -- Rust
      lspconfig.rust_analyzer.setup({ capabilities = capabilities })
      
      -- ====================================================================
      -- COMPLETION
      -- ====================================================================
      local cmp = require("cmp")
      local luasnip = require("luasnip")
      
      require("luasnip.loaders.from_vscode").lazy_load()
      
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })
      
      -- ====================================================================
      -- KEYMAPS
      -- ====================================================================
      local keymap = vim.keymap.set
      
      -- File explorer
      keymap("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle Explorer" })
      keymap("n", "<leader>o", "<cmd>Neotree focus<cr>", { desc = "Focus Explorer" })
      
      -- Telescope
      keymap("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find Files" })
      keymap("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live Grep" })
      keymap("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })
      keymap("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help Tags" })
      keymap("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Recent Files" })
      keymap("n", "<leader>fc", "<cmd>Telescope git_commits<cr>", { desc = "Git Commits" })
      keymap("n", "<leader>fs", "<cmd>Telescope git_status<cr>", { desc = "Git Status" })
      
      -- Buffers
      keymap("n", "<S-l>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next Buffer" })
      keymap("n", "<S-h>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev Buffer" })
      keymap("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete Buffer" })
      keymap("n", "<leader>bp", "<cmd>BufferLinePick<cr>", { desc = "Pick Buffer" })
      
      -- Window navigation
      keymap("n", "<C-h>", "<C-w>h", { desc = "Go Left" })
      keymap("n", "<C-j>", "<C-w>j", { desc = "Go Down" })
      keymap("n", "<C-k>", "<C-w>k", { desc = "Go Up" })
      keymap("n", "<C-l>", "<C-w>l", { desc = "Go Right" })
      
      -- Save
      keymap("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
      keymap("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
      
      -- Clear highlights
      keymap("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear Highlights" })
      
      -- Git (gitsigns)
      keymap("n", "<leader>gh", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview Hunk" })
      keymap("n", "<leader>gb", "<cmd>Gitsigns toggle_current_line_blame<cr>", { desc = "Toggle Blame" })
      keymap("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Diff This" })
      keymap("n", "<leader>gs", "<cmd>Gitsigns stage_hunk<cr>", { desc = "Stage Hunk" })
      keymap("n", "<leader>gr", "<cmd>Gitsigns reset_hunk<cr>", { desc = "Reset Hunk" })
      keymap("n", "<leader>gS", "<cmd>Gitsigns stage_buffer<cr>", { desc = "Stage Buffer" })
      keymap("n", "<leader>gR", "<cmd>Gitsigns reset_buffer<cr>", { desc = "Reset Buffer" })
      
      -- LazyGit
      keymap("n", "<leader>gg", "<cmd>lua _LAZYGIT_TOGGLE()<cr>", { desc = "LazyGit" })
      
      -- Terminal
      keymap("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", { desc = "Float Terminal" })
      keymap("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Horizontal Terminal" })
      keymap("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", { desc = "Vertical Terminal" })
      
      -- NixOS rebuild shortcuts
      keymap("n", "<leader>nr", "<cmd>lua _NIXOS_REBUILD()<cr>", { desc = "NixOS Rebuild Switch" })
      keymap("n", "<leader>nt", "<cmd>lua _NIXOS_TEST()<cr>", { desc = "NixOS Rebuild Test" })
      
      -- Terminal mode escape
      keymap("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit Terminal Mode" })
      keymap("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Go Left" })
      keymap("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Go Down" })
      keymap("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Go Up" })
      keymap("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Go Right" })
    '';
  };
  
  # ========================================================================
  # HELIX EDITOR - KALDIRILDI (Neovim kullanılıyor)
  # ========================================================================
  
  # ========================================================================
  # LSP SERVERS
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
    
    # Lua
    lua-language-server
    
    # General
    nodePackages.vscode-langservers-extracted
  ];
}
