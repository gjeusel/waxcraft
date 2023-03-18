-- Investigate:
-- https://github.com/cshuaimin/ssr.nvim/
-- https://github.com/monaqa/dial.nvim

return {
  --------- UI ---------
  { "mhinz/vim-startify" },
  { -- gruvbox
    "morhetz/gruvbox",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = "dark"
      vim.g.gruvbox_invert_selection = 0
      vim.g.gruvbox_improved_warnings = 1
      vim.cmd([[colorscheme gruvbox]])
      require("wax.themes")
    end,
  },
  { -- lualine
    "nvim-lualine/lualine.nvim",
    lazy = false,
    config = function()
      require("wax.plugcfg.lualine")
    end,
  },
  { -- barbar
    "romgrk/barbar.nvim",
    lazy = false,
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = {
      animation = false,
      icons = false,
      auto_hide = false,
      closable = false,
      clickable = false,
      maximum_padding = 1,
      icon_separator_active = "▎",
      icon_separator_inactive = "▎",
      no_name_title = "", -- avoid scratch buffer display from null-ls
      exclude_name = { "" },
    },
    init = function()
      local kmap = vim.keymap.set
      local opts = { nowait = true, silent = true }
      kmap({ "n", "i" }, "œ", "<cmd>BufferPrevious<cr>", opts) -- option + q
      kmap({ "n", "i" }, "∑", "<cmd>BufferNext<cr>", opts) -- option + w
      kmap({ "n", "i" }, "®", "<cmd>BufferClose<cr>", opts) -- option + r
      kmap({ "n" }, "©", "<cmd>BufferCloseAllButCurrent<cr>", opts) -- option + g
    end,
  },
  { -- dressing
    "stevearc/dressing.nvim",
    dependencies = {
      "nvim-telescope/telescope.nvim",
      keys = {
        {
          "<leader>fE",
          "<cmd>Telescope builtin<cr>",
          desc = "Find anything with telescope",
          mode = "n",
        },
      },
    },
    event = "VeryLazy",
    opts = {
      builtin = { enabled = false },
      select = {
        enabled = true,
        backend = { "telescope" },
      },
      input = { enabled = true, { win_options = { winblend = 0 } } },
    },
  },
  { -- gitsigns
    "lewis6991/gitsigns.nvim",
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map("n", "]c", function()
          if vim.wo.diff then
            return "]c"
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return "<Ignore>"
        end, { expr = true })

        map("n", "[c", function()
          if vim.wo.diff then
            return "[c"
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return "<Ignore>"
        end, { expr = true })

        -- Actions
        map({ "n", "v" }, "<leader>hs", ":Gitsigns stage_hunk<CR>")
        map({ "n", "v" }, "<leader>hr", ":Gitsigns reset_hunk<CR>")
        map("n", "<leader>hS", gs.stage_buffer)
        map("n", "<leader>hu", gs.undo_stage_hunk)
        map("n", "<leader>hR", gs.reset_buffer)
        map("n", "<leader>hp", gs.preview_hunk)
        map("n", "<leader>hb", function()
          gs.blame_line({ full = true })
        end)
        map("n", "<leader>tb", gs.toggle_current_line_blame)
        map("n", "<leader>hd", gs.diffthis)
        map("n", "<leader>hD", function()
          gs.diffthis("~")
        end)
      end,
    },
  },
  { -- indentline
    "lukas-reineke/indent-blankline.nvim",
    enabled = false,
    lazy = false,
    opts = {
      char = "¦",
      show_end_of_line = false,
      show_trailing_blankline_indent = false,
    },
    init = function()
      vim.g.indent_blankline_filetype_exclude = {
        "lspinfo",
        "checkhealth",
        "help",
        "man",
        "startify",
        "markdown",
        "vim",
        "tex",
        "fzf",
        "TelescopePrompt",
      }
    end,
  },
  { -- treesitter
    -- "nvim-treesitter/nvim-treesitter",
    dir = "~/src/nvim-treesitter",
    pin = true,
    -- commit = "aebc6cf6bd4675ac86629f516d612ad5288f7868",
    -- run = ":TSUpdate",
    dependencies = {
      { -- playground
        "nvim-treesitter/playground",
        keys = {
          {
            "<leader>xc",
            "<cmd>TSHighlightCapturesUnderCursor<cr>",
            desc = "Show TS higlight under the cursor",
            mode = "n",
          },
        },
        cmd = "TSPlaygroundToggle",
      },
      { "nvim-treesitter/nvim-treesitter-textobjects" },
      { -- nvim-ts-context-commentstring
        "JoosepAlviste/nvim-ts-context-commentstring",
        ft = { "html", "vue", "typescriptreact", "svelte" },
      },
      { "windwp/nvim-ts-autotag" },
    },
    config = function()
      require("wax.plugcfg.treesitter")
    end,
  },
  { -- hlslens
    "kevinhwang91/nvim-hlslens",
    event = "VeryLazy",
    config = function()
      require("wax.plugcfg.hlslens")
    end,
  },

  --------- Deemed Necessary ---------
  { "nvim-lua/plenary.nvim", lazy = true },
  { -- undotree
    "mbbill/undotree",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "UndotreeToggle", mode = "n" },
    },
  },
  { -- vim-tmux-navigator
    "christoomey/vim-tmux-navigator", -- tmux navigation in love with vim
    keys = {
      { "<c-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Tmux Navigate Down", mode = "n" },
      { "<c-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Tmux Navigate Up", mode = "n" },
      { "<c-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Tmux Navigate Right", mode = "n" },
      { "<c-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Tmux Navigate Left", mode = "n" },
    },
    init = function()
      -- tmux, disable tmux navigator when zooming the Vim pane
      vim.g.tmux_navigator_disable_when_zoomed = 1
      vim.g.tmux_navigator_no_mappings = 1 -- custom ones below regarding modes
    end,
  },
  { -- janko/vim-test
    "janko/vim-test",
    dependencies = {
      "jgdavey/tslime.vim", -- send command from vim to a running tmux session
    },
    config = function()
      require("wax.plugcfg.vim-test")
    end,
  },
  { "tpope/vim-eunuch", event = "VeryLazy" }, -- sugar for the UNIX shell commands
  { "tpope/vim-scriptease", cmd = "Messages" }, -- gives :Messages
  { -- diffview: git integration for nvim
    "sindrets/diffview.nvim",
    config = function()
      require("wax.plugcfg.diffview")
    end,
  },
  { -- fzf-lua
    "ibhagwan/fzf-lua",
    lazy = false,
    config = function()
      require("wax.plugcfg.fzf")
    end,
  },
  { -- grapple
    "cbochs/grapple.nvim",
    event = "VeryLazy",
    config = function()
      require("wax.plugcfg.grapple")
    end,
  },

  --------- Enrich Actions ---------
  { "AndrewRadev/splitjoin.vim", event = "VeryLazy" },
  { "kylechui/nvim-surround", event = "VeryLazy", opts = { move_cursor = "begin" } },
  { -- numToStr/Comment.nvim
    "numToStr/Comment.nvim",
    opts = {
      ignore = "^$", -- ignore empty lines
      sticky = true,
      toggler = {
        -- line-comment keymap
        line = "<leader>cc",
        ---block-comment keymap
        -- block = "gbc",
      },
      opleader = {
        -- line-comment keymap
        line = "<leader>c",
        -- block-comment keymap
        -- block = "<leader>b",
      },
      mappings = {
        basic = true,
        extra = false,
        extended = false,
      },
      pre_hook = function()
        -- https://github.com/numToStr/Comment.nvim/pull/62#issuecomment-972790418
        -- Fix builtin Comment behaviour by using ts_context_commentstring:
        if vim.tbl_contains({ "vue", "svelte" }, vim.bo.filetype) then
          require("ts_context_commentstring.internal").update_commentstring()
          return vim.o.commentstring
        end

        if vim.bo.filetype == "typescriptreact" then
          local fn = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
          return fn()
        end
      end,
    },
  },

  --------- LSP ---------
  { -- Github lua copilot
    "zbirenbaum/copilot.lua",
    keys = {
      {
        "<C-x>",
        "<cmd>Copilot panel<cr>",
        desc = "Open Copilot Panel",
        mode = { "n", "i" },
      },
    },
    opts = {
      panel = {
        enabled = true,
        auto_refresh = false,
        keymap = {
          jump_prev = "[[",
          jump_next = "]]",
          accept = "<CR>",
          refresh = "gr",
          open = "<C-x>",
        },
        layout = {
          position = "bottom", -- | top | left | right
          ratio = 0.4,
        },
      },
      suggestion = {
        enabled = false,
      },
      server_opts_overrides = {
        settings = {
          inlineSuggest = { enabled = false },
          editor = {
            showEditorCompletions = false,
            enableAutoCompletions = false,
          },
          advanced = {
            top_p = 0.70,
            listCount = 3, -- #completions for panel
            inlineSuggestCount = 0, -- #completions for getCompletions
            enableAutoCompletions = false,
          },
        },
      },
    },
  },
  { -- null-ls
    "jose-elias-alvarez/null-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" }, -- used for python-utils
    config = function()
      require("wax.lsp.null-ls")
    end,
  },

  { -- lspconfig + mason
    "neovim/nvim-lspconfig",
    lazy = false, -- (needed to register filetype autocmd autostart)
    -- event = "VeryLazy",
    dependencies = {
      { -- mason
        "williamboman/mason.nvim",
        init = function()
          vim.keymap.set("n", "<leader>fM", function()
            require("mason.ui").open()
          end)
        end,
        opts = {
          log_level = vim.log.levels[waxopts.loglevel:upper()],
          ui = {
            border = "rounded",
            icons = {
              package_installed = "✓",
              package_pending = "➜",
              package_uninstalled = "✗",
            },
          },
        },
      },
      { -- mason-lspconfig.nvim
        "williamboman/mason-lspconfig.nvim",
        opts = {
          ensure_installed = {},
          automatic_installation = { exclude = { "pylsp" } },
        },
      },
      -- { "nvim-lua/lsp-status.nvim" },
      { "b0o/schemastore.nvim", ft = "json" }, -- json schemas for jsonls
    },
    config = function()
      require("wax.lsp")
    end,
  },
  { -- nvim-cmp
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "onsails/lspkind-nvim",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-nvim-lua",
      "hrsh7th/cmp-nvim-lsp",
      -- "lukas-reineke/cmp-rg",
      { dir = "~/src/cmp-rg", pin = true },
      "saadparwaiz1/cmp_luasnip",
      { -- snippet engine in lua
        "L3MON4D3/LuaSnip",
        lazy = true,
        config = function()
          require("wax.plugcfg.luasnip")
        end,
      },
      { -- auto pair written in lua
        "windwp/nvim-autopairs",
        opts = {
          disable_filetype = { "TelescopePrompt", "vim", "fzf", "packer" },
          close_triple_quotes = true,
          enable_check_bracket_line = true, --- check bracket in same line
          check_ts = true,
          ts_config = {
            lua = { "string", "source" },
            javascript = { "string", "template_string" },
          },
        },
      },
    },
    config = function()
      require("wax.plugcfg.nvim-cmp")
    end,
  },

  --------- Language Specific ---------
  { "edgedb/edgedb-vim", ft = "edgedb" },
  { "Vimjas/vim-python-pep8-indent", ft = "python" },

  --------- NeoVim Perf / Dev ---------
  { "dstein64/vim-startuptime", cmd = "StartupTime" }, -- analyze startup time
  { "folke/neodev.nvim", ft = "lua" },

  --------- Funky bits ---------
  { "Eandrju/cellular-automaton.nvim", cmd = "CellularAutomaton" },
}
