" Telescope issues waiting for it to be solved:
"
" - handle of treesitter folds and views restore
"   (https://github.com/nvim-telescope/telescope.nvim/pull/541 and https://github.com/nvim-telescope/telescope.nvim/issues/559)
"
" - better integration with fzf. At the moment, it is slow and not a lot customizable (passing custom commands is not implemented, pin to rg)
"   (https://github.com/nvim-telescope/telescope-fzf-writer.nvim)

" nnoremap <leader>P <cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown({}))<cr>
" nnoremap <leader>p <cmd>lua require('telescope.builtin').git_files(require('telescope.themes').get_dropdown({}))<cr>

" nnoremap <leader>a <cmd>lua require('telescope').extensions.fzf_writer.grep(require('telescope.themes').get_dropdown({}))<cr>
" nnoremap <leader>a <cmd>lua require('telescope.builtin').live_git_grep(require('telescope.themes').get_dropdown({}))<cr>
" nnoremap <leader>A <cmd>lua require('telescope.builtin').live_grep(require('telescope.themes').get_dropdown({}))<cr>

nnoremap <leader>b <cmd>lua require('telescope.builtin').builtin(require('telescope.themes').get_dropdown({}))<cr>
nnoremap <leader>h <cmd>lua require('telescope.builtin').command_history(require('telescope.themes').get_dropdown({}))<cr>
