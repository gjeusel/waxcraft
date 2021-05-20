local lspconfig = require("lspconfig")
local utils = require("wax.utils")
local builtin = require('telescope.builtin')
local actions = require('telescope.actions')
local transform_mod = require('telescope.actions.mt').transform_mod

local layout_strategies = require("telescope.pickers.layout_strategies")


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
layout_strategies.centerwax = function(self, max_columns, max_lines)
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


layout_strategies.verticalwax = function(self, max_columns, max_lines)
  local layout_config = self.layout_config or {}
  local resolve = require("telescope.config.resolve")
  local p_window = require('telescope.pickers.window')

  local initial_options = p_window.get_initial_window_options(self)
  local preview = initial_options.preview
  local results = initial_options.results
  local prompt = initial_options.prompt

  local width_padding = resolve.resolve_width(
    layout_config.width_padding or math.ceil((1 - self.window.width) * 0.5 * max_columns)
  )(self, max_columns, max_lines)

  local width = max_columns - width_padding * 2
  preview.width = width
  results.width = width
  prompt.width = width

  -- Height
  local height_padding = resolve.resolve_height(layout_config.height_padding or 3)(self, max_columns, max_lines)
  height_padding = math.max(0, height_padding)
  local picker_height = max_lines - 2 * height_padding

  local preview_total = 0
  preview.height = 0
  preview.height = resolve.resolve_height(
    layout_config.preview_height or (max_lines - 15)
  )(self, max_columns, picker_height)

  preview_total = preview.height + 2

  if height_padding == 0 then
    self.preview = false
    preview.height = 0
    preview.width = 0
    preview_total = 0
  end

  prompt.height = 1
  results.height = picker_height - preview_total - prompt.height - 2

  results.col, preview.col, prompt.col = width_padding, width_padding, width_padding

  local step = 1
  if self.previewer then
    if not layout_config.mirror then
      preview.line = height_padding
      results.line = preview.line + preview.height + step
      prompt.line = results.line + results.height + step
    else
      prompt.line = height_padding
      results.line = prompt.line + prompt.height + step
      preview.line = results.line + results.height + step
    end
  else
    results.line = height_padding
    prompt.line = results.line + results.height + step
  end

  return {
    preview = self.previewer and preview.width > 0 and preview,
    results = results,
    prompt = prompt
  }
end


layout_strategies.flexwax = function(self, max_columns, max_lines)
  local layout_config = self.layout_config or {}

  local flip_columns = layout_config.flip_columns or 150

  if max_columns < flip_columns then
    self.layout_config = (require("telescope.config").values.layout_defaults or {})['vertical']
    return layout_strategies.verticalwax(self, max_columns, max_lines)
  else
    self.layout_config = (require("telescope.config").values.layout_defaults or {})['horizontal']
    return layout_strategies.horizontal(self, max_columns, max_lines)
  end
end


require('telescope').setup{
  defaults = {
    prompt_prefix = '❯ ',
    selection_caret = '❯ ',
    vimgrep_arguments = grep_cmds["rg"],  -- Using ripgrep
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

-- Custom Grep to be fuzzy
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
M.fallback_grep_string = function()
  if utils.is_git() then
    return M.git_grep_string()
  else
    return M.rg_grep_string()
  end
end


-- Custom find file (defaulting to git files if is git)
M.fallback_grep_file = function(opts)
  opts = opts or {}
  if utils.is_git() then
    local default_opts = {prompt_title='~ git files ~', hidden=true}
    for k,v in pairs(default_opts) do opts[k] = v end
    return builtin.git_files(opts)
  else
    local default_opts = {prompt_title='~ files ~', hidden=true}
    for k,v in pairs(default_opts) do opts[k] = v end
    return builtin.find_files(opts)
  end
end


-- Dotfiles find file
M.wax_file = function()
  local opts = {
    prompt_title = "~ dotfiles waxdir ~",
    cwd = "~/src/waxcraft",
    -- cwd=nil,
    hidden=true,
    -- find_command="find",
    -- search_dirs={"~/src/waxcraft", "~/.config/nvim"}
  }
  return builtin.git_files(opts)
end


-- Projects find file
M.projects_files = function()
  local scan = require('plenary.scandir')
  local Path = require('plenary.path')
  local os_sep = Path.path.sep

  local action_set = require('telescope.actions.set')
  local action_state = require('telescope.actions.state')
  local conf = require('telescope.config').values
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local make_entry = require('telescope.make_entry')
  local tele_path = require'telescope.path'

  local opts = {
    prompt_title = "~ projects files ~",
    cwd = "~/src",
  }

  opts.depth = opts.depth or 1
  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.new_finder = opts.new_finder or function(path)
    opts.cwd = path
    local data = {}

    scan.scan_dir(path, {
      hidden = opts.hidden or false,
      add_dirs = true,
      depth = opts.depth,
      on_insert = function(entry, typ)
        table.insert(data, typ == 'directory' and (entry .. os_sep) or entry)
      end
    })

    return finders.new_table {
      results = data,
      entry_maker = (function()
        local gen = make_entry.gen_from_file(opts)
        return function(entry)
          local tmp = gen(entry)
          tmp.ordinal = tele_path.make_relative(entry, opts.cwd)
          return tmp
        end
      end)()
    }
  end

  pickers.new(opts, {
    prompt_title = 'File Browser',
    finder = opts.new_finder(opts.cwd),
    previewer = conf.file_previewer(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      action_set.select:replace(function(_, cmd)
        local selection = action_state.get_selected_entry()
        local project = selection[0]
        actions.close(prompt_bufnr)
        builtin.fallback_grep_file({cwd = project})
        vim.cmd(":normal! A")  -- small fix to be in insert mode
      end)

      return true
    end
    -- attach_mappings = function(prompt)
    --   action_set.select:replace {
    --     post = function()
    --       print(vim.inspect(action_state.get_selected_entry()))
    --     end,
    --     -- post = function()
    --     --   local selection = action_state.get_selected_entry()
    --     --   return builtin.find_files(({prompt_title='~ files ~', hidden=true}))
    --     -- end,
    --   }
    --   return true
    -- end,
  }):find()
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
