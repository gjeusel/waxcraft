vim.api.nvim_exec(
[[
command -bang -nargs=* GGrep call fzf#vim#grep( 'git grep --line-number --ignore-case --untracked --exclude-standard '.shellescape(<q-args>), 0, fzf#vim#with_preview({ 'dir': systemlist('git rev-parse --show-toplevel')[0] }, <bang>0))
]], false)

vim.api.nvim_exec([[
" :Ag  - Start fzf with hidden preview window that can be enabled with "?" key
" :Ag! - Start fzf in fullscreen and display the preview window above
command -bang -nargs=* Ag call fzf#vim#ag(<q-args>, <bang>0 ? fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'up:60%') : fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}, 'right:50%:hidden', '?'), <bang>0)
]], false)

vim.api.nvim_exec([[
function FzfOmniFiles()
    let is_git = system('git status')
    if v:shell_error
        execute 'Files'
    else
        execute 'GFiles'
    endif
endfunction

function AgOmniFiles()
  let is_git = system('git status')
  if v:shell_error
    execute 'Ag'
  else
    execute 'GGrep'
  endif
endfunction
]], false)

vim.api.nvim_exec([[
nmap <leader>a :call AgOmniFiles()<CR>
nmap <leader>A :Ag<CR>
" nmap <leader>p :call FzfOmniFiles()<CR>
" nmap <leader>P :Files<CR>
" nmap <C-p> :call FzfOmniFiles()<CR>
" nmap <leader>b :Buffers<CR>

" fzf
" Hide statusline of terminal buffer
autocmd! FileType fzf
autocmd  FileType fzf set laststatus=0 noshowmode noruler | autocmd BufLeave <buffer> set laststatus=2 noshowmode ruler
]], false)

-- Customize fzf colors to match your color scheme
vim.g.fzf_colors = {
  fg      = {"fg", "Normal"},
  bg      = {"bg", "Normal"},
  hl      = {"fg", "Comment"},
  ["fg+"] = {'fg', 'CursorLine', 'CursorColumn', 'Normal'},
  ["bg+"] = {'bg', 'CursorLine', 'CursorColumn'},
  ["hl+"] = {'fg', 'Statement'},
  info    = {'fg', 'PreProc'},
  border  = {'fg', 'Ignore'},
  prompt  = {'fg', 'Conditional'},
  pointer = {'fg', 'Exception'},
  marker  = {'fg', 'Keyword'},
  spinner = {'fg', 'Label'},
  header  = {'fg', 'Comment'}
}


-- nmap("<leader>a", ":call AgOmniFiles()<CR>")
-- nmap("<leader>A", ":Ag<CR>")
