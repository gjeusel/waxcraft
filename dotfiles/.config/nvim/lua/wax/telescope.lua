local lspconfig = require("lspconfig")
local utils = require("telescope.utils")
local builtin = require('telescope.builtin')
local actions = require('telescope.actions')
local transform_mod = require('telescope.actions.mt').transform_mod


local find_root_dir = lspconfig.util.root_pattern(
  ".git",
  "Dockerfile",
  "package.json",
  "tsconfig.json"
)

local grep_cmds = {
  rg = {
    'rg',
    '--color=never',
    '--no-heading',
    '--with-filename',
    '--line-number',
    '--column',
    '--smart-case'
  },
  ag = {
    'ag',
    '--nocolor',
    '--filename',
    '--noheading',
    '--line-number',
    '--column',
    '--smart-case',
    '--hidden',  -- search hidden files
    '--follow',  -- follow symlinks
  },
  git = {
    "git", "grep",
    "--ignore-case",
    "--untracked",
    "--exclude-standard",
    "--line-number",
    "--column",
    "-I",  -- don't match pattern in binary files
    -- "--threads", "10",
    "--full-name",
  }
}

-- Waiting for: https://github.com/nvim-telescope/telescope.nvim/issues/684
-- for this to work
local custom_actions = transform_mod(
  {
    reset_folds = function(_)
      vim.cmd(':normal! zx')
      vim.cmd(':normal! zR')
      -- vim.cmd(':loadview')
    end,
  }
)

-- Custome layout strategy ( like center but follow layout defaults )
---    +--------------+
---    |    Preview   |
---    |    Preview   |
---    |    Preview   |
---    |    Preview   |
---    |    Preview   |
---    +--------------+
---    |    Prompt    |
---    +--------------+
---    |    Result    |
---    |    Result    |
---    +--------------+
require("telescope.pickers.layout_strategies").wax = function(self, max_columns, max_lines)
  local resolve = require("telescope.config.resolve")
  local p_window = require('telescope.pickers.window')

  local layout_config = self.layout_config or {}

  local initial_options = p_window.get_initial_window_options(self)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_padding = resolve.resolve_width(
    layout_config.width_padding or math.ceil((1 - self.window.width) * 0.5 * max_columns)
  )(self, max_columns, max_lines)

  local width = max_columns - width_padding * 2
  if not self.previewer then
    preview.width = 0
  else
    preview.width = width
  end
  results.width = width
  prompt.width = width

  -- Height
  local height_padding = math.max(
    1,
    resolve.resolve_height(layout_config.height_padding or 3)(self, max_columns, max_lines)
  )
  local picker_height = max_lines - 2 * height_padding

  local preview_total = 0
  preview.height = 0
  if self.previewer then
    preview.height = resolve.resolve_height(
      layout_config.preview_height or (max_lines - 15)
    )(self, max_columns, picker_height)

    preview_total = preview.height + 2
  end

  prompt.height = 1
  results.height = picker_height - preview_total - prompt.height - 2

  results.col, preview.col, prompt.col = width_padding, width_padding, width_padding

  if self.previewer then
    preview.line = height_padding
    prompt.line = preview.line + preview.height + 2
    results.line = prompt.line + prompt.height + 2

---    +-----------------+
---    |    Previewer    |
---    |    Previewer    |
---    |    Previewer    |
---    +-----------------+
---    |     Result      |
---    |     Result      |
---    |     Result      |
---    +-----------------+
---    |     Prompt      |
---    +-----------------+
    -- preview.line = height_padding
    -- results.line = preview.line + preview.height + 2
    -- prompt.line = results.line + results.height + 2
  else
    results.line = height_padding
    prompt.line = results.line + results.height + 2
  end

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end

require('telescope').setup{
  defaults = {
    prompt_prefix = '❯ ',
    selection_caret = '❯ ',
    vimgrep_arguments = grep_cmds["rg"],  -- Using ripgrep
    color_devicons = true,
    layout_strategy = "vertical",
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

        -- ["<C-t>"] = actions.select_default + actions.nvim_reset_folds,
        ["<CR>"] = actions.select_default + actions.center + custom_actions.reset_folds,
        -- ["<CR>"] = actions.center_custom,
        -- ["<CR>"] = actions.select_default + actions.select_horizontal,
        -- ["<CR>"] = actions.select_default + actions.center,
        -- ["<CR>"] = actions.select_default + nvim_reset_folds.x,
        -- ["<CR>"] = actions.select_default + actions.center + actions.nvim_reset_folds,
      },
    },
    file_ignore_patterns = {
      "node_modules/.*",
      "dist/.*",
      "__pycache__/.*",
      "package-lock.json",
      "%.ipynb",
    },
  },
  extensions = {
    fzf = {
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
    },
  }
}

-- Extensions
require('telescope').load_extension('fzf')


local M = {}


M.git_grep_string = function()
  local git_root, ret = utils.get_os_command_output({ "git", "rev-parse", "--show-toplevel" })
  local opts = {
    prompt_title = "~ git grep string ~",
    search = '' ,  -- https://github.com/nvim-telescope/telescope.nvim/issues/564
    cwd = git_root[1],
    vimgrep_arguments = grep_cmds["git"],
  }

  -- local theme_opts = require('telescope.themes').get_dropdown({})
  -- local theme_opts = require('telescope.themes').get_ivy({})
  -- for k,v in pairs(theme_opts) do opts[k] = v end
  return builtin.grep_string(opts)
end


M.rg_grep_string = function()
  local root_dir = find_root_dir(".")

  local opts = {
    prompt_title = "~ rg grep string ~",
    search = '' ,  -- https://github.com/nvim-telescope/telescope.nvim/issues/564
    cwd = root_dir,
    vimgrep_arguments = grep_cmds["rg"],
  }
  return builtin.grep_string(opts)
end


M.wax_file = function()
  -- local wax_dir, ret = utils.get_os_command_output({"echo", "$waxCraft_PATH"})
  local opts = {
    prompt_title = "~ dotfiles waxdir ~",
    -- cwd = wax_dir,
    cwd = "~/src/waxcraft",
    hidden=true,
  }
  return builtin.git_files(opts)
end

-- Add all M commands to builtin for the builtin.builtin leader b search
for key, value in pairs(M) do
  builtin[key] = value
end

-- Fallback to builtin
return setmetatable({}, {
  __index = function(_, k)
    if M[k] then
      return M[k]
    else
      return require('telescope.builtin')[k]
    end
  end
})
