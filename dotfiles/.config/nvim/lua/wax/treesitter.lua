local ts = require'nvim-treesitter.configs'
local parsers = require'nvim-treesitter.parsers'

ts.setup {
  highlight = {
    enable = true,
    -- disable = {"vue", "typescript"},
    -- custom_captures = {}
    additional_vim_regex_highlighting = false,
  },
  -- rainbow = {
  --   enable = true,
  --   extended_mode = true, -- Highlight also non-parentheses delimiters, boolean or table: lang -> boolean
  -- },
  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = 'gnn',
      node_incremental = "grn",
      scope_incremental = "grc",
      node_decremental = "grm",
    }
  },
  indent = {
    enable = true,  -- is shit
  },
  -- refactor = {
  --   highlight_definitions = { enable = true },
  --   highlight_current_scope = { enable = false },
  --   smart_rename = {
  --     enable = true,
  --     keymaps = {
  --       smart_rename = "grr",
  --     }
  --   },
  --   navigation = {
  --     enable = true,
  --     keymaps = {
  --       goto_definition = "gd",
  --       list_definitions = "gD",
  --       list_definitions_toc = "gO",
  --       -- goto_next_usage = "<a-*>",
  --       -- goto_previous_usage = "<a-#>",
  --     }
  --   }
  -- },
  -- textobjects = {
  --   select = {
  --     enable = true,
  --     keymaps = {
  --       ["ie"] = "@block.inner",
  --       ["ae"] = "@block.outer",
  --       ["im"] = "@call.inner",
  --       ["am"] = "@call.outer",
  --       ["iC"] = "@class.inner",
  --       ["aC"] = "@class.outer",
  --       ["ad"] = "@comment.outer",
  --       ["ic"] = "@conditional.inner",
  --       ["ac"] = "@conditional.outer",
  --       ["if"] = "@function.inner",
  --       ["af"] = "@function.outer",
  --       ["il"] = "@loop.inner",
  --       ["al"] = "@loop.outer",
  --       ["is"] = "@parameter.inner",
  --       ["as"] = "@statement.outer",
  --     }
  --   },
  --   -- swap = {
  --   --   enable = true,
  --   --   swap_next = {
  --   --     ["<leader>a"] = "@parameter.inner",
  --   --   },
  --   --   swap_previous = {
  --   --     ["<leader>A"] = "@parameter.inner",
  --   --   },
  --   -- },
  --   -- move = {
  --   --   enable = true,
  --   --   goto_next_start = {
  --   --     ["]m"] = "@function.outer",
  --   --     ["]]"] = "@class.outer",
  --   --   },
  --   --   goto_next_end = {
  --   --     ["]M"] = "@function.outer",
  --   --     ["]["] = "@class.outer",
  --   --   },
  --   --   goto_previous_start = {
  --   --     ["[m"] = "@function.outer",
  --   --     ["[["] = "@class.outer",
  --   --   },
  --   --   goto_previous_end = {
  --   --     ["[M"] = "@function.outer",
  --   --     ["[]"] = "@class.outer",
  --   --   },
  --   -- },
  -- },
  playground = {
    enable = true,
    updatetime = 25,
    persist_queries = false
  },
  query_linter = {
    enable = true,
    use_virtual_text = true,
    lint_events = { "BufWrite", "CursorHold" },
  },
  ensure_installed = { -- one of 'all', 'language' or a list of languages
    -- Generic:
    'bash',
    'json',
    'lua',
    'ql',
    'query',
    'regex',
    'toml',
    'yaml',
    -- Frontend:
    'graphql',
    'html',
    'css',
    -- 'ecma',
    'jsdoc',
    'javascript',
    'typescript',
    'vue',
    -- Backend:
    'go',
    'rust',
  },
  context_commentstring = {
    enable = true,
  },
}

-- local configs = parsers.get_parser_configs()
-- local ft_str = table.concat(
--   vim.tbl_map(
--     function(ft) return configs[ft].filetype or ft end,
--     parsers.available_parsers()
--   ),
--   ','
-- )
-- local ft_str = "typescript,vue,lua"
-- vim.cmd('autocmd Filetype ' .. ft_str .. ' setlocal foldmethod=expr foldexpr=nvim_treesitter#foldexpr()')
