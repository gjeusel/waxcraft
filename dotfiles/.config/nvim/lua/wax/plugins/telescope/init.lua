local actions = require("telescope.actions")
local constants = require("wax.plugins.telescope.constants")

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
        ["<C-f>"] = actions.smart_send_to_qflist, -- + actions.open_qflist, -- + my_cool_custom_action.x,
      },
      n = {
        ["<C-f>"] = actions.smart_send_to_qflist, -- + actions.open_qflist, -- + my_cool_custom_action.x,
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
    ["ui-select"] = {
      require("telescope.themes").get_dropdown({}),
    },
  },
})

-- Extensions
for _, ext in pairs({ "fzf", "ui-select" }) do
  pcall(require("telescope").load_extension, ext)
end

-- Mappings
local function telescope_keymaps()
  local themes = require("telescope.themes")
  local functions = require("wax.plugins.telescope.functions")
  local opts = { noremap = true, silent = true, nowait = true }

  -- Telescope live grep
  vim.keymap.set("n", "<leader>A", functions.entirely_fuzzy_grep_string, opts)

  -- Telescope file
  vim.keymap.set("n", "<leader>p", functions.wax_find_file, opts)
  vim.keymap.set("n", "<leader>P", function()
    functions.wax_find_file({ git_files = false })
  end, opts)

  -- Telescope project then file on ~/src
  vim.keymap.set("n", "<leader>q", functions.projects_grep_files, opts)
  vim.keymap.set("n", "<leader>Q", functions.projects_grep_string, opts)

  -- Telescope opened buffers
  vim.keymap.set("n", "<leader>n", function()
    functions.buffers({ prompt_title = "~ buffers ~" })
  end, opts)

  -- Telescope Builtin:
  vim.keymap.set("n", "<leader>b", functions.builtin, opts)

  -- Spell Fix:
  vim.keymap.set("n", "z=", function()
    functions.spell_suggest(themes.get_cursor({}))
  end)

  -- Command History: option-d
  vim.keymap.set({ "n", "i", "c" }, "∂", function()
    functions.command_history(themes.get_dropdown({}))
  end, opts)

  -- LSP
  local vertical_opts = {
    sorting_strategy = "ascending",
    layout_strategy = "vertical",
    fname_width = 90,
    -- include_current_line=false,
    -- time_text = true,
  }
  vim.keymap.set("n", "<leader>ff", functions.lsp_dynamic_workspace_symbols, opts)
  vim.keymap.set("n", "<leader>fF", functions.lsp_document_symbols, opts)
  vim.keymap.set("n", "<leader>r", function()
    functions.lsp_references(vertical_opts)
  end, opts)

  -- dotfiles
  vim.keymap.set("n", "<leader>fn", functions.wax_file, opts)
end

telescope_keymaps()

local telescope_functions = require("wax.plugins.telescope.functions")
return telescope_functions
