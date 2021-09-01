vim.api.nvim_exec(
  [[
" Setting FileType:

augroup ensureFileType
  " Make sure all markdown files have the correct filetype set
  au BufRead,BufNewFile *.{md,md.erb,markdown,mdown,mkd,mkdn,txt} set filetype=markdown

  au BufNewFile,BufRead .flake8 set filetype=ini

  au BufNewFile,BufRead cronfile set filetype=sh
  au BufNewFile,BufRead *.{sh,txt,env*,flaskenv} set filetype=sh
  au BufNewFile,BufRead *aliases set filetype=zsh

  au BufNewFile,BufRead *.nix set filetype=nix

  au BufNewFile,BufRead .gitconfig set filetype=conf
  au BufNewFile,BufRead *.conf set filetype=config
  au BufNewFile,BufRead *.{kubeconfig,yml,yaml} set filetype=yaml
augroup end


" Generic:
augroup generic
  au Filetype gitcommit setlocal spell textwidth=72
  au FileType git setlocal foldlevel=20  " open all unfolded
  au Filetype vim setlocal tabstop=2 foldmethod=marker
  au FileType *.ya?ml setlocal shiftwidth=2 tabstop=2 softtabstop=2
  au FileType sh,zsh setlocal foldmethod=marker foldlevel=10
  au FileType markdown setlocal wrap wrapmargin=2 textwidth=140 spell
  au FileType lua setlocal foldmethod=expr foldexpr=nvim_treesitter#foldexpr()
augroup end


" EdgeDB
au FileType edgeql setlocal commentstring=#%s


augroup python
  au FileType python setlocal shiftwidth=4 tabstop=4 softtabstop=4 colorcolumn=100
  au FileType python setlocal foldenable foldmethod=expr foldexpr=nvim_treesitter#foldexpr()
  "au FileType python setlocal foldenable foldmethod=expr foldexpr=SimpylFold#FoldExpr(v:lnum)
augroup end


" Frontend:
augroup frontend
  " HTML
  autocmd FileType html setlocal shiftwidth=2 tabstop=2 softtabstop=2 expandtab
  autocmd FileType html setlocal foldmethod=syntax nowrap foldlevel=4

  " JSON
  autocmd FileType json setlocal foldmethod=syntax foldlevel=20

  " JS / TS / Vue
  autocmd FileType vue,typescript setlocal foldmethod=expr foldexpr=nvim_treesitter#foldexpr()
augroup end

]],
  false
)

-- vim.cmd [[
-- " Switch to the current file directory when a new buffer is opened
-- au BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | lcd %:p:h | endif
-- ]]
