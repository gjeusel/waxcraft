local transform_mod = require("telescope.actions.mt").transform_mod
local actions = require("telescope.actions")

local constants = require("wax.plugins.telescope.constants")

-- Waiting for: https://github.com/nvim-telescope/telescope.nvim/issues/684
-- for this to work
local custom_actions = transform_mod({
  restore_folds = function(_)
    vim.wo.foldmethod = vim.wo.foldmethod or "nvim_treesitter#foldexpr()"
    vim.wo.foldmethod = "expr"
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
    color_devicons = true,
    layout_strategy = "flexwax",
    sorting_strategy = "descending",
    layout_defaults = {
      horizontal = {
        width_padding = 0.1,
        height_padding = 0.1,
        preview_width = 0.6,
      },
      vertical = {
        width_padding = 0.1,
        height_padding = 2,
        preview_height = 0.6,
        -- mirror = true,
      },
      wax = {
        width_padding = 0.1,
        height_padding = 2,
        preview_height = 0.6,
      },
    },
    mapping = {
      i = {
        ["<C-a>"] = false,
        ["<C-q>"] = actions.smart_send_to_qflist, -- + actions.open_qflist, -- + my_cool_custom_action.x,

        ["<C-R>"] = actions.select_default + actions.center,
        -- ["<C-R>"] = actions.select_default + actions.center + custom_actions.restore_view,
        -- ["<CR>"] = actions.select_default + actions.center + custom_actions.restore_view,
      },
    },
    file_ignore_patterns = {
      "node_modules/.*",
      "dist/.*",
      "__pycache__/.*",
      "package-lock.json",
      "%.ipynb",
      ".git/.*",
      "static/appbuilder/.*",
      "%.min.js",
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

-- Telescope file
local basemap = "<cmd>lua require('wax.plugins.telescope')"
nnoremap("<leader>p", basemap .. ".fallback_grep_file()<cr>")
nnoremap("<leader>P", basemap .. ".find_files({prompt_title='~ files ~', hidden=true})<cr>")

-- Telescope project then file on ~/src
nnoremap("<leader>q", basemap .. ".projects_grep_files()<cr>")
nnoremap("<leader>Q", basemap .. ".projects_grep_string()<cr>")

-- Telescope opened buffers
nnoremap("<leader>n", basemap .. ".buffers({prompt_title='~ buffers ~'})<cr>")

-- Telescope Builtin:
nnoremap("<leader>b", basemap .. ".builtin(require('telescope.themes').get_dropdown({}))<cr>")

-- Spell Fix:
nnoremap("z=", basemap .. ".spell_suggest(require('telescope.themes').get_dropdown({}))<cr>")

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
