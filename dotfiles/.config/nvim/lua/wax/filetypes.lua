-- Ensure FileType for specific file pattern
local group_ensure_ft = "Ensure FileType"
vim.api.nvim_create_augroup(group_ensure_ft, { clear = true })

local map_ft_pattern = {
  markdown = { "*.md", "*.md.erb", "*.markdown", "*.mdown", "*.mkd", "*.mkdn" },
  ini = { ".flake8" },
  sh = { "cronfile", "*.txt", "*.env*", "*.flaskenv" },
  zsh = { "*aliases" },
  nix = { "*.nix" },
  config = { ".gitconfig", ".gitignore", "*.conf" },
  yaml = { "*.kubeconfig", "*.yaml", "*.yml" },
  terraform = { "*.tf", "*.tfvars", "*.tfstate" },
  edgeql = { "*.edgeql", "*.esdl" },
}

for filetype, pattern in pairs(map_ft_pattern) do
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    group = group_ensure_ft,
    pattern = pattern,
    command = ("set filetype=%s"):format(filetype),
  })
end

-- Local Settings depending on FileType
local group_ft_settings = "FileType Local Settings"
vim.api.nvim_create_augroup(group_ft_settings, { clear = true })

local map_ft_local_settings = {
  yaml = "shiftwidth=2 tabstop=2 softtabstop=2",
  gitcommit = "spell",
  git = "syntax=on nofoldenable",
  vim = "tabstop=2 foldlevel=99 foldmethod=marker",
  ["*sh"] = "nofoldenable",
  markdown = "spell textwidth=140", -- "wrap wrapmargin=2"
  json = "foldmethod=syntax foldlevel=99",
  edgeql = "commentstring=#%s",
  --
  python = "shiftwidth=4 tabstop=4 softtabstop=4",
  --
  html = "foldmethod=syntax foldlevel=4 nowrap shiftwidth=2 tabstop=2 softtabstop=2",
  [{ "vue", "typescript", "typescriptreact", "javascript", "javascriptreact" }] = "foldminlines=3",
}

for filetype, settings in pairs(map_ft_local_settings) do
  vim.api.nvim_create_autocmd("FileType", {
    group = group_ft_settings,
    pattern = filetype,
    command = ("setlocal %s"):format(settings),
  })
end

-- Performances
-- https://www.reddit.com/r/neovim/comments/pz3wyc/comment/heyy4qf/?utm_source=share&utm_medium=web2x&context=3
vim.api.nvim_exec(
  [[
" disable syntax highlighting in big files
function DisableSyntaxTreesitter()
  echo("Big file, disabling syntax, treesitter and folding")
  if exists(':TSBufDisable')
      exec 'TSBufDisable autotag'
      exec 'TSBufDisable highlight'
      exec 'TSBufDisable indent'
      exec 'TSBufDisable incremental_selection'
      exec 'TSBufDisable context_commentstring'
      exec 'TSBufDisable autopairs'
  endif

  setlocal eventignore+=FileType  " disable all filetype autocommands

  setlocal foldmethod=manual
  setlocal foldexpr=
  setlocal nowrap
  "syntax clear
  "syntax off    " hmmm, which one to use?
  "filetype off

  setlocal noundofile
  setlocal noswapfile
  setlocal noloadplugins
endfunction

function EnableFastFeatures()
  " activate some fast tooling
  LspStart
  exec 'setlocal syntax=' . &ft
endfunction

let g:large_file = 512 * 1024

augroup BigFileDisable
  autocmd!
  autocmd BufReadPre,FileReadPre * if getfsize(expand("%")) > g:large_file | exec DisableSyntaxTreesitter() | endif
  autocmd BufEnter * if getfsize(expand("%")) > g:large_file | exec EnableFastFeatures() | endif
augroup END

]],
  false
)
