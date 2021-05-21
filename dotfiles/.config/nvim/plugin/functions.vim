" Redirect output of vim commands like :syntax in other buffer
" See https://dev.to/dkendal/capture-the-output-of-a-vim-command-5809
function! s:split(expr) abort
  let lines = split(execute(a:expr, 'silent'), "[\n\r]")
  let name = printf('capture://%s', a:expr)

  if bufexists(name) == v:true
    execute 'bwipeout' bufnr(name)
  end

  execute 'botright' 'new' name

  setlocal buftype=nofile
  setlocal bufhidden=hide
  setlocal noswapfile
  setlocal filetype=vim

  call append(line('$'), lines)
endfunction

function s:capture(expr, bang) abort
  call s:split(a:expr)
endfunction

command! -nargs=1 -bang P call s:capture(<q-args>, <bang>0)

" Always happen to me:
command Cq :cq


" Profiling functions
function! StartProfiling()
  execute ":profile start /tmp/neovim.profile"
  execute ":profile func *"
  execute ":profile file *"
  let g:profiling=1
endfunction

function! EndProfiling()
  execute ":profile pause"
  let g:profiling=0
endfunction

let g:profiling=0
function! ToggleProfiling()
  if g:profiling == 0
    call StartProfiling()
  else
    call EndProfiling()
  endif
endfunction
