nnoremap <leader>P <cmd>lua require('telescope.builtin').find_files(require('telescope.themes').get_dropdown({}))<cr>
nnoremap <leader>p <cmd>lua require('telescope.builtin').git_files(require('telescope.themes').get_dropdown({}))<cr>

nnoremap <leader>a <cmd>lua require('telescope.builtin').live_git_grep(require('telescope.themes').get_dropdown({}))<cr>
nnoremap <leader>A <cmd>lua require('telescope.builtin').live_grep(require('telescope.themes').get_dropdown({}))<cr>

nnoremap <leader>b <cmd>lua require('telescope.builtin').builtin(require('telescope.themes').get_dropdown({}))<cr>

nnoremap <leader>h <cmd>lua require('telescope.builtin').command_history(require('telescope.themes').get_dropdown({}))<cr>
