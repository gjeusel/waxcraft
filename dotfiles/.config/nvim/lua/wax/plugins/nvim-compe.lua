-- TODO: snippets at: https://elianiva.my.id/post/my-nvim-lsp-setup#sumneko_lua

require("compe").setup({
  enabled = true,
  autocomplete = true,
  debug = false,
  min_length = 1,
  preselect = "enable",
  throttle_time = 80,
  source_timeout = 200,
  resolve_timeout = 800,
  incomplete_delay = 400,
  max_abbr_width = 100,
  max_kind_width = 100,
  max_menu_width = 100,
  documentation = {
    border = { "", "", "", " ", "", "", "", " " }, -- the border option is the same as `|help nvim_open_win|`
    winhighlight = "NormalFloat:CompeDocumentation,FloatBorder:CompeDocumentationBorder",
    max_width = 120,
    min_width = 60,
    max_height = math.floor(vim.o.lines * 0.3),
    min_height = 1,
  },
  source = {
    path = true,
    buffer = true,
    nvim_lsp = true,
    nvim_lua = true,
    -- treesitter = {}, -- slow
    -- snippets
    vsnip = false,
    ultisnips = { priority = 1000 },
    -- sugar
    calc = { filetypes = { "markdown", "text" } },
    spell = { filetypes = { "markdown", "text", "gitcommit" } },
    emoji = { filetypes = { "markdown", "text", "gitcommit" } },
  },
})

local mapopts = { expr = true, silent = true }
vim.api.nvim_set_keymap("i", "<C-Space>", "compe#complete()", mapopts)
-- vim.api.nvim_set_keymap("i", "<CR>", "compe#confirm({ 'keys': '<CR>', 'select': v:true })", mapopts)
-- vim.api.nvim_set_keymap("i", "<C-e>", "compe#close('<C-e'>)", mapopts) -- buggy: https://github.com/hrsh7th/nvim-compe/issues/329
vim.api.nvim_set_keymap("i", "<C-f>", "compe#scroll({ 'delta': +4 })", mapopts)
vim.api.nvim_set_keymap("i", "<C-d>", "compe#scroll({ 'delta': +4 })", mapopts)

local t = function(str)
  return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local check_back_space = function()
  local col = vim.fn.col(".") - 1
  if col == 0 or vim.fn.getline("."):sub(col, col):match("%s") then
    return true
  else
    return false
  end
end

-- Use (s-)tab to:
--- move to prev/next item in completion menuone
--- jump to prev/next snippet's placeholder
_G.tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t("<C-n>")
    -- elseif vim.fn.call("vsnip#available", {1}) == 1 then
    --   return t "<Plug>(vsnip-expand-or-jump)"
  elseif check_back_space() then
    return t("<Tab>")
  else
    return vim.fn["compe#complete"]()
  end
end
_G.s_tab_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t("<C-p>")
    -- elseif vim.fn.call("vsnip#jumpable", {-1}) == 1 then
    --   return t "<Plug>(vsnip-jump-prev)"
  else
    -- If <S-Tab> is not working in your terminal, change it to <C-h>
    return t("<S-Tab>")
  end
end

vim.api.nvim_set_keymap("i", "<Tab>", "v:lua.tab_complete()", mapopts)
vim.api.nvim_set_keymap("s", "<Tab>", "v:lua.tab_complete()", mapopts)
vim.api.nvim_set_keymap("i", "<S-Tab>", "v:lua.s_tab_complete()", mapopts)
vim.api.nvim_set_keymap("s", "<S-Tab>", "v:lua.s_tab_complete()", mapopts)

-- Fix behaviour of completion not closing on <C-c>
_G.control_c_close_complete = function()
  if vim.fn.pumvisible() == 1 then
    return t("<Esc>")
  else
    return t("<C-c>")
  end
end
vim.api.nvim_set_keymap("i", "<C-c>", "v:lua.control_c_close_complete()", mapopts)

-- Fix Behaviours induced by nvim-compe on snippets and < >
vim.g.UltiSnipsSnippetDirectories = { "mysnippets" }
vim.g.UltiSnipsExpandTrigger = "<nop>"
vim.g.UltiSnipsJumpForwardTrigger = "<c-j>"
vim.g.UltiSnipsJumpBackwardTrigger = "<c-k>"
vim.api.nvim_exec(
  [[
" fix behaviour induced by nvim-compe
au BufNewFile,BufRead * imap <nowait>< <
au BufNewFile,BufRead * imap <nowait>> >
au BufNewFile,BufRead * vmap <nowait>< <
au BufNewFile,BufRead * vmap <nowait>> >
au BufNewFile,BufRead *.snippets set filetype=snippets
au BufNewFile,BufRead *.snippets highlight snipLeadingSpaces ctermbg=none
]],
  false
)
