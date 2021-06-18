local M = {}

M.grep_cmds = {
  rg = {
    'rg',
    '--color=never',
    '--no-heading',
    '--with-filename',
    '--line-number',
    '--column',
    '--smart-case'
  },
  ag = {
    'ag',
    '--nocolor',
    '--filename',
    '--noheading',
    '--line-number',
    '--column',
    '--smart-case',
    '--hidden',  -- search hidden files
    '--follow',  -- follow symlinks
  },
  git = {
    "git", "grep",
    "--ignore-case",
    "--untracked",
    "--exclude-standard",
    "--line-number",
    "--column",
    "-I",  -- don't match pattern in binary files
    -- "--threads", "10",
    "--full-name",
  }
}

return M
