-- vim.cmd("syntax on")

-- vim.o.termguicolors = true
vim.o.background = "dark"
vim.g.gruvbox_invert_selection = 0
vim.g.gruvbox_improved_warnings = 1

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

  -- Imp gruvbox signs
  GruvboxGreenSign = { link = "GruvboxGreen" },
  GruvboxRedSign = { link = "GruvboxRed" },
  GruvboxAquaSign = { link = "GruvboxAqua" },
  GruvboxBlueSign = { link = "GruvboxBlue" },
  GruvboxYellowSign = { link = "GruvboxYellow" },
  GruvboxPurpleSign = { link = "GruvboxPurple" },
  GruvboxOrangeSign = { link = "GruvboxOrange" },

  -- statusline
  Statusline = { link = "GruvboxFg3" },
  StatuslineNC = { link = "GruvboxFg4" },

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
  ["@property"] = { link = "white" },
  ["@parameter"] = { link = "white" },
  ["@constant"] = { link = "white" },
  ["@variable"] = { link = "white" },
  ["@field"] = { link = "white" },
  ["@constructor"] = { link = "white" },

  ["@punctuation.special"] = { link = "GruvboxFg3" },
  ["@punctuation.bracket"] = { link = "GruvboxFg3" },
  ["@punctuation.delimiter"] = { link = "white" },
}

local frontend_gruvbox_ts_hls = {
  ["@variable.builtin"] = { link = "GruvboxOrange" },

  ["@function"] = { link = "GruvboxBlue" },
  ["@method"] = { link = "GruvboxBlue" },

  ["@tag.attribute"] = { link = "GruvboxFg3" },

  ["@type"] = { link = "GruvboxYellow" },
  ["@type.builtin"] = { link = "GruvboxYellow" },
}

local python_gruvbox_ts_hls = {
  ["@include"] = { link = "GruvboxBlue" },

  ["@keyword.operator"] = { link = "GruvboxRed" },
  ["@boolean"] = { link = "GruvboxOrange" },

  ["@none"] = { link = "GruvboxFg1" }, -- fstring interpolation

  ["@punctuation.special"] = { link = "GruvboxOrange" }, -- { } of f-string
  ["@punctuation.bracket"] = { link = "white" },
  ["@punctuation.delimiter"] = { link = "white" },

  ["@operator"] = { link = "GruvboxFg1" },

  ["@field"] = { link = "white" },

  ["@constant"] = { link = "white" },
  ["@variable"] = { link = "white" },
  ["@parameter"] = { link = "white" },

  ["@type"] = { link = "GruvboxYellow" },

  ["@method"] = { link = "GruvboxAqua" },
  ["@function"] = { link = "GruvboxAqua" },
  ["@constructor"] = { link = "GruvboxGreen" }, -- used for decorators

  ["@variable.builtin"] = { link = "GruvboxBlue" },
  ["@function.builtin"] = { link = "GruvboxYellow" },
  ["@constant.builtin"] = { link = "GruvboxOrange" },
}

local ts_augroup = "lang-ts-hl-custom"

local apply_gruvbox_theme = function()
  local apply_highlights = function(tbl, lang)
    local ns_id = 0
    if lang then
      ns_id = vim.api.nvim_create_namespace("treesitter/highlighter")
    end
    for k, v in pairs(tbl) do
      vim.api.nvim_set_hl(ns_id, k, vim.tbl_extend("keep", v, { default = false }))
    end
  end

  apply_highlights(base_gruvbox_hls) -- base highlights
  apply_highlights(base_gruvbox_ts_hls) -- treesitter highlights

  vim.api.nvim_create_augroup(ts_augroup, { clear = true })

  vim.api.nvim_create_autocmd("FileType", {
    group = ts_augroup,
    pattern = "python",
    callback = function()
      apply_highlights(python_gruvbox_ts_hls)
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = ts_augroup,
    pattern = { "vue", "typescript", "javascript", "typescriptreact", "javascriptreact" },
    callback = function()
      apply_highlights(frontend_gruvbox_ts_hls)
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = ts_augroup,
    pattern = "yaml",
    callback = function()
      apply_highlights({
        ["@field"] = { link = "GruvboxBlue" },
      })
    end,
  })
end

-- is required to be a global var as it is used in other places
-- to configure plugins
if waxopts.colorscheme == "gruvbox" then
  vim.cmd("silent! colorscheme gruvbox")
  apply_gruvbox_theme()
elseif waxopts.colorscheme == "nord" then
  require("wax.themes.nord")
end

vim.keymap.set("n", "<leader>xc", function()
  vim.cmd("TSHighlightCapturesUnderCursor")
end)

vim.keymap.set("n", "<leader>xz", function()
  require("plenary.reload").reload_module("wax.themes")
  apply_gruvbox_theme()
  vim.api.nvim_exec_autocmds("FileType", ts_augroup)
end)
