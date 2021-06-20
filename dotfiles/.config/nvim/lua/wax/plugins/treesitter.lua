local ts = require("nvim-treesitter.configs")
local parsers = require("nvim-treesitter.parsers")

ts.setup({
  highlight = {
    enable = true,
    -- disable = {"vue", "typescript"},
    -- custom_captures = {}
    -- additional_vim_regex_highlighting = false, -- also activate vim syntax
    use_languagetree = true, -- enable language injection
  },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = "gnn",
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    },
  },
  indent = {
    enable = true,
    disable = { "yaml" },
  },
  ensure_installed = { -- one of 'all', 'language' or a list of languages
    -- Generic:
    "bash",
    "json",
    "lua",
    "ql",
    "query",
    "regex",
    "toml",
    "yaml",
    -- Frontend:
    "graphql",
    "html",
    "css",
    "jsdoc",
    "javascript",
    "typescript",
    "vue",
    -- Backend:
    "go",
    "rust",
    -- 'python',  commented as too many habits on current settings
  },

  -- Plugins config:

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
      keymaps = {
        ["if"] = "@function.inner",
        ["af"] = "@function.outer",

        ["ic"] = "@conditional.inner",
        ["ac"] = "@conditional.outer",

        ["ie"] = "@block.inner",
        ["ae"] = "@block.outer",
      },
    },
    move = {
      enable = true,
      goto_next_start = {
        ["]m"] = "@function.outer",
        ["]]"] = "@class.outer",
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        ["]["] = "@class.outer",
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        ["[["] = "@class.outer",
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        ["[]"] = "@class.outer",
      },
    },
  },

  -- 'JoosepAlviste/nvim-ts-context-commentstring'
  context_commentstring = {
    enable = true,
  },

  -- -- 'p00f/nvim-ts-rainbow'
  -- rainbow = {
  --   enable = true,
  --   extended_mode = true, -- Highlight also non-parentheses delimiters, boolean or table: lang -> boolean
  -- },

  -- 'windwp/nvim-ts-autotag'
  autotag = {
    enable = true,
  },
})