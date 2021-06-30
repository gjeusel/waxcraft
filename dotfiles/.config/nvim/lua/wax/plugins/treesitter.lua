local ts = require("nvim-treesitter.configs")
local parsers = require("nvim-treesitter.parsers")

-- NOTE: M1 apple: https://github.com/nvim-treesitter/nvim-treesitter/issues/791

ts.setup({
  highlight = {
    enable = true,
    -- disable = { "python" },
    -- custom_captures = {}
    additional_vim_regex_highlighting = false, -- also activate vim syntax
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
    disable = { "yaml", "python"},
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
    "python",
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
        ["]]"] = "@function.outer",
        ["]c"] = "@class.outer",
      },
      goto_next_end = {
        ["]["] = "@function.outer",
        ["]C"] = "@class.outer",
      },
      goto_previous_start = {
        ["[["] = "@function.outer",
        ["[c"] = "@class.outer",
      },
      goto_previous_end = {
        ["[]"] = "@function.outer",
        ["[C"] = "@class.outer",
      },
    },
    lsp_interop = {
      enable = true,
      peek_definition_code = {
        ["df"] = "@function.outer",
        ["dF"] = "@class.outer",
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
