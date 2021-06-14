-- syntax (colors for self keyword for example)
vim.g.pymode_syntax = 1
vim.g.pymode_syntax_all = 1

-- Disable all the rest, we only want syntax coloring
vim.g.pymode_indent = 1           -- pep8 indent
vim.g.pymode_folding = 0          -- disable folding to use SimpyFold
vim.g.pymode_motion = 1           -- give jumps to functions / methods / classes
vim.g.pymode_doc = 0
vim.g.pymode_trim_whitespaces = 0 -- do not trim unused white spaces on save
vim.g.pymode_rope = 0             -- disable rope
vim.g.pymode_lint = 0             -- disable lint
vim.g.pymode_breakpoint = 0       -- disable it for custom
vim.g.pymode_run_bind = ''        -- don't bind <leader>r used for references
