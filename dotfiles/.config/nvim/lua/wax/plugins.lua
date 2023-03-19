-- Investigate:
-- https://github.com/cshuaimin/ssr.nvim/
-- https://github.com/monaqa/dial.nvim

return {
  --------- UI ---------
  { "mhinz/vim-startify", lazy = false },
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
    event = { "BufReadPre", "BufNewFile" },
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
    keys = {
      { "œ", "<cmd>BufferPrevious<cr>", desc = "Previous buffer", mode = { "n", "i" } },
      { "∑", "<cmd>BufferNext<cr>", desc = "Next buffer", mode = { "n", "i" } },
      { "®", "<cmd>BufferClose<cr>", desc = "Close buffer", mode = { "n", "i" } },
      {
        "©",
        "<cmd>BufferCloseAllButCurrent<cr>",
        desc = "Close all buffer except current",
        mode = { "n", "i" },
      },
    },
    -- init = function()
    --   local kmap = vim.keymap.set
    --   local opts = { nowait = true, silent = true }
    --   kmap({ "n", "i" }, "œ", "<cmd>BufferPrevious<cr>", opts) -- option + q
    --   kmap({ "n", "i" }, "∑", "<cmd>BufferNext<cr>", opts) -- option + w
    --   kmap({ "n", "i" }, "®", "<cmd>BufferClose<cr>", opts) -- option + r
    --   kmap({ "n" }, "©", "<cmd>BufferCloseAllButCurrent<cr>", opts) -- option + g
    -- end,
  },
  { -- dressing
    "stevearc/dressing.nvim",
    lazy = true,
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
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
    opts = {
      builtin = { enabled = false },
      select = { enabled = true, backend = { "telescope" } },
      input = { enabled = true, win_options = { winblend = 0 } },
    },
  },
  { -- gitsigns
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        map("n", "]h", gs.next_hunk, "Next Hunk")
        map("n", "[h", gs.prev_hunk, "Prev Hunk")

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
    "nvim-treesitter/nvim-treesitter",
    -- dev = true, -- use "~/src/nvim-treesitter/"
    event = { "BufReadPost", "BufNewFile" },
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
        lazy = true,
        ft = { "html", "vue", "typescriptreact", "svelte" },
      },
      { "windwp/nvim-ts-autotag" },
      {
        "andymass/vim-matchup",
        event = "VeryLazy",
        init = function()
          vim.g.matchup_enabled = 1
          vim.g.matchup_mouse_enabled = 0
          vim.g.matchup_text_obj_enabled = 0
          vim.g.matchup_transmute_enabled = 0
          vim.g.matchup_matchparen_offscreen = {}

          -- Wrong matching (HTML)
          -- https://github.com/andymass/vim-matchup/issues/19
          vim.g.matchup_matchpref = { html = { nolists = 1 } }
        end,
      },
    },
    build = ":TSUpdate",
    init = function()
      vim.treesitter.language.register("jinja.html", "html")
    end,
    opts = {
      highlight = {
        enable = true,
        disable = function(lang, buf)
          if vim.tbl_contains({ "vim" }, lang) then
            return true
          end
          return is_big_file(vim.api.nvim_buf_get_name(buf))
        end,
        additional_vim_regex_highlighting = false, -- for spell check
        use_languagetree = true, -- enable language injection
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = "<nop>",
          node_decremental = "<bs>",
        },
      },
      indent = {
        enable = true,
        disable = {
          "lua",
          "vim",
          "python", -- we use "Vimjas/vim-python-pep8-indent"
          "json",
          "typescript",
        },
      },
      ensure_installed = {
        -- Generic:
        "bash",
        "jsonc",
        -- "yaml",
        "lua",
        "ql",
        "query",
        "regex",
        "toml",
        "markdown",
        -- Frontend:
        "graphql",
        "html",
        "css",
        -- "jsdoc",
        "javascript",
        "typescript",
        "tsx",
        "svelte",
        "vue",
        -- Backend:
        "go",
        "rust",
        "python",
        -- Infra:
        "hcl", -- terraform
      },
      --
      ------- Plugins config -------
      --
      -- 'nvim-treesitter/playground'
      playground = {
        enable = true,
        updatetime = 25,
        persist_queries = false,
      },
      query_linter = {
        enable = true,
        use_virtual_text = true,
        lint_events = { "BufWrite", "CursorHold" },
      },
      -- 'nvim-treesitter/nvim-treesitter-textobjects'
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
          keymaps = {
            ["if"] = "@function.inner",
            ["af"] = "@function.outer",

            ["ic"] = "@class.inner",
            ["ac"] = "@class.outer",

            ["iC"] = "@conditional.inner",
            ["aC"] = "@conditional.outer",

            ["ie"] = "@block.inner",
            ["ae"] = "@block.outer",
          },
        },
        move = {
          enable = true,
          goto_next_start = {
            ["]]"] = "@function.outer",
            ["]l"] = "@class.outer",
          },
          goto_next_end = {
            ["]["] = "@function.outer",
            ["]L"] = "@class.outer",
          },
          goto_previous_start = {
            ["[["] = "@function.outer",
            ["[l"] = "@class.outer",
          },
          goto_previous_end = {
            ["[]"] = "@function.outer",
            ["[L"] = "@class.outer",
          },
        },
        lsp_interop = {
          enable = true,
          peek_definition_code = {
            ["<leader>fd"] = "@function.outer",
            ["<leader>fD"] = "@class.outer",
          },
        },
      },
      -- 'JoosepAlviste/nvim-ts-context-commentstring' -- auto deduce comment string on context
      context_commentstring = {
        enable = true,
        enable_autocmd = false,
        -- config = {
        --   ["jinja.html"] = "{# %s #}",
        -- },
      },
      -- 'andymass/vim-matchup' -- better the '%'
      matchup = {
        enable = true,
        disable_virtual_text = true,
      },
      -- 'windwp/nvim-ts-autotag'  -- auto close/rename html tags
      autotag = {
        enable = true,
        filetypes = {
          "html",
          "jinja.html", -- custom add
          "javascript",
          "typescript",
          "javascriptreact",
          "typescriptreact",
          "svelte",
          "vue",
          "tsx",
          "jsx",
          "rescript",
          "xml",
          "php",
          "markdown",
          "glimmer",
          "handlebars",
          "hbs",
        },
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
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
    event = "VeryLazy",
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
    lazy = false,
    event = "VeryLazy",
    dependencies = {
      "jgdavey/tslime.vim", -- send command from vim to a running tmux session
    },
    config = function()
      require("wax.plugcfg.vim-test")
    end,
  },
  { -- tpope/vim-eunuch - sugar for shell commands
    "tpope/vim-eunuch",
    cmd = { "Move", "Copy", "Rename", "Delete" },
  },
  { "tpope/vim-scriptease", cmd = "Messages" },
  { -- diffview: git integration for nvim
    "sindrets/diffview.nvim",
    config = function()
      require("wax.plugcfg.diffview")
    end,
  },
  { -- fzf-lua
    "ibhagwan/fzf-lua",
    event = "VeryLazy",
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
  { -- nvim-surround
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {
      move_cursor = "begin",
      indent_lines = false,
      keymaps = {
        normal = "s",
        normal_line = "S",
        visual = "S",
        delete = "ds",
        change = "cs",
      },
    },
  },
  { -- mini.pairs
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    config = function(_, opts)
      require("mini.pairs").setup(opts)
    end,
  },
  { -- mini - (arround/inside improved)
    "echasnovski/mini.ai",
    dependencies = { "echasnovski/mini.nvim", "nvim-treesitter-textobjects" },
    event = "VeryLazy",
    opts = function()
      local ai = require("mini.ai")
      return {
        search_method = "cover_or_nearest",
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }, {}),
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }, {}),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }, {}),
        },
      }
    end,
    config = function(_, opts)
      require("mini.ai").setup(opts)
    end,
  },
  { -- numToStr/Comment.nvim
    "numToStr/Comment.nvim",
    lazy = false,
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
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" }, -- used for python-utils
    config = function()
      require("wax.lsp.null-ls")
    end,
  },

  { -- luasnip
    "L3MON4D3/LuaSnip",
    event = "VeryLazy",
    config = function()
      require("wax.plugcfg.luasnip")
    end,
  },

  { -- lspconfig + mason
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "folke/neodev.nvim", opts = { experimental = { pathStrict = true } } },
      { -- fidget
        "j-hui/fidget.nvim",
        opts = {
          align = { bottom = false, right = true },
          window = { blend = 0, relative = "editor" },
        },
      },
      { -- mason
        "williamboman/mason.nvim",
        lazy = true,
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
        lazy = true,
      },
      { "b0o/schemastore.nvim", ft = "json" }, -- json schemas for jsonls
    },
    config = function()
      -- Set log level for LSP
      vim.lsp.set_log_level(waxopts.loglevel)

      local waxlsp = require("wax.lsp")
      waxlsp.setup_ui()
      waxlsp.set_lsp_keymaps()

      --Enable completion triggered by <c-x><c-o>
      vim.api.nvim_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

      local have_mason, mlsp = pcall(require, "mason-lspconfig")

      if have_mason then
        local handlers = waxlsp.create_mason_handlers()
        local ensure_installed = vim.tbl_keys(handlers)
        mlsp.setup({
          ensure_installed = ensure_installed,
          automatic_installation = { exclude = { "pylsp" } },
        })
        mlsp.setup_handlers(handlers)
      end
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
      { "lukas-reineke/cmp-rg", dev = true, pin = true },
      "saadparwaiz1/cmp_luasnip",
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
  { -- profiler with flamegraph
    "stevearc/profile.nvim",
    lazy = false,
    config = function()
      local should_profile = os.getenv("NVIM_PROFILE")
      if should_profile then
        require("profile").instrument_autocmds()
        if should_profile:lower():match("^start") then
          require("profile").start("*")
        else
          require("profile").instrument("*")
        end
      end

      function _G.toggle_profile()
        local prof = require("profile")
        if prof.is_recording() then
          prof.stop()
          vim.ui.input(
            { prompt = "Save profile to:", completion = "file", default = "profile.json" },
            function(filename)
              if filename then
                prof.export(filename)
                vim.notify(string.format("Wrote %s", filename))
              end
            end
          )
        else
          prof.start("*")
        end
      end
      -- vim.keymap.set("", "<leader>fP", _G.toggle_profile)
    end,
  },

  --------- Funky bits ---------
  {
    "Eandrju/cellular-automaton.nvim",
    keys = {
      {
        "<leader>fl",
        "<cmd>CellularAutomaton make_it_rain<cr>",
        desc = "Who will bring the rain ?",
        nowait = true,
      },
    },
    cmd = "CellularAutomaton",
  },
}
