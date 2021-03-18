let g:SimpylFold_docstring_preview = 1
let g:SimpylFold_fold_docstring = 1
let g:SimpylFold_fold_import = 0
let g:fastfold_savehook = 1
let g:fastfold_fold_command_suffixes =  ['x','X','a','A','o','O','c','C']
let g:fastfold_fold_movement_commands = [']z', '[z', 'zj', 'zk']

function! FoldText()
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

set foldtext=FoldText()
