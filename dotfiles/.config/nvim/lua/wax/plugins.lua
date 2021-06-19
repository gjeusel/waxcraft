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

    use("zhimsel/vim-stay") -- adds automated view session creation and restoration whenever editing a buffer
    use("jiangmiao/auto-pairs") -- auto pair
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
    use({ "Konfekt/FastFold", branch = "master" }) -- update folds only when needed, otherwise folds slowdown vim

    use("justinmk/vim-sneak") -- minimalist motion with 2 keys
    use("junegunn/vim-easy-align") -- easy alignment, better than tabularize
    use("numtostr/BufOnly.nvim") -- deletes all buffers except
    use("vim-scripts/loremipsum") -- dummy text generator (:Loremipsum [number of words])

    use({
      "tomtom/tcomment_vim", -- for contextual comment
      requires = {
        "JoosepAlviste/nvim-ts-context-commentstring",
        commit = "5024c83e92c3988f6e7119bfa1b2347ae3a42c3e",
      },
      config = function()
        vim.cmd([[
          let g:tcomment_opleader1 = '<leader>c'
          let g:tcomment#filetype#guess_vue = 0  " https://github.com/tomtom/tcomment_vim/issues/284#issuecomment-809956888
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
    use("ap/vim-buftabline") -- buffer line

    use("kyazdani42/nvim-web-devicons") -- icons
    use("mhinz/vim-startify") -- fancy start screen
    use("lewis6991/gitsigns.nvim") -- git sign column

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
        "nvim-treesitter/playground", -- play with queries
        "nvim-treesitter/nvim-treesitter-textobjects", -- better text objects
        -- 'p00f/nvim-ts-rainbow', -- rainbow parenthesis
        { "windwp/nvim-ts-autotag", branch = "main", ft = { "html", "vue" } },
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
        lock = true,
      },
      config = function()
        require("wax.lsp")
      end,
    })
    use({
      "hrsh7th/nvim-compe",
      branch = "master",
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

    use({
      "luochen1990/rainbow", -- embed parenthesis colors
      ft = { "python" },
      config = function()
        vim.cmd([[ RainbowToggleOn ]])
      end,
    })
    use({
      "tmhedberg/SimpylFold", -- better folds
      ft = { "python" },
      config = function() end,
    })
    use({
      "python-mode/python-mode",
      ft = { "python" },
      config = function()
        require("wax.plugins.python-mode")
        package.loaded["wax.themes"] = nil -- remove cached module
        require("wax.themes") -- again for 'syntax on' after new python-mode syntax
      end,
    })
  end,
  config = {
    display = {
      open_fn = require("packer.util").float,
    },
  },
})
