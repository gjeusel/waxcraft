" Telescope issues waiting for it to be solved:
"
" - handle of treesitter folds and views restore
"   (https://github.com/nvim-telescope/telescope.nvim/pull/541 and https://github.com/nvim-telescope/telescope.nvim/issues/559)
"
" - better integration with fzf. At the moment, it is slow and not a lot customizable (passing custom commands is not implemented, pin to rg)
"   (https://github.com/nvim-telescope/telescope-fzf-writer.nvim)

nnoremap <leader>a <cmd>lua require('wax.telescope').git_grep_string()<cr>
nnoremap <leader>A <cmd>lua require('wax.telescope').rg_grep_string()<cr>

nnoremap <leader>p <cmd>lua require('wax.telescope').git_files({prompt_title='~ git files ~'})<cr>
nnoremap <leader>P <cmd>lua require('wax.telescope').find_files({prompt_title='~ files ~'})<cr>

nnoremap <leader>n <cmd>lua require('wax.telescope').buffers({prompt_title='~ buffers ~'})<cr>
" Telescope Builtin:
nnoremap <leader>b <cmd>lua require('wax.telescope').builtin(require('telescope.themes').get_dropdown({}))<cr>

" Spell Fix:
nnoremap z= <cmd>lua require('wax.telescope').spell_suggest(require('telescope.themes').get_dropdown({}))<cr>

" Command History: option-d
map <nowait>∂ <cmd>lua require('wax.telescope').command_history(require('telescope.themes').get_dropdown({}))<cr>
