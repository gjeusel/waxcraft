local ensure_packer = function()
  local directory = vim.fn.stdpath("data") .. "/site/pack/packer/start"
  vim.fn.mkdir(directory, "p")

  local install_path = directory .. "/packer.nvim"
  if vim.fn.empty(vim.fn.glob(install_path)) == 0 then
    return false
  end

  print("Downloading packer.nvim...")
  local out = vim.fn.system(
    string.format(
      "git clone --depth 1 %s %s",
      "https://github.com/wbthomason/packer.nvim",
      directory .. "/packer.nvim"
    )
  )

  print("Downloaded packer at " .. out)
  vim.cmd([[packadd packer.nvim]])
  return true
end

local packer_bootstrap = ensure_packer()

-- Auto recompile packer on changes
vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins.lua source <afile> | PackerCompile
  augroup end
]])

return require("packer").startup({
  function(use)
    -- Packer can manage itself as an optional plugin
    use({ "wbthomason/packer.nvim" })

    -- Analyze startuptime
    use({ "dstein64/vim-startuptime", cmd = "StartupTime" })

    -- plenary is used everywhere - even in utils
    use({ "nvim-lua/plenary.nvim" })

    --------- System Plugins ---------
    use("AndrewRadev/splitjoin.vim") -- easy split join on whole paragraph
    use("michaeljsmith/vim-indent-object") -- text object based on indentation levels.
    use({ "vim-scripts/loremipsum", cmd = "Loremipsum" }) -- dummy text generator (:Loremipsum [number of words])

    use({ -- the next vim-sneak
      "ggandor/lightspeed.nvim",
      config = function()
        safe_require("wax.plugins.lightspeed")
      end,
    })

    use({ -- mini for lot of small life quality improvements
      "echasnovski/mini.nvim",
      config = function()
        safe_require("mini.ai").setup()
      end,
    })

    -- key bindings cheatsheet
    use({
      "folke/which-key.nvim",
      config = function()
        safe_require("which-key")
      end,
      cmd = "WhichKey",
    })

    use({ -- nvim-surround
      "kylechui/nvim-surround",
      tag = "main",
      config = function()
        safe_require("nvim-surround").setup({})
      end,
    })

    use({ -- easy comment/uncomment
      "numToStr/Comment.nvim",
      config = function()
        safe_require("wax.plugins.comment")
      end,
    })
    use({ -- vim-tmux-navigator
      "christoomey/vim-tmux-navigator", -- tmux navigation in love with vim
      config = function()
        safe_require("wax.plugins.vim-tmux-navigator")
      end,
    })
    use({ -- vim-test
      "janko/vim-test", -- test at the speed of light
      requires = {
        "jgdavey/tslime.vim", -- send command from vim to a running tmux session
        branch = "main",
      },
      config = function()
        safe_require("wax.plugins.vim-test")
      end,
    })
    use({ -- nvim-dap
      "mfussenegger/nvim-dap",
      -- "~/src/nvim-dap",
      requires = {
        "theHamsta/nvim-dap-virtual-text",
        "rcarriga/nvim-dap-ui",
        "mfussenegger/nvim-dap-python",
      },
      config = function()
        safe_require("wax.plugins.nvim-dap")
      end,
    })

    -- use({ -- ultra fold
    --   "kevinhwang91/nvim-ufo",
    --   requires = "kevinhwang91/promise-async",
    --   config = function()
    --     safe_require("wax.plugins.folds-ufo")
    --   end,
    -- })
    -- use({
    --   "Konfekt/FastFold",
    --   config = function()
    --     -- FastFold:
    --     vim.g.fastfold_savehook = 0
    --   end,
    -- })
    -- use({
    --   "tmhedberg/SimpylFold",
    --   requires = "Konfekt/FastFold",
    --   config = function()
    --     -- SimpylFold:
    --     vim.g.SimpylFold_docstring_preview = 0
    --     vim.g.SimpylFold_fold_docstring = 1
    --     vim.g.SimpylFold_fold_import = 0
    --     -- FastFold:
    --     vim.g.fastfold_savehook = 0
    --   end,
    --   -- ft = { "python" },
    -- })

    -- Tpope is awesome
    use("tpope/vim-eunuch") -- sugar for the UNIX shell commands
    use({ "tpope/vim-scriptease", cmd = "Messages" }) -- gives :Messages
    use({ -- vim fugitive
      "tpope/vim-fugitive",
      config = function()
        vim.api.nvim_exec(
          [[
          command! -nargs=* Gdiff Gvdiffsplit <args>
          augroup remapTpopeFugitive
            autocmd User FugitiveObject nunmap <buffer> -
            autocmd User FugitiveObject nunmap <buffer> <CR>
          augroup end
          ]],
          false
        )
      end,
    }) -- Git wrapper for vim

    use({
      -- diffview: git integration for nvim
      "sindrets/diffview.nvim",
      config = function()
        safe_require("wax.plugins.diffview")
      end,
    })

    use({ -- help dev in lua
      "folke/neodev.nvim",
      before = "lspconfig",
      config = function()
        safe_require("neodev").setup({})
      end,
    })

    use({ -- Just Another Quickrun
      "is0n/jaq-nvim",
      config = function()
        safe_require("wax.plugins.jaq-nvim")
      end,
    })

    --------- User Interface ---------
    use("morhetz/gruvbox")
    use("mhartington/oceanic-next")
    use("shaunsingh/nord.nvim")

    use({ -- lightline
      "itchyny/lightline.vim", -- light status line
      config = function()
        safe_require("wax.plugins.lightline")
      end,
      -- after = {"lsp-status.nvim"},
    })
    use({ -- barbar
      "romgrk/barbar.nvim",
      config = function()
        safe_require("wax.plugins.barbar")
      end,
    })
    use({ -- dressing
      "stevearc/dressing.nvim",
      config = function()
        safe_require("dressing").setup({
          builtin = { enabled = false },
          select = {
            enabled = false, -- replaced by fzf-lua
            -- enabled = true,
            winblend = 0,
            -- priority list for backends:
            -- backend = { "telescope", "fzf_lua", "fzf", "builtin", "nui" },
            -- fzf_lua = { winopts = { width = 0.4, height = 0.4 } },
          },
          input = { enabled = true, winblend = 0 },
        })
      end,
    })

    use({ -- nvim-web-devicons
      "kyazdani42/nvim-web-devicons",
      config = function()
        safe_require("nvim-web-devicons").setup()
      end,
    })
    use("mhinz/vim-startify") -- fancy start screen
    use({ -- gitsigns
      "lewis6991/gitsigns.nvim",
      after = { "plenary.nvim" },
      config = function()
        safe_require("wax.plugins.gitsigns")
      end,
    })

    use({ -- indentLine
      "Yggdroot/indentLine", -- indent line
      config = function()
        vim.g.indentLine_conceallevel = 0 -- else it overwrite conceallevel on certain filetypes
        vim.g.indentLine_char = "│"
        vim.g.indentLine_color_gui = "#343d46" -- indent line color got indentLine plugin
        vim.g.indentLine_fileTypeExclude = {
          "startify",
          "markdown",
          "vim",
          "tex",
          "help",
          "man",
          "fzf",
          "packer",
          "TelescopePrompt",
        }
      end,
    })

    use({ -- better hl search
      "kevinhwang91/nvim-hlslens",
      config = function()
        safe_require("wax.plugins.hlslens")
      end,
    })

    -- use("rhysd/conflict-marker.vim") -- conflict markers for vimdiff

    --------- Fuzzy Fuzzy Fuzzy ---------
    use({
      "ibhagwan/fzf-lua",
      config = function()
        safe_require("wax.plugins.fzf")
      end,
    })

    --------- TreeSitter ---------
    use({ -- treesitter
      -- "nvim-treesitter/nvim-treesitter",
      "~/src/nvim-treesitter",
      lock = true,
      -- commit = "aebc6cf6bd4675ac86629f516d612ad5288f7868",
      -- run = ":TSUpdate",
      requires = {
        { -- play with queries
          "nvim-treesitter/playground",
          after = { "nvim-treesitter" },
          -- cmd = "TSPlaygroundToggle",
        },
        { -- better text objects
          "nvim-treesitter/nvim-treesitter-textobjects",
          after = { "nvim-treesitter" },
        },
        { -- comment string update on context (vue -> html + typescript)
          "JoosepAlviste/nvim-ts-context-commentstring",
          ft = { "html", "vue", "typescriptreact" },
          config = function()
            safe_require("nvim-treesitter.configs").setup({
              context_commentstring = {
                enable = true,
                enable_autocmd = false,
              },
            })
          end,
          after = { "nvim-treesitter" },
        },
        -- { "p00f/nvim-ts-rainbow" },
        -- { -- add better behavior for '%'
        --   "andymass/vim-matchup",
        --   config = function()
        --     safe_require("wax.plugins.vim-matchup")
        --   end,
        --   after = { "nvim-treesitter" },
        -- },
        { -- auto html tag
          "windwp/nvim-ts-autotag",
          branch = "main",
          after = { "nvim-treesitter" },
        },
      },
      config = function()
        safe_require("wax.plugins.treesitter")
      end,
    })

    --------- LSP ---------
    use({ -- lspconfig + mason
      "williamboman/mason.nvim",
      branch = "main",
      requires = {
        { "williamboman/mason-lspconfig.nvim", branch = "main" },
        "nvim-lua/lsp-status.nvim",
        "neovim/nvim-lspconfig",
        -- "ray-x/lsp_signature.nvim", -- a bit buggy
        { "jose-elias-alvarez/null-ls.nvim", branch = "main" },
        "b0o/schemastore.nvim", -- json schemas for jsonls
      },
      config = function()
        safe_require("wax.plugins.mason")
        safe_require("wax.lsp")
      end,
    })

    use({ -- nvim-cmp
      "hrsh7th/nvim-cmp",
      requires = {
        "onsails/lspkind-nvim",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-nvim-lsp",
        -- "ray-x/cmp-treesitter",
        "saadparwaiz1/cmp_luasnip",
        { -- snippet engine in lua
          "L3MON4D3/LuaSnip",
          config = function()
            safe_require("wax.plugins.luasnip")
          end,
        },
        { -- auto pair written in lua
          "windwp/nvim-autopairs",
          config = function()
            safe_require("wax.plugins.nvim-autopairs")
          end,
        },
        -- { -- GH copilot setup
        --   "zbirenbaum/copilot-cmp",
        --   module = "copilot_cmp",
        --   requires = {
        --     -- { "github/copilot.vim", branch = "release" },
        --     { "zbirenbaum/copilot.lua" },
        --   },
        --   -- event = { "VimEnter" },
        --   event = { "InsertEnter" },
        --   config = function()
        --     vim.schedule(function()
        --       safe_require("wax.plugins.gh-copilot")
        --     end)
        --   end,
        -- },
      },
      config = function()
        safe_require("wax.plugins.nvim-cmp")
      end,
    })

    --------- Language Specific ---------
    use({ "edgedb/edgedb-vim" })

    --------- Packer ---------
    -- Automatically set up your configuration after cloning packer.nvim
    -- Put this at the end after all plugins
    if packer_bootstrap then
      require("packer").sync()
    end
  end,
  config = {
    -- Move to lua dir so impatient.nvim can cache it:
    -- compile_path = vim.fn.stdpath("config") .. "/lua/packer_compiled.lua",
    auto_clean = true,
    max_jobs = 8,
    compile_on_sync = true,
    display = {
      open_fn = require("packer.util").float,
    },
    -- profile = {
    --   enable = true,
    --   threshold = 1, -- in milliseconds
    -- },
  },
})
