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
