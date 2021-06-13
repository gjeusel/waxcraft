" Telescope issues waiting for it to be solved:
"
" - handle of treesitter folds and views restore
"   (https://github.com/nvim-telescope/telescope.nvim/pull/541 and https://github.com/nvim-telescope/telescope.nvim/issues/559)
"
" - better integration with fzf. At the moment, it is slow and not a lot customizable (passing custom commands is not implemented, pin to rg)
"   (https://github.com/nvim-telescope/telescope-fzf-writer.nvim)

" Too slow for fuzzy search inside file:
" nnoremap <leader>a <cmd>lua require('wax.telescope').fallback_grep_string()<cr>
" nnoremap <leader>A <cmd>lua require('wax.telescope').rg_grep_string()<cr>


" Telescope file
nnoremap <leader>p <cmd>lua require('wax.telescope').fallback_grep_file()<cr>
nnoremap <leader>P <cmd>lua require('wax.telescope').find_files({prompt_title='~ files ~', hidden=true})<cr>

" Telescope project then file on ~/src
nnoremap <leader>q <cmd>lua require('wax.telescope').projects_files()<cr>

" Telescope opened buffers
nnoremap <leader>n <cmd>lua require('wax.telescope').buffers({prompt_title='~ buffers ~'})<cr>

" Telescope Builtin:
nnoremap <leader>b <cmd>lua require('wax.telescope').builtin(require('telescope.themes').get_dropdown({}))<cr>

" Spell Fix:
nnoremap z= <cmd>lua require('wax.telescope').spell_suggest(require('telescope.themes').get_dropdown({}))<cr>

" Command History: option-d
map <nowait>∂ <cmd>lua require('wax.telescope').command_history(require('telescope.themes').get_dropdown({}))<cr>

" Telescope - COC
nnoremap <leader>f :Telescope coc workspace_symbols<cr>
nnoremap <leader>F :Telescope coc document_symbols<cr>
