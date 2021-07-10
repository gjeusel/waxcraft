-- vim.o.foldminlines = 2

-- TODO: convert it to lua function ?
vim.cmd([[
function! FoldText() abort
  " clear fold from fillchars to set it up the way we want later
  let &l:fillchars = substitute(&l:fillchars,',\?fold:.','','gi')
  let l:numwidth = (v:version < 701 ? 8 : &numberwidth)
  let l:foldtext = ' '.(v:foldend-v:foldstart).' lines folded'.v:folddashes.'¦'
  " let l:endofline = (&textwidth>0 ? &textwidth : 80)
  let l:endofline = 100
  let l:linetext = strpart(getline(v:foldstart),0,l:endofline-strlen(l:foldtext))
  let l:align = l:endofline-strlen(l:linetext)
  setlocal fillchars+=fold:\ 
  return printf('%s%*s', l:linetext, l:align, l:foldtext)
endfunction
]])

vim.cmd("set foldtext=FoldText()")
