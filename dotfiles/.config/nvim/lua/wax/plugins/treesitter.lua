local ts = require("nvim-treesitter.configs")

-- NOTE: M1 apple: https://github.com/nvim-treesitter/nvim-treesitter/issues/791

ts.setup({
  highlight = {
    enable = true,
    disable = { "vim" },
    -- custom_captures = {}
    additional_vim_regex_highlighting = false, -- for spell check
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
    disable = {
      "lua",
      "vim",
      "python",
      "yaml",
      -- frontend
      "json",
      "vue",
      "typescript",
    },
  },
  ensure_installed = { -- one of 'all', 'language' or a list of languages
    -- Generic:
    "bash",
    "json",
    "yaml",
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
    "vue",
    -- Backend:
    "go",
    "rust",
    "python",
    -- Infra:
    "hcl", -- terraform
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

  -- 'JoosepAlviste/nvim-ts-context-commentstring'
  context_commentstring = {
    enable = true,
  },

  -- 'p00f/nvim-ts-rainbow'
  rainbow = {
    enable = false,
    extended_mode = false, -- Also highlight non-bracket delimiters like html tags, boolean or table: lang -> boolean
    max_file_lines = 3000, -- Do not enable for files with more than n lines, int
    -- colors = { "#bf616a", "#d08770", "#ebcb8b", "#a3be8c", "#88c0d0", "#5e81ac", "#b48ead" },
    colors = { "#8FBCBB", "#88C0D0", "#81A1C1" },
    termcolors = { 109, 108, "white" },
    -- termcolors = { "red", "green", "yellow", "blue" }, -- table of colour name strings
  },

  -- 'windwp/nvim-autopairs'
  autopairs = { enable = true },

  -- 'andymass/vim-matchup'
  matchup = {
    enable = true,
    disable_virtual_text = true,
  },

  -- 'windwp/nvim-ts-autotag'
  autotag = {
    enable = true,
  },
})

-- Set my own queries:
local Path = require("plenary.path")
local scan = require("plenary.scandir")

local wax_ts_queries = Path:new(vim.env.waxCraft_PATH):joinpath("dotfiles/treeshitter/queries")

local function load_wax_ts_queries()
  if not wax_ts_queries:exists() then
    return
  end

  local qry_dirs = scan.scan_dir(wax_ts_queries:absolute(), { depth = 1, only_dirs = true })

  for _, qry_dir in pairs(qry_dirs) do
    qry_dir = Path:new(qry_dir)

    local language = vim.fn.fnamemodify(qry_dir.filename, ":t")

    local qry_paths = scan.scan_dir(qry_dir:absolute(), { depth = 1 })
    for _, qry_path in pairs(qry_paths) do
      qry_path = Path:new(qry_path)
      local qry_type = vim.fn.fnamemodify(qry_path.filename, ":t:r")

      log.debug("Overwritting TreeSitter", qry_type, "queries for", language)

      pcall(vim.treesitter.query.set_query, language, qry_type, qry_path:read())
    end
  end
end

load_wax_ts_queries()
