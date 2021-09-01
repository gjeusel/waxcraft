-- Only required if you have packer in your `opt` pack
local packer_exists = pcall(vim.cmd, [[packadd packer.nvim]])

local download_packer = function()
  if vim.fn.input("Download Packer? (y for yes)") ~= "y" then
    return
  end

  print("Downloading packer.nvim...")
  local directory = string.format("%s/site/pack/packer/opt/", vim.fn.stdpath("data"))

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
    use({
      "wbthomason/packer.nvim",
      opt = true,
      commit = "a5f3d1ae5c570ac559f4b8103980d53497601d4e",
    })

    --------- System Plugins ---------
    use({
      "famiu/nvim-reload", -- easy reaload
      requires = "nvim-lua/plenary.nvim",
      config = function()
        require("wax.plugins.nvim-reload")
      end,
    })

    -- use()
    use("AndrewRadev/splitjoin.vim") -- easy split join on whole paragraph
    use("wellle/targets.vim") -- text object for parenthesis & more !
    use("michaeljsmith/vim-indent-object") -- text object based on indentation levels.
    -- use 'psliwka/vim-smoothie'                     -- smoother scroll

    use({
      "antoinemadec/FixCursorHold.nvim", -- Fix CursorHold Performance
      config = function()
        require("wax.plugins.fixcursorhold")
      end,
    })

    use("justinmk/vim-sneak") -- minimalist motion with 2 keys
    use("junegunn/vim-easy-align") -- easy alignment, better than tabularize
    use("vim-scripts/loremipsum") -- dummy text generator (:Loremipsum [number of words])

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
    use("tpope/vim-repeat") -- better action repeat for vim-surround with .
    use("tpope/vim-eunuch") -- sugar for the UNIX shell commands
    use("tpope/vim-fugitive") -- Git wrapper for vim
    use("tpope/vim-abolish") -- :S to replace with smartcase
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
        require("gitsigns").setup()
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

    use({ -- non-obtrusive registers preview
      "tversteeg/registers.nvim",
      setup = function()
        vim.g.registers_return_symbol = "⤶"
        -- vim.g.registers_space_symbol = "•"
        -- vim.g.registers_tab_symbol = "•"
        vim.g.registers_space_symbol = " "
        vim.g.registers_tab_symbol = " "
        vim.g.registers_show_empty_registers = 0 -- do not show it
        vim.g.registers_trim_whitespace = 0 -- do show spaces
        vim.g.registers_show_empty_registers = 0 -- do not show empty registers
      end,
    })

    --------- Fuzzy Fuzzy Fuzzy ---------
    use({
      "nvim-telescope/telescope.nvim",
      lock = true,
      requires = {
        "nvim-lua/popup.nvim",
        "nvim-lua/plenary.nvim",
        { "nvim-telescope/telescope-fzf-native.nvim", branch = "main", run = "make" },
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
      run = function()
        vim.cmd([[TSUpdate]])
      end,
      requires = {
        { -- play with queries
          "nvim-treesitter/playground",
        },
        { -- better text objects
          "nvim-treesitter/nvim-treesitter-textobjects",
        },
        { -- comment string update on context (vue -> html + typescript)
          "JoosepAlviste/nvim-ts-context-commentstring",
          -- Lock on specific commit: https://github.com/wbthomason/packer.nvim/issues/211
          commit = "5024c83e92c3988f6e7119bfa1b2347ae3a42c3e",
          lock = true,
          ft = { "html", "vue" },
        },
        -- { "p00f/nvim-ts-rainbow", cond = conditional_python }, -- rainbow parenthesis
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
    use({
      "hrsh7th/nvim-compe",
      branch = "master",
      requires = {
        "SirVer/ultisnips",
        { -- auto pair written in lua
          "windwp/nvim-autopairs",
          config = function()
            require("wax.plugins.nvim-autopairs")
          end,
        },
      },
      config = function()
        require("wax.plugins.nvim-compe")
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
    -- use({ -- better python folds
    --   "tmhedberg/SimpylFold",
    --   requires = { "Konfekt/FastFold" },
    --   ft = { "python" },
    --   config = function()
    --     vim.g.SimpylFold_docstring_preview = 0
    --     vim.g.SimpylFold_fold_docstring = 1
    --     vim.g.SimpylFold_fold_import = 0
    --
    --     vim.g.fastfold_force = 1 -- pass by fastfold for all foldmethods
    --     vim.g.fastfold_savehook = 1 -- update on save
    --     vim.g.fastfold_fold_command_suffixes = { "x", "X", "a", "A", "o", "O", "c", "C" }
    --     vim.g.fastfold_fold_movement_commands = { "]z", "[z", "zj", "zk" }
    --
    --     vim.api.nvim_exec(
    --       [[
    --         autocmd BufEnter *.py call SimpylFold#Recache()
    --         "autocmd BufEnter *.py :normal! zx<cr>
    --         "autocmd BufEnter *.py :normal! zz<cr>
    --       ]],
    --       false
    --     )
    --   end,
    -- })
  end,
  config = {
    auto_clean = true,
    max_jobs = 30,
    compile_on_sync = true,
    display = {
      open_fn = require("packer.util").float,
    },
  },
})
