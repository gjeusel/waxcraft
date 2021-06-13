" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)
nmap <silent> å <Plug>(coc-diagnostic-prev)
nmap <silent> ß <Plug>(coc-diagnostic-next)
imap <silent> å <esc><Plug>(coc-diagnostic-prev)
imap <silent> ß <esc><Plug>(coc-diagnostic-next)

" Format
nmap <silent> <leader>m <Plug>(coc-format)
nmap <silent> <leader>. <Plug>(coc-codeaction)

" GoTo code navigation.
nmap <silent> <leader>d <Plug>(coc-definition)
nmap <silent> <leader>y <Plug>(coc-type-definition)
nmap <silent> <leader>i <Plug>(coc-implementation)
nmap <silent> <leader>r <Plug>(coc-references)

" Use K to show documentation in preview window.
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocActionAsync('doHover')
  endif
endfunction

" Highlight the symbol and its references when holding the cursor.
" autocmd CursorHold * silent call CocActionAsync('highlight')

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Symbol renaming.
nmap <leader>rn <Plug>(coc-rename)

" " Formatting selected code.
" xmap <leader>f  <Plug>(coc-format-selected)
" nmap <leader>f  <Plug>(coc-format-selected)

" Remap ctrl-c to escape to avoid having Floating Window left
inoremap <C-c> <Esc>

      " \ "coc-fzf-preview"
let g:coc_global_extensions = [
      \ "coc-snippets",
      \ "coc-pyright",
      \ "coc-vimlsp",
      \ "coc-git",
      \ "coc-sh",
      \
      \ "coc-lua",
      \ "coc-json",
      \ "coc-yaml",
      \ "coc-toml",
      \ "coc-sql",
      \
      \ "coc-css",
      \ "coc-tailwindcss",
      \ "coc-html",
      \ "coc-tsserver",
      \ "coc-vetur",
      \ "coc-prettier",
      \ "coc-eslint",
      \ "coc-tslint",
      \ ]

" Snippets:
" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" Command aliases or abbrevations
function! CommandAlias(aliasname, target)
  " :aliasname => :target  (only applicable at the beginning of the command line)
  exec printf('cnoreabbrev <expr> %s ', a:aliasname)
    \ .printf('((getcmdtype() ==# ":" && getcmdline() ==# "%s") ? ', a:aliasname)
    \ .printf('("%s") : ("%s"))', escape(a:target, '"'), escape(a:aliasname, '"'))
endfunction
call CommandAlias('CC', 'CocCommand')

autocmd User CocStatusChange,CocDiagnosticChange call lightline#update()
