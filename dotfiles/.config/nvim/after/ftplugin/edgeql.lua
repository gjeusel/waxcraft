vim.opt_local.commentstring = "#%s"
vim.opt_local.shiftwidth = 4

vim.cmd([[
function! EdgeqlIndent(lnum)
    " Find the previous non-blank line.
    let lnum = a:lnum - 1
    while lnum > 0 && getline(lnum) =~ '^\s*$'
        let lnum = lnum - 1
    endwhile

    " If we're at the top of the file, don't indent.
    if lnum == 0
        return 0
    endif

    " Get the previous non-blank line.
    let prevline = getline(lnum)

    " Basic indentation size.
    let indentsize = &shiftwidth

    " Check for common EdgeQL start block keywords.
    if prevline =~ '^\s*\v(select|with|module|for|type)'
        " Increase indent if previous line starts a block.
        return indent(lnum) + indentsize
    else
        " Maintain the same indentation as the previous line.
        return indent(lnum)
    endif
endfunction

" Set the indentexpr to the EdgeqlIndent function.
setlocal indentexpr=EdgeqlIndent(v:lnum)
]])
