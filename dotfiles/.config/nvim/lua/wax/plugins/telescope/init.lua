local actions = require("telescope.actions")
local constants = require("wax.plugins.telescope.constants")
local themes = require("telescope.themes")
local functions = require("wax.plugins.telescope.functions")

-- https://github.com/nvim-telescope/telescope.nvim/issues/559
vim.api.nvim_create_autocmd("BufRead", {
  callback = function()
    vim.api.nvim_create_autocmd("BufWinEnter", {
      once = true,
      pattern = { "*.py", "*.ts", "*.vue", ".lua" },
      callback = function()
        vim.defer_fn(function()
          -- local str = vim.api.nvim_replace_termcodes(":silent! loadview<cr>", true, false, true)
          -- vim.api.nvim_feedkeys(str, "m", false)
          -- vim.cmd([[:silent! loadview]])
          vim.cmd([[:normal! zx]])
          vim.cmd([[:normal! zO]])
        end, 0)
      end,
    })
  end,
})

require("telescope").setup({
  defaults = {
    prompt_prefix = "❯ ",
    selection_caret = "❯ ",
    vimgrep_arguments = constants.grep_cmds["rg"],
    color_devicons = false,
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
        -- mirror = true,
      },
    },
    mappings = {
      i = {
        ["<C-r>"] = actions.smart_send_to_qflist,
      },
      n = {
        ["<C-r>"] = actions.smart_send_to_qflist,
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

-- Load Extensions
for _, ext in pairs({ "fzf" }) do
  pcall(require("telescope").load_extension, ext)
end

-- Mappings
local kmap = vim.keymap.set

local kopts = { noremap = true, silent = true, nowait = true }

-- Telescope file
kmap("n", "<leader>p", functions.ffile, kopts)
kmap("n", "<leader>P", function()
  functions.ffile({ git_files = false })
end, kopts)

-- -- Telescope project then file on ~/src
-- kmap("n", "<leader>q", functions.projects_grep_files, kopts)
-- kmap("n", "<leader>Q", functions.projects_grep_string, kopts)

-- Telescope opened buffers
kmap("n", "<leader>n", function()
  functions.buffers({ prompt_title = "~ buffers ~" })
end, kopts)

-- Telescope Builtin:
kmap("n", "<leader>fr", functions.builtin, kopts)

-- Spell Fix:
kmap("n", "z=", function()
  functions.spell_suggest(themes.get_cursor({}))
end)

-- LSP
local vertical_opts = {
  sorting_strategy = "ascending",
  layout_strategy = "vertical",
  fname_width = 90,
  -- include_current_line=false,
  -- time_text = true,
}
kmap("n", "<leader>ff", functions.lsp_dynamic_workspace_symbols, kopts)
kmap("n", "<leader>fF", functions.lsp_document_symbols, kopts)
kmap("n", "<leader>r", function()
  functions.lsp_references(vertical_opts)
end, kopts)

-- dotfiles
kmap("n", "<leader>fw", functions.wax_file, kopts)

return functions
