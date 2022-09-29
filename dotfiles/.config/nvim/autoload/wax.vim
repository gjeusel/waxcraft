function! wax#foldexpr() abort
	return luaeval(printf('require("wax.folds").get_fold_indic(%d)', v:lnum))
endfunction
