local actions = require('telescope.actions')


-- https://github.com/nvim-telescope/telescope.nvim/pull/541
function nvim_file_edit(_)
  vim.cmd(':e')
end


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
        ["<CR>"] = actions.select_default + actions.center,
      },
    }
  }
}

require('telescope').load_extension('fzy_native')
