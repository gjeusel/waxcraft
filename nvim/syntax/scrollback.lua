-- Highlights for a terminal's scrollback, the `scrollback` filetype of Rex's copy mode: dim the
-- line above each prompt, color the prompt symbol, embolden the command, and make errors and
-- warnings stand out in the output.

if vim.b.current_syntax then
  return
end

vim.cmd([[
  syntax match scrollbackPreprompt /^.\+\n\ze\(\S\+ \)\?λ/
  syntax match scrollbackCommand /\(^\(\S\+ \)\?\)\@<=λ.*$/ contains=scrollbackSymbol
  syntax match scrollbackSymbol /λ/ contained
  syntax match scrollbackError /\c\<\(error\|errors\|failed\|failure\|fatal\|traceback\)\>/
  syntax match scrollbackWarning /\c\<\(warn\|warning\|warnings\|deprecated\)\>/
  highlight default link scrollbackPreprompt Comment
  highlight default link scrollbackCommand Title
  highlight default link scrollbackSymbol Number
  highlight default link scrollbackError DiagnosticError
  highlight default link scrollbackWarning DiagnosticWarn
]])

vim.b.current_syntax = "scrollback"
