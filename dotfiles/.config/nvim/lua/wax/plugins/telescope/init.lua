local transform_mod = require("telescope.actions.mt").transform_mod
local actions = require("telescope.actions")

local constants = require("wax.plugins.telescope.constants")

-- Waiting for: https://github.com/nvim-telescope/telescope.nvim/issues/684
-- for this to work
local custom_actions = transform_mod({
  restore_folds = function(_)
    vim.wo.foldmethod = vim.wo.foldmethod or "expr"
    vim.wo.foldexpr = vim.wo.foldexpr or "nvim_treesitter#foldexpr()"
    vim.cmd(":normal! zx")
    -- vim.cmd(":normal! zz")
  end,
  restore_view = function(_)
    pcall(vim.cmd, ":loadview") -- suppress error in case of no view stored
  end,
})

require("telescope").setup({
  defaults = {
    prompt_prefix = "❯ ",
    selection_caret = "❯ ",
    vimgrep_arguments = constants.grep_cmds["rg"], -- Using ripgrep
    color_devicons = false,
    -- layout_strategy = "flexwax",
    sorting_strategy = "descending",
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        width_padding = 0.1,
        height_padding = 0.1,
        preview_width = 0.5,
      },
      vertical = {
        width_padding = 0.1,
        height_padding = 2,
        preview_height = 0.5,
        mirror = true,
      },
    },
    mappings = {
      i = {
        ["<C-f>"] = actions.smart_send_to_qflist, -- + actions.open_qflist, -- + my_cool_custom_action.x,
        ["<CR>"] = actions.select_default + actions.center,
        -- ["<CR>"] = actions.select_default + actions.center + custom_actions.restore_view,
      },
      n = {
        ["<C-f>"] = actions.smart_send_to_qflist, -- + actions.open_qflist, -- + my_cool_custom_action.x,
        ["<CR>"] = actions.select_default + actions.center,
        -- ["<CR>"] = actions.select_default + actions.center + custom_actions.restore_view,
      },
    },
    file_ignore_patterns = {
      -- Should be LUA pattern matching:
      -- https://riptutorial.com/lua/example/20315/lua-pattern-matching
      -- '%' is the escape char in lua
      -- global
      ".git/",
      -- python
      "%.egg%-info/",
      "__pycache__/",
      "%.ipynb",
      "%.mypy_cache/",
      "%.pytest_cache/",
      -- frontend
      "node_modules/",
      "dist/",
      "static/appbuilder/",
      "%.min%.js",
    },
  },
  extensions = {
    fzf = {
      override_generic_sorter = true, -- override the generic sorter
      override_file_sorter = true, -- override the file sorter
      case_mode = "smart_case", -- or "ignore_case" or "respect_case"
    },
  },
})

-- Extensions
require("telescope").load_extension("fzf")

local basemap = "<cmd>lua require('wax.plugins.telescope')"

-- Telescope live grep
-- nnoremap("<leader>A", basemap .. ".entirely_fuzzy_grep_string()<cr>")
nnoremap("<leader>A", basemap .. ".entirely_fuzzy_grep_string()<cr>")

-- Telescope file
nnoremap("<leader>p", basemap .. ".wax_find_file()<cr>")
nnoremap("<leader>P", basemap .. ".wax_find_file({git_files=false})<cr>")

-- Telescope project then file on ~/src
nnoremap("<leader>q", basemap .. ".projects_grep_files()<cr>")
nnoremap("<leader>Q", basemap .. ".projects_grep_string()<cr>")

-- Telescope opened buffers
nnoremap("<leader>n", basemap .. ".buffers({prompt_title='~ buffers ~'})<cr>")

-- Telescope Builtin:
nnoremap("<leader>b", basemap .. ".builtin(require('telescope.themes').get_dropdown({}))<cr>")

-- Spell Fix:
nnoremap("z=", basemap .. ".spell_suggest(require('telescope.themes').get_cursor({}))<cr>")

-- Command History: option-d
keymap(
  "nic",
  "∂",
  basemap .. ".command_history(require('telescope.themes').get_dropdown({}))<cr>",
  { nowait = true }
)

-- LSP
nnoremap("<leader>ff", basemap .. ".lsp_dynamic_workspace_symbols()<cr>")
nnoremap("<leader>fF", basemap .. ".lsp_document_symbols()<cr>")
nnoremap("<leader>r", basemap .. ".lsp_references()<cr>")

-- dotfiles
nnoremap("<leader>fn", basemap .. ".wax_file()<cr>")

-- vim help
nnoremap("<leader>fh", basemap .. ".wax_file()<cr>")

local telescope_functions = require("wax.plugins.telescope.functions")
return telescope_functions
