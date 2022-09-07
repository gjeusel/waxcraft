-- vim.cmd("syntax on")

-- vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.gruvbox_invert_selection = 0
vim.g.gruvbox_improved_warnings = 1

vim.g.nord_disable_background = true

-- Highlight API is still a wip in nvim: https://github.com/nanotee/nvim-lua-guide#defining-syntaxhighlights

-- TreeSitter list of highlights:
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/8adb2e0352858d1b12c0b4ee3617c9f38ed8c53b/lua/nvim-treesitter/highlight.lua

-- Gruvbox Specific
local base_gruvbox_hls = {
  -- Base interface
  Normal = { ctermbg = nil },
  NormalFloat = { ctermbg = nil },
  SignColumn = { ctermbg = nil },
  VertSplit = { ctermbg = nil, ctermfg = 248 },
  CursorLineNr = { ctermbg = nil },
  EndOfBuffer = { ctermbg = nil },
  ColorColumn = { ctermbg = 236 },

  -- Better diff views
  DiffAdd = { cterm = nil, ctermfg = "Green", ctermbg = nil },
  DiffChange = { cterm = nil, ctermfg = "Yellow", ctermbg = nil },
  DiffDelete = { cterm = nil, ctermfg = "Red", ctermbg = nil },
  DiffText = { cterm = nil, ctermfg = "Blue", ctermbg = nil },

  -- statusline
  Statusline = { link = "GruvboxFg3" },

  -- barbar
  BufferCurrent = { link = "GruvboxFg1" },
  BufferCurrentSign = { link = "GruvboxAqua" },
  BufferCurrentMod = { link = "GruvboxAqua" },

  BufferVisible = { link = "GruvboxFg2" },
  BufferVisibleSign = { link = "GruvboxBlue" },
  BufferVisibleMod = { link = "GruvboxBlue" },

  BufferInactive = { link = "GruvboxFg4" },
  BufferInactiveSign = { link = "GruvboxFg4" },
  BufferInactiveMod = { link = "GruvboxFg4" },

  BufferTabpages = { link = "GruvboxBg0" },
  BufferTabpageFill = { link = "GruvboxBg0" },

  -- fold
  Folded = { bold = true, ctermbg = nil, ctermfg = 248 },

  -- lsp
  DiagnosticError = { link = "GruvboxRed" },
  DiagnosticWarn = { link = "GruvboxYellow" },
  DiagnosticInfo = { link = "GruvboxFg3" },
  DiagnosticHint = { link = "GruvboxBlue" },

  -- nvim-cmp
  CmpItemAbbrMatch = { link = "GruvboxFg3" },
  CmpItemAbbrMatchFuzzy = { link = "GruvboxFg3" },
  CmpItemKind = { link = "GruvboxFg4" },
  CmpItemMenu = { link = "GruvboxBg4" },
  CmpItemAbbrDeprecated = { strikethrough = true },
}

local base_gruvbox_ts_hls = {
  TSProperty = { link = "white" },
  TSParameter = { link = "white" },
  TSConstant = { link = "white" },
  TSVariable = { link = "white" },
  TSField = { link = "white" },
  TSConstructor = { link = "white" },

  TSPunctSpecial = { link = "GruvboxFg3" },
  TSPunctBracket = { link = "GruvboxFg3" },
  TSPunctDelimiter = { link = "white" },
}

local frontend_gruvbox_ts_hls = {
  TSVariableBuiltin = { link = "GruvboxOrange" },

  TSFunction = { link = "GruvboxBlue" },
  TSMethod = { link = "GruvboxBlue" },

  TSTagAttribute = { link = "GruvboxFg3" },

  TSType = { link = "GruvboxYellow" },
  TSTypeBuiltin = { link = "GruvboxYellow" },

  TSTitle = { link = "GruvboxYellow" },
}

local python_gruvbox_ts_hls = {
  TSInclude = { link = "GruvboxBlue" },

  TSKeywordOperator = { link = "GruvboxRed" },
  TSBoolean = { link = "GruvboxOrange" },

  TSNone = { link = "GruvboxFg1" }, -- fstring interpolation

  TSPunctDelimiter = { link = "white" },
  TSPunctBracket = { link = "white" },
  TSPunctSpecial = { link = "GruvboxOrange" }, -- { } of f-string

  TSOperator = { link = "GruvboxFg1" },

  TSField = { link = "white" },

  TSConstant = { link = "white" },
  TSVariable = { link = "white" },
  TSParameter = { link = "white" },

  TSType = { link = "GruvboxYellow" },

  TSMethod = { link = "GruvboxAqua" },
  TSFunction = { link = "GruvboxAqua" },
  TSConstructor = { link = "GruvboxGreen" }, -- used for decorators

  TSVariableBuiltin = { link = "GruvboxBlue" },
  TSFuncBuiltin = { link = "GruvboxYellow" },
  TSConstBuiltin = { link = "GruvboxOrange" },
}

local apply_gruvbox_theme = function()
  local apply_highlights = function(tbl)
    for k, v in pairs(tbl) do
      vim.api.nvim_set_hl(0, k, vim.tbl_extend("keep", v, { default = false }))
    end
  end

  local highlights = vim.tbl_extend("keep", base_gruvbox_hls, base_gruvbox_ts_hls)
  apply_highlights(highlights)

  local python_ts_hl_group = "python-ts-hl"
  vim.api.nvim_create_augroup(python_ts_hl_group, { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = python_ts_hl_group,
    pattern = "python",
    callback = function()
      apply_highlights(python_gruvbox_ts_hls)
    end,
  })

  local frontend_ts_hl_group = "frontend-ts-hl"
  vim.api.nvim_create_augroup(frontend_ts_hl_group, { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = frontend_ts_hl_group,
    pattern = { "vue", "typescript", "javascript", "typescriptreact", "javascriptreact" },
    callback = function()
      apply_highlights(frontend_gruvbox_ts_hls)
    end,
  })
end

local apply_treesitter_python_theme = function()
  vim.api.nvim_exec(
    [[
    hi! link pythonInclude GruvboxBlue

    hi! link pythonKeywordOperator GruvboxRed
    hi! link pythonBoolean GruvboxOrange

    hi! link pythonNone GruvboxFg1  " fstring interpolation

    hi! link pythonPunctDelimiter white
    hi! link pythonPunctBracket white
    hi! link pythonPunctSpecial GruvboxOrange  " { } of f-string

    hi! link pythonOperator GruvboxFg1

    hi! link pythonConstant white
    hi! link pythonConstructor white
    hi! link pythonField white

    hi! link pythonConstant white
    hi! link pythonVariable white
    hi! link pythonParameter white

    hi! link pythonType GruvboxYellow
    hi! link pythonMethod GruvboxAqua
    hi! link pythonFunction GruvboxAqua
    hi! link pythonConstructor GruvboxGreen  " used for decorators

    hi! link pythonVariableBuiltin GruvboxBlue
    hi! link pythonFuncBuiltin GruvboxYellow
    hi! link pythonConstBuiltin GruvboxOrange
  ]],
    false
  )
end

if iterm_colorscheme == "gruvbox" then
  vim.cmd("silent! colorscheme gruvbox")
  apply_gruvbox_theme()
elseif iterm_colorscheme == "nord" then
  require("wax.themes.nord")
end

nnoremap("<leader>xc", "<cmd>TSHighlightCapturesUnderCursor<cr>")
nnoremap(
  "<leader>xz",
  "<cmd>lua require('plenary.reload').reload_module('wax.themes'); require('wax.themes').apply_treesitter_gruvbox_theme()<cr>"
)
