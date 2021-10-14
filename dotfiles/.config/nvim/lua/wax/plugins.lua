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
    use({
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
    use("junegunn/vim-easy-align") -- easy alignment, better than tabularize
    use({ "vim-scripts/loremipsum", cmd = "Loremipsum" }) -- dummy text generator (:Loremipsum [number of words])

    use({
      "tomtom/tcomment_vim", -- for contextual comment, see nvim-treesitter-textobjects
      config = function()
        vim.cmd([[
          let g:tcomment_opleader1 = '<leader>c'
          " https://github.com/tomtom/tcomment_vim/issues/284#issuecomment-809956888
          let g:tcomment#filetype#guess_vue = 0
        ]])
      end,
    })
    use({
      "christoomey/vim-tmux-navigator", -- tmux navigation in love with vim
      config = function()
        require("wax.plugins.vim-tmux-navigator")
      end,
    })
    use({
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
    use({
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
    use("tjdevries/colorbuddy.nvim") -- help to write its own colorscheme
    use({
      "itchyny/lightline.vim", -- light status line
      config = function()
        require("wax.plugins.lightline")
      end,
      -- after="lspconfig",  -- use lsp-status
    })
    -- use { 'hoob3rt/lualine.nvim',
    --   -- requires = {'kyazdani42/nvim-web-devicons', opt = true},
    --   after="nvim-web-devicons",
    --   config = function() require("wax.plugins.lualine") end,
    -- }
    -- use("ap/vim-buftabline", require("numtostr/BufOnly.nvim")) -- buffer line
    use({
      "romgrk/barbar.nvim",
      config = function()
        require("wax.plugins.barbar")
      end,
    })

    use({
      "kyazdani42/nvim-web-devicons",
      config = function()
        require("nvim-web-devicons").setup()
      end,
    }) -- icons
    use("mhinz/vim-startify") -- fancy start screen
    use({
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
    use({
      "Yggdroot/indentLine", -- indent line
      config = function()
        require("wax.plugins.indent-line")
      end,
    })

    -- use 'kshenoy/vim-signature'        -- toggle display marks
    use({
      "wincent/loupe", -- better focus on current highlight search
      config = function()
        vim.g.LoupeClearHighlightMap = 0
        vim.g.LoupeVeryMagic = 0
      end,
    })

    use("rhysd/conflict-marker.vim") -- conflict markers for vimdiff

    --------- Fuzzy Fuzzy Fuzzy ---------
    use({
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
    use({
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
    use({
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
          commit = "5024c83e92c3988f6e7119bfa1b2347ae3a42c3e", -- after it works no more
          ft = { "html", "vue" },
        },
        -- { "p00f/nvim-ts-rainbow" },
        { -- add better behavior for '%'
          "andymass/vim-matchup",
          config = function()
            vim.cmd([[
              hi MatchBackground cterm=none ctermbg=none

              hi MatchParenCur cterm=none ctermbg=none
              hi MatchParen cterm=none ctermbg=none

              hi MatchWord cterm=underline ctermbg=none
              hi MatchWordCur cterm=underline ctermbg=none
            ]])
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
        { "kabouzeid/nvim-lspinstall", branch = "main" },
        -- { os.getenv("HOME") .. "/src/nvim-lspinstall", branch = "main" },
        "ray-x/lsp_signature.nvim", -- a bit buggy
        lock = true,
      },
      config = function()
        require("wax.lsp")
      end,
    })
    use({ -- nvim-cmp
      "hrsh7th/nvim-cmp",
      -- commit = "a63a1a23e9a7e62b21a5c151c771ed6ca21a0990",
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
