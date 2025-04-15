-- Investigate:
-- https://github.com/cshuaimin/ssr.nvim
-- https://github.com/monaqa/dial.nvim

return {
  --------- UI ---------
  {
    "mhinz/vim-startify",
    lazy = false,
  },
  {
    "rktjmp/lush.nvim",
    dependencies = {
      -- robustify when missing WAXPATH env variable (e.g. sudo vim)
      {
        dir = vim.env.WAXPATH and vim.env.WAXPATH .. "/colorschemes/nord" or "/tmp",
        lazy = true,
      },
      {
        dir = vim.env.WAXPATH and vim.env.WAXPATH .. "/colorschemes/gruvbox" or "/tmp",
        lazy = true,
      },
    },
    init = function()
      vim.o.termguicolors = true
      pcall(vim.cmd, "colorscheme nord")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "linrongbin16/lsp-progress.nvim" },
    lazy = false,
    config = function()
      require("wax.plugcfg.lualine")
    end,
  },
  {
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
      exclude_name = { "", "[dap-repl]" },
    },
    keys = {
      { "œ", "<cmd>BufferPrevious<cr>", desc = "Previous buffer", mode = { "n", "i" } },
      { "∑", "<cmd>BufferNext<cr>", desc = "Next buffer", mode = { "n", "i" } },
      { "®", "<cmd>BufferClose<cr>", desc = "Close buffer", mode = { "n", "i" } },
      -- {
      --   "©", -- option + g
      --   function()
      --     vim.cmd("BufferCloseAllButCurrent")
      --     vim.cmd([[exec "normal \<c-w>\<c-o>"]])
      --   end,
      --   desc = "Close all buffer except current",
      --   mode = { "n", "i" },
      -- },
    },
  },
  {
    "stevearc/dressing.nvim",
    lazy = false,
    opts = {
      builtin = { enabled = false },
      select = { enabled = true, fzf_lua = { winopts = { height = 0.5, width = 0.5 } } },
      input = { enabled = true, win_options = { winblend = 0 } },
    },
  },
  {
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
  {
    "echasnovski/mini.indentscope",
    lazy = false,
    opts = {
      mappings = {},
      draw = {
        delay = 100, -- ms
        animation = function(s, n)
          return 0
        end,
      },
      symbol = "│",
      options = { try_as_border = true },
    },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = {
          "mason",
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
        callback = function()
          vim.b.miniindentscope_disable = true
        end,
      })
    end,
  },
  {
    "kevinhwang91/nvim-hlslens",
    event = "VeryLazy",
    config = function()
      require("wax.plugcfg.hlslens")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    -- dev = true, -- use "~/src/nvim-treesitter/"
    event = { "BufReadPost", "BufNewFile" },
    dependencies = {
      -- { -- playground
      --   "nvim-treesitter/playground",
      --   keys = {
      --     {
      --       "<leader>xc",
      --       "<cmd>TSHighlightCapturesUnderCursor<cr>",
      --       desc = "Show TS higlight under the cursor",
      --       mode = "n",
      --     },
      --   },
      --   cmd = "TSPlaygroundToggle",
      -- },
      { "nvim-treesitter/nvim-treesitter-textobjects" },
      { -- nvim-ts-context-commentstring
        "JoosepAlviste/nvim-ts-context-commentstring",
        lazy = true,
        ft = { "html", "vue", "typescriptreact", "svelte", "lua", "vim", "tsx" },
      },
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
      { -- 'windwp/nvim-ts-autotag'  -- auto close/rename html tags
        "windwp/nvim-ts-autotag",
        event = { "BufReadPre", "BufNewFile" },
        config = function(_, opts)
          require("nvim-ts-autotag").setup({
            opts = {
              -- enable = true,
              enable_close = true,
              enable_rename = true,
              enable_close_on_slash = false,
              aliases = { ["jinja.html"] = "html" },
            },
          })
        end,
      },
    },
    build = ":TSUpdate",
    init = function()
      vim.treesitter.language.register("jinja.html", "html")
      vim.treesitter.language.register("bash", "zsh")
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
          "nix",
        },
      },
      ensure_installed = {
        -- Generic:
        "nix",
        "bash",
        "jsonc",
        "yaml",
        "lua",
        "ql",
        "query",
        "regex",
        "toml",
        "markdown",
        "git_config",
        "git_rebase",
        "gitcommit",
        "diff",
        "make",
        -- Frontend:
        "graphql",
        "html",
        "css",
        "scss",
        -- "jsdoc",
        "javascript",
        "typescript",
        "tsx",
        "svelte",
        "vue",
        -- Backend:
        "sql",
        "go",
        "rust",
        "python",
        -- Infra:
        "helm",
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
        config = {
          -- ["jinja.html"] = "{# %s #}",
        },
      },
      -- 'andymass/vim-matchup' -- better the '%'
      matchup = {
        enable = true,
        disable_virtual_text = true,
      },
    },
    config = function(_, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },

  --------- Deemed Necessary ---------
  {
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    "mbbill/undotree",
    keys = {
      { "<leader>u", "<cmd>UndotreeToggle<cr>", desc = "UndotreeToggle", mode = "n" },
    },
  },
  {
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
  {
    "janko/vim-test",
    lazy = false,
    -- dev = true,
    pin = true,
    event = "VeryLazy",
    config = function()
      require("wax.plugcfg.vim-test")
    end,
  },
  {
    "tpope/vim-sleuth", -- heuristic for setting shiftwidth and expandtab
  },
  {
    "tpope/vim-eunuch", -- sugar for shell commands
    cmd = { "Move", "Copy", "Rename", "Delete" },
  },
  {
    "tpope/vim-scriptease",
    cmd = "Messages",
  },
  {
    "sindrets/diffview.nvim", -- git integration for nvim
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
  {
    "ibhagwan/fzf-lua",
    config = function()
      require("wax.plugcfg.fzf")
    end,
    keys = {
      ---------- Grep ----------
      {
        "<leader>a",
        function()
          require("wax.plugcfg.fzf").fzf_grep(find_root_monorepo())
        end,
        desc = "Fuzzy search content of files (entire monorepo)",
      },
      {
        "<leader>A",
        function()
          require("wax.plugcfg.fzf").fzf_grep(find_root_package()) -- default to find_root_package
        end,
        desc = "Fuzzy search content of files (package first)",
      },
      ---------- Word Under Cursor ----------
      {
        "<leader>ff",
        function()
          require("wax.plugcfg.fzf").grep_cword(find_root_monorepo())
        end,
        desc = "RipGrep with search being the current word under the cursor (entire monorepo)",
      },
      {
        "<leader>fF",
        function()
          require("wax.plugcfg.fzf").grep_cword(find_root_package())
        end,
        desc = "RipGrep with search being the current word under the cursor (package first)",
      },
      ---------- Files ----------
      {
        "<leader>p",
        function()
          require("wax.plugcfg.fzf").rg_files(find_root_monorepo())
        end,
        desc = "Find git files (all monorepo)",
      },
      {
        "<leader>P",
        function()
          require("wax.plugcfg.fzf").rg_files(find_root_package())
        end,
        desc = "Find git files (package first)",
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
        "<leader>fh",
        function()
          require("fzf-lua/providers/colorschemes").highlights()
        end,
        desc = "Fzf Lua Highlights",
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
  {
    "cbochs/grapple.nvim",
    tag = "v0.8.1",
    -- dev = true, -- use "~/src/grapple.nvim/"
    lazy = false,
    config = function()
      require("wax.plugcfg.grapple")
    end,
  },

  --------- Enrich Actions ---------
  {
    "AndrewRadev/splitjoin.vim",
    event = "VeryLazy",
  },
  {
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
  {
    "echasnovski/mini.pairs",
    event = "VeryLazy",
    config = function(_, opts)
      require("mini.pairs").setup(opts)
    end,
  },
  {
    "echasnovski/mini.align",
    event = "VeryLazy",
    opts = {
      mappings = {
        start = "<leader>ta",
        start_with_preview = "<leader>tA",
      },
    },
  },
  {
    "echasnovski/mini.ai", -- (arround/inside improved)
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
  {
    "numToStr/Comment.nvim",
    lazy = false,
    opts = {
      ignore = "^$", -- ignore empty lines
      sticky = true,
      toggler = {
        -- line-comment keymap
        line = "<leader>cc",
        ---block-comment keymap
        -- block = "<leader>bc",
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
      -- pre_hook = function()
      --   require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
      -- end,
      pre_hook = function()
        -- https://github.com/numToStr/Comment.nvim/pull/62#issuecomment-972790418
        -- Fix builtin Comment behaviour by using ts_context_commentstring:
        if vim.tbl_contains({ "vue", "svelte", "scss", "typescriptreact" }, vim.bo.filetype) then
          require("ts_context_commentstring.internal").update_commentstring()
          return vim.o.commentstring
        end

        -- if vim.bo.filetype == "typescriptreact" then
        --   local fn = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
        --   return fn()
        -- end
      end,
    },
  },

  --------- LSP ---------
  {
    "milanglacier/minuet-ai.nvim",
    event = "VeryLazy",
    config = function()
      require("wax.plugcfg.minuet-ai")
    end,
  },

  {
    "L3MON4D3/LuaSnip",
    event = "VeryLazy",
    config = function()
      require("wax.plugcfg.luasnip")
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    -- enabled = false,
    dependencies = {
      { "linrongbin16/lsp-progress.nvim", opts = {} },
      -- { "saghen/blink.cmp" },
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

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("wax-lsp-attach", { clear = true }),
        callback = function(event)
          waxlsp.set_lsp_keymaps(event.buf)
        end,
      })

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

  {
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

  -- {
  --   "saghen/blink.cmp",
  --   version = "v1.1.1",
  --   dependencies = {
  --     "mikavilpas/blink-ripgrep.nvim",
  --   },
  --   config = function()
  --     require("wax.plugcfg.blink-cmp")
  --   end,
  -- },

  {
    "stevearc/conform.nvim", --  (better buffer lsp format)
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
  { "towolf/vim-helm", ft = { "yaml", "smarty" } },

  --------- NeoVim Perf / Dev ---------
  {
    "dstein64/vim-startuptime", -- analyze startup time
    cmd = "StartupTime",
  },
  {
    "stevearc/profile.nvim", -- profiler with flamegraph
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
            { prompt = "Save profile to:", completion = "file", default = "/tmp/nvim-profile.json" },
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
      vim.keymap.set("", "<leader>fP", _G.toggle_profile)
    end,
  },

  --------- Funky bits ---------
  {
    "Eandrju/cellular-automaton.nvim",
    lazy = true,
    keys = {
      {
        "<leader>fl",
        function()
          vim.cmd([[norm! zR]])
          vim.cmd([[CellularAutomaton make_it_rain]])
        end,
        desc = "Who will bring the rain ?",
        nowait = true,
      },
    },
    cmd = "CellularAutomaton",
  },
}
