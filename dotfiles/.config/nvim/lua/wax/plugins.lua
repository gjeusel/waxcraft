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
      vim.o.termguicolors = false
      vim.o.background = "dark"
      vim.g.gruvbox_invert_selection = 0
      vim.g.gruvbox_improved_warnings = 1
      vim.cmd([[colorscheme gruvbox]])
      require("wax.themes")
    end,
  },
  -- {
  --   "sainnhe/gruvbox-material",
  --   lazy = false,
  --   priority = 1000,
  --   config = function()
  --     vim.o.termguicolors = false
  --     vim.o.background = "dark"
  --     vim.g.gruvbox_material_background = "soft"
  --     vim.g.gruvbox_material_foreground = "original"
  --     vim.g.gruvbox_material_transparent_background = 1
  --     vim.g.gruvbox_material_better_performance = 1
  --     vim.cmd([[colorscheme gruvbox-material]])
  --   end,
  -- },
  { -- lualine
    "nvim-lualine/lualine.nvim",
    dependencies = { "linrongbin16/lsp-progress.nvim" },
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
      auto_hide = true,
      tabpages = false,
      clickable = false,
      icons = {
        button = "",
        filetype = { enabled = false },
        separator = { left = "▎", right = "" },
        modified = { button = "" },
        pinned = { button = "" },
        inactive = { button = "" },
      },
      maximum_padding = 1,
      -- avoid scratch buffer display from null-ls:
      no_name_title = "",
      exclude_name = { "" },
    },
    keys = {
      { "œ", "<cmd>BufferPrevious<cr>", desc = "Previous buffer", mode = { "n", "i" } },
      { "∑", "<cmd>BufferNext<cr>", desc = "Next buffer", mode = { "n", "i" } },
      { "®", "<cmd>BufferClose<cr>", desc = "Close buffer", mode = { "n", "i" } },
      {
        "©", -- option + g
        function()
          vim.cmd("BufferCloseAllButCurrent")
          vim.cmd([[exec "normal \<c-w>\<c-o>"]])
        end,
        desc = "Close all buffer except current",
        mode = { "n", "i" },
      },
    },
  },
  { -- dressing
    "stevearc/dressing.nvim",
    init = function()
      require("dressing")
    end,
    opts = {
      builtin = { enabled = false },
      select = { enabled = true, fzf_lua = { winopts = { height = 0.5, width = 0.5 } } },
      input = { enabled = true, win_options = { winblend = 0 } },
    },
  },
  { -- gitsigns
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "Gdiff" },
    opts = {
      on_attach = function(buffer)
        local gs = package.loaded.gitsigns

        -- Navigation with ]c & [c
        vim.keymap.set("n", "]c", function()
          if vim.wo.diff then
            return "]c"
          end
          vim.schedule(function()
            gs.next_hunk()
          end)
          return "<Ignore>"
        end, { expr = true, buffer = buffer, desc = "Next Hunk/Diff" })

        vim.keymap.set("n", "[c", function()
          if vim.wo.diff then
            return "[c"
          end
          vim.schedule(function()
            gs.prev_hunk()
          end)
          return "<Ignore>"
        end, { expr = true, buffer = buffer, desc = "Prev Hunk/Diff" })

        local function map(mode, l, r, desc)
          vim.keymap.set(mode, l, r, { buffer = buffer, desc = desc })
        end

        -- Actions
        map({ "n", "v" }, "<leader>hs", ":Gitsigns stage_hunk<CR>")
        map({ "n", "v" }, "<leader>hr", ":Gitsigns reset_hunk<CR>")
        map("n", "<leader>hS", gs.stage_buffer)
        map("n", "<leader>hu", gs.undo_stage_hunk)
        map("n", "<leader>hR", gs.reset_buffer)
        map("n", "<leader>hp", gs.preview_hunk)

        -- blame
        map("n", "<leader>gb", gs.toggle_current_line_blame)
        map("n", "<leader>gB", function()
          gs.blame_line({ full = true })
        end)

        -- diffthis
        map("n", "<leader>gD", function()
          gs.diffthis("master")
        end)
        map("n", "<leader>gd", function()
          gs.diffthis("~")
        end)
      end,
    },
    keys = {
      {
        "<leader>gh",
        "<cmd>Gdiff head<cr>",
        desc = "Open Git diff on HEAD",
        mode = "n",
      },
      {
        "<leader>gm",
        "<cmd>Gdiff main<cr>",
        desc = "Open Git diff on main",
        mode = "n",
      },
    },
    config = function(_, opts)
      local gs = require("gitsigns")
      gs.setup(opts)

      -- Define our custom user command
      vim.api.nvim_create_user_command("Gdiff", function(ctx)
        gs.diffthis(ctx.args)
      end, { nargs = "*" })
    end,
  },
  { -- indentline
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    enabled = true,
    lazy = false,
    opts = {
      indent = { char = "┊", highlight = "GruvboxBg1" },
      whitespace = { remove_blankline_trail = true, highlight = "GruvboxBg1" },
      scope = { enabled = false },
      exclude = {
        filetypes = {
          "lspinfo",
          "checkhealth",
          "help",
          "man",
          "gitcommit",
          "startify",
          "markdown",
          "vim",
          "tex",
          "fzf",
          "TelescopePrompt",
          "TelescopeResults",
        },
      },
    },
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
        ft = { "html", "vue", "typescriptreact", "svelte", "lua", "vim" },
      },
      { "windwp/nvim-ts-autotag" },
      { -- vim-matchup - better %
        "andymass/vim-matchup",
        -- enabled = false,
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
          -- scope_incremental = "<nop>",
          -- node_decremental = "<nop>",
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

            -- html tags:
            ["at"] = "@function.outer",
            ["it"] = "@function.inner",
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
        -- lsp_interop = {
        --   enable = true,
        --   peek_definition_code = {
        --     ["<leader>fd"] = "@function.outer",
        --     ["<leader>fD"] = "@class.outer",
        --   },
        -- },
      },
      -- 'JoosepAlviste/nvim-ts-context-commentstring' -- auto deduce comment string on context
      ts_context_commentstring = {
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
        enable_rename = true,
        enable_close = true,
        enable_close_on_slash = false,
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
  { -- tpope/vim-sleuth - heuristic for setting shiftwidth and expandtab
    "tpope/vim-sleuth",
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
    keys = {
      {
        "<leader>gg",
        "<cmd>DiffviewClose<cr>",
        desc = "Close diffview",
        mode = "n",
      },
      {
        "<leader>gH",
        "<cmd>DiffviewFileHistory %<cr>",
        desc = "Open diffview history on current file",
        mode = "n",
      },
      -- {
      --   "<leader>gH",
      --   "<cmd>DiffviewFileHistory<cr>",
      --   desc = "Open diffview history on repository",
      --   mode = "n",
      -- },
      {
        "<leader>gf",
        function()
          require("diffview").open("HEAD", vim.api.nvim_buf_get_name(0))
        end,
        desc = "Open diffview merge on current file against HEAD",
      },
    },
  },
  { -- fzf-lua
    "ibhagwan/fzf-lua",
    config = function()
      require("wax.plugcfg.fzf")
    end,
    keys = {
      ---------- Grep ----------
      {
        "<leader>a",
        function()
          require("wax.plugcfg.fzf").fzf_grep()
        end,
        desc = "Fuzzy search content of files",
      },
      {
        "<leader>A",
        function()
          require("wax.plugcfg.fzf").live_grep()
        end,
        desc = "RipGrep content of files",
      },
      {
        "<leader>ff",
        function()
          require("wax.plugcfg.fzf").grep_word_under_cursor()
        end,
        desc = "RipGrep with search being the current word under the cursor",
      },
      ---------- Files ----------
      {
        "<leader>p",
        function()
          require("wax.plugcfg.fzf").rg_files()
        end,
        desc = "Find git files",
      },
      {
        "<leader>P",
        function()
          require("wax.plugcfg.fzf").rg_files("--no-ignore-vcs")
        end,
        desc = "Find files",
      },
      ---------- Misc ----------
      {
        "<leader>fe",
        function()
          require("fzf-lua").builtin()
        end,
        desc = "Fzf Lua Builtin",
      },
      {
        "∂", -- option + d
        function()
          require("fzf-lua").command_history()
        end,
        desc = "Fzf Command History",
        mode = { "n", "i", "c" },
      },
      {
        "z=",
        function()
          require("fzf-lua").spell_suggest()
        end,
        desc = "Fzf Spell Suggest",
      },
      {
        "<leader>n",
        function()
          require("fzf-lua").buffers()
        end,
        desc = "Fzf Opened Buffers",
      },
      ---------- LSP ----------
      {
        "<leader>r",
        function()
          require("wax.plugcfg.fzf").lsp_references()
        end,
        desc = "Fzf Lsp References of word under cursor",
      },
      ------- Custom -------
      {
        "<leader>fw",
        function()
          require("wax.plugcfg.fzf").wax_files()
        end,
        desc = "Find file among dotfiles",
      },
      {
        "<leader>q",
        function()
          require("wax.plugcfg.fzf").select_project_find_file()
        end,
        desc = "Select project then find file.",
      },
      {
        "<leader>Q",
        function()
          require("wax.plugcfg.fzf").select_project_fzf_grep()
        end,
        desc = "Select project then grep files.",
      },
    },
  },
  { -- grapple
    "cbochs/grapple.nvim",
    tag = "v0.8.1",
    -- dev = true, -- use "~/src/grapple.nvim/"
    lazy = false,
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
    -- ft = { "python", "typescript", "vue" },
    opts = function()
      local ai = require("mini.ai")
      return {
        search_method = "cover_or_nearest",
        n_lines = 500,
        mappings = {
          -- Main textobject prefixes
          around = "a",
          inside = "i",

          -- Next/last variants
          around_next = "an",
          inside_next = "in",
          around_last = "al",
          inside_last = "il",

          -- Move cursor to corresponding edge of `a` textobject
          goto_left = "g[",
          goto_right = "g]",
        },
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
    enabled = false,
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
        auto_refresh = true,
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
      suggestion = { enabled = false },
      -- server_opts_overrides = {
      --   settings = {
      --     inlineSuggest = { enabled = false },
      --     editor = {
      --       showEditorCompletions = false,
      --       enableAutoCompletions = false,
      --     },
      --     advanced = {
      --       top_p = 0.70,
      --       listCount = 3, -- #completions for panel
      --       inlineSuggestCount = 0, -- #completions for getCompletions
      --       enableAutoCompletions = false,
      --     },
      --   },
      -- },
    },
  },
  { -- null-ls
    "nvimtools/none-ls.nvim",
    commit = "1dad329b3899413e7e8e03412b2489dbcda5f7e4",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" }, -- used for python-utils
    config = function()
      vim.g.nonels_supress_issue58 = true
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
    -- enabled = false,
    dependencies = {
      { "linrongbin16/lsp-progress.nvim", opts = {} },
      { "folke/neodev.nvim", opts = { experimental = { pathStrict = true } } },
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
      vim.api.nvim_set_option_value("omnifunc", "v:lua.vim.lsp.omnifunc", {})

      local have_mason, mlsp = pcall(require, "mason-lspconfig")

      local excluded_auto_install = { "pylsp" }
      local excluded_ensure_install = { "lua_ls" }

      if have_mason then
        local handlers = waxlsp.create_mason_handlers()

        local ensure_installed = vim.tbl_keys(handlers)
        ensure_installed = vim.tbl_filter(function(server_name)
          return not vim.tbl_contains(excluded_ensure_install, server_name)
        end, ensure_installed)

        mlsp.setup({
          ensure_installed = ensure_installed,
          automatic_installation = { exclude = excluded_auto_install },
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
      "rcarriga/cmp-dap",
    },
    config = function()
      require("wax.plugcfg.nvim-cmp")
    end,
  },

  { -- conform.nvim  (better buffer lsp format)
    "stevearc/conform.nvim",
    keys = {
      {
        "<leader>m",
        "<cmd>lua require('conform').format({lsp_fallback=true})<cr>",
        desc = "Conform Format",
        mode = { "n", "v" },
      },
    },
    config = function()
      require("wax.lsp.conform")
    end,
  },

  -- DAP
  { import = "wax.debugger" },

  --------- Language Specific ---------
  { "edgedb/edgedb-vim", ft = { "edgedb", "edgeql" } },
  { "Vimjas/vim-python-pep8-indent", ft = "python", pin = true },

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
    lazy = true,
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
