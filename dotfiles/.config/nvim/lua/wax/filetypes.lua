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
  au BufNewFile,BufRead *.{kubeconfig,yml,yaml} set filetype=yaml syntax=on
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
augroup edgeql
  au BufNewFile,BufRead *.edgeql setf edgeql
  au BufNewFile,BufRead *.esdl setf edgeql
  au FileType edgeql setlocal commentstring=#%s
augroup end


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

-- Performances
-- https://www.reddit.com/r/neovim/comments/pz3wyc/comment/heyy4qf/?utm_source=share&utm_medium=web2x&context=3
vim.api.nvim_exec(
  [[
" disable syntax highlighting in big files
function DisableSyntaxTreesitter()
  echo("Big file, disabling syntax, treesitter and folding")
  if exists(':TSBufDisable')
      exec 'TSBufDisable autotag'
      exec 'TSBufDisable highlight'
      exec 'TSBufDisable indent'
      exec 'TSBufDisable incremental_selection'
      exec 'TSBufDisable context_commentstring'
      exec 'TSBufDisable autopairs'
  endif

  setlocal eventignore+=FileType  " disable all filetype autocommands

  setlocal foldmethod=manual
  setlocal foldexpr=
  setlocal nowrap
  "syntax clear
  "syntax off    " hmmm, which one to use?
  "filetype off

  setlocal noundofile
  setlocal noswapfile
  setlocal noloadplugins
endfunction

function EnableFastFeatures()
  " activate some fast tooling
  LspStart
  exec 'setlocal syntax=' . &ft
endfunction

let g:large_file = 258 * 512

augroup BigFileDisable
  autocmd!
  autocmd BufReadPre,FileReadPre * if getfsize(expand("%")) > g:large_file | exec DisableSyntaxTreesitter() | endif
  autocmd BufEnter * if getfsize(expand("%")) > g:large_file | exec EnableFastFeatures() | endif
augroup END

]],
  false
)
