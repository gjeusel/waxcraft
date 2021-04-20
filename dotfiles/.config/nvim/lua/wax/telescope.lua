local actions = require('telescope.actions')

local transform_mod = require('telescope.actions.mt').transform_mod

-- -- https://github.com/nvim-telescope/telescope.nvim/pull/541
actions.nvim_file_edit = transform_mod(
  {
    nvim_file_edit = function()
      vim.cmd(':normal! zx')
    end
  }
)

require('telescope').setup{
  defaults = {
    generic_sorter =  require('telescope.sorters').get_generic_fuzzy_sorter,
    file_sorter = require('telescope.sorters').get_fzy_sorter,
    vimgrep_arguments = {
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
    color_devicons = true,
    mapping = {
      i = {
        ["<C-q>"] = actions.send_to_qflist,
        -- ["<CR>"] = actions.select_default + actions.nvim_file_edit + actions.center,
        ["<CR>"] = actions.select_default,
      },
    },
    file_ignore_patterns = {"node_modules/.*", "dist/.*", "__pycache__/.*"},
  },
  extensions = {
    fzf = {
      override_generic_sorter = true,  -- override the generic sorter
      override_file_sorter = true,     -- override the file sorter
      case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
    },
  }
}


local builtin = require('telescope.builtin')

live_git_grep = function(opts)
  local vimgrep_arguments = {
    "git", "grep",
    "--ignore-case",
    "--untracked",
    "--exclude-standard",
    "--line-number",
    "--column",
    "-I",  -- don't match pattern in binary files
    "--threads", "10",
  }
  opts.vimgrep_arguments = vimgrep_arguments
  return builtin.live_grep(opts)
end

builtin.live_git_grep = live_git_grep

-- Extensions
require('telescope').load_extension('fzf')
