local download_packer = function()
  print("Downloading packer.nvim...")

  local directory = string.format("%s/site/pack/packer/opt", vim.fn.stdpath("data"))
  vim.fn.mkdir(directory, "p")

  local out = vim.fn.system(
    string.format(
      "git clone %s %s",
      "https://github.com/wbthomason/packer.nvim",
      directory .. "/packer.nvim"
    )
  )

  print(out)
  print("Downloaded packer.nvim")
  print("Reopen NVIM and run :PackerSync twice")
end

local packer_exists = pcall(vim.cmd, [[packadd packer.nvim]]) -- works even if packer in your `opt` pack
if not packer_exists then
  download_packer()
  return
end

-- Auto recompile packer on changes
vim.api.nvim_exec(
  [[
  autocmd BufWritePost plugins.lua PackerCompile
  ]],
  false
)

return require("packer").startup({
  function(use)
    -- Packer can manage itself as an optional plugin
    use({ "wbthomason/packer.nvim", opt = true })

    --- Performances plugins
    use("lewis6991/impatient.nvim") -- speed up startup TODO: remove it once merged upstream
    use({ -- combine all autocmds on filetype into one
      "nathom/filetype.nvim",
      config = function()
        vim.g.did_load_filetypes = 1
      end,
    })
    use({ -- FixCursorHold
      "antoinemadec/FixCursorHold.nvim", -- Fix CursorHold Performance
      config = function()
        -- in millisecond, used for both CursorHold and CursorHoldI,
        -- use updatetime instead if not defined
        vim.g.cursorhold_updatetime = 100
      end,
    })

    --------- System Plugins ---------
    use("AndrewRadev/splitjoin.vim") -- easy split join on whole paragraph
    use("wellle/targets.vim") -- text object for parenthesis & more !
    use("michaeljsmith/vim-indent-object") -- text object based on indentation levels.
    -- use 'psliwka/vim-smoothie'                     -- smoother scroll

    use("justinmk/vim-sneak") -- minimalist motion with 2 keys
    -- use("ggandor/lightspeed.nvim") -- better vim-sneak ?
    use("junegunn/vim-easy-align") -- easy alignment, better than tabularize
    use({ "vim-scripts/loremipsum", cmd = "Loremipsum" }) -- dummy text generator (:Loremipsum [number of words])

    use({ -- easy comment/uncomment
      "numToStr/Comment.nvim",
      config = function()
        require("wax.plugins.comment")
      end,
    })
    use({ -- vim-tmux-navigator
      "christoomey/vim-tmux-navigator", -- tmux navigation in love with vim
      config = function()
        require("wax.plugins.vim-tmux-navigator")
      end,
    })
    use({ -- vim-test
      "janko/vim-test", -- test at the speed of light
      requires = {
        "jgdavey/tslime.vim", -- send command from vim to a running tmux session
        branch = "main",
      },
      config = function()
        require("wax.plugins.vim-test")
      end,
    })

    -- Tpope is awesome
    use("tpope/vim-surround") -- change surrounding easily
    use("tpope/vim-eunuch") -- sugar for the UNIX shell commands
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
    use("tpope/vim-scriptease") -- gives :Messages

    -- use 'airblade/vim-rooter'

    --------- User Interface ---------
    use("morhetz/gruvbox")
    use("mhartington/oceanic-next")
    use("shaunsingh/nord.nvim")
    -- use("tjdevries/colorbuddy.nvim") -- help to write its own colorscheme
    use({ -- lightline
      "itchyny/lightline.vim", -- light status line
      config = function()
        require("wax.plugins.lightline")
      end,
      -- after="lspconfig",  -- use lsp-status
    })
    use({ -- barbar
      "romgrk/barbar.nvim",
      config = function()
        require("wax.plugins.barbar")
      end,
    })

    use({ -- nvim-web-devicons
      "kyazdani42/nvim-web-devicons",
      config = function()
        require("nvim-web-devicons").setup()
      end,
    }) -- icons
    use("mhinz/vim-startify") -- fancy start screen
    use({ -- gitsigns
      "lewis6991/gitsigns.nvim",
      config = function()
        require("gitsigns").setup({
          attach_to_untracked = false,
          update_debounce = 500,
          max_file_length = 1000,
        })
      end,
    }) -- git sign column

    -- Waiting for https://github.com/nanotee/nvim-lua-guide
    -- use {'glepnir/indent-guides.nvim', -- indent guide
    --   config = function() require('wax.plugins.indent-guides') end,
    -- }
    use({ -- indentLine
      "Yggdroot/indentLine", -- indent line
      config = function()
        require("wax.plugins.indent-line")
      end,
    })

    -- use 'kshenoy/vim-signature'        -- toggle display marks
    use({ -- loupe
      "wincent/loupe", -- better focus on current highlight search
      config = function()
        vim.g.LoupeClearHighlightMap = 0
        vim.g.LoupeVeryMagic = 0
      end,
    })

    use("rhysd/conflict-marker.vim") -- conflict markers for vimdiff

    --------- Fuzzy Fuzzy Fuzzy ---------
    use({ -- telescope
      "nvim-telescope/telescope.nvim",
      -- lock = true,
      requires = {
        "nvim-lua/popup.nvim",
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", branch = "main", run = "make" },
        { -- clipboard integration in telescope
          "AckslD/nvim-neoclip.lua",
          config = function()
            require("neoclip").setup()
          end,
        },
      },
      config = function()
        require("wax.plugins.telescope")
      end,
    })
    use({ -- fzf.vim
      "junegunn/fzf.vim",
      requires = {
        "junegunn/fzf",
        run = "./install --all",
      },
      config = function()
        require("wax.plugins.fzf")
      end,
    })

    --------- TreeSitter ---------
    use({ -- treesitter
      "nvim-treesitter/nvim-treesitter",
      -- commit = '006aceb574e90fdc3dc911b76ecb7fef4dd0d609',
      lock = true,
      run = ":TSUpdate",
      requires = {
        { -- play with queries
          "nvim-treesitter/playground",
          cmd = "TSPlaygroundToggle",
        },
        { -- better text objects
          "nvim-treesitter/nvim-treesitter-textobjects",
        },
        { -- comment string update on context (vue -> html + typescript)
          "JoosepAlviste/nvim-ts-context-commentstring",
          ft = { "html", "vue" },
          config = function()
            require("nvim-treesitter.configs").setup({
              context_commentstring = {
                enable = true,
                enable_autocmd = false,
              },
            })
          end,
        },
        -- { "p00f/nvim-ts-rainbow" },
        { -- add better behavior for '%'
          "andymass/vim-matchup",
          config = function()
            require("wax.plugins.vim-matchup")
          end,
        },
        { -- auto html tag
          "windwp/nvim-ts-autotag",
          branch = "main",
          ft = { "html", "vue" },
        },
      },
      config = function()
        require("wax.plugins.treesitter")
      end,
    })

    --------- LSP ---------
    use({
      "neovim/nvim-lspconfig",
      requires = {
        "nvim-lua/lsp-status.nvim",
        { -- nvim-lsp-installer
          "williamboman/nvim-lsp-installer",
          -- os.getenv("HOME") .. "/src/nvim-lsp-installer",
          branch = "main",
          config = function()
            require("wax.plugins.nvim-lsp-installer")
          end,
        },
        "ray-x/lsp_signature.nvim", -- a bit buggy
        lock = true,
      },
      config = function()
        require("wax.lsp")
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
            require("wax.plugins.luasnip")
          end,
        },
        { -- auto pair written in lua
          "windwp/nvim-autopairs",
          config = function()
            require("wax.plugins.nvim-autopairs")
          end,
        },
      },
      config = function()
        require("wax.plugins.nvim-cmp")
      end,
    })

    --------- Language Specific ---------
    use({
      "mattn/emmet-vim",
      ft = { "html", "vue" },
      config = function()
        vim.cmd([[
        imap <expr> <C-d> emmet#expandAbbrIntelligent('\<tab>')
      ]])
      end,
    })
    use({ "edgedb/edgedb-vim" })
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
    profile = {
      enable = true,
      threshold = 1, -- in milliseconds
    },
  },
})
