--
-------- Gruvbox Specific --------
--
-- TreeSitter list of highlights: https://github.com/nvim-treesitter/nvim-treesitter/blob/master/CONTRIBUTING.md
--

local base_gruvbox_hls = {
  -- Base interface
  Normal = { ctermbg = nil },
  NormalFloat = { ctermbg = nil },
  SignColumn = { ctermbg = nil },
  VertSplit = { ctermbg = nil, ctermfg = 248 },
  CursorLineNr = { ctermbg = nil },
  EndOfBuffer = { ctermbg = nil },
  ColorColumn = { ctermbg = nil },

  -- Better diff views
  DiffAdd = { cterm = nil, ctermfg = "Green", ctermbg = nil },
  DiffChange = { cterm = nil, ctermfg = "Yellow", ctermbg = nil },
  DiffDelete = { cterm = nil, ctermfg = "Red", ctermbg = nil },
  DiffText = { cterm = nil, ctermfg = "Blue", ctermbg = nil },

  -- Better floating windows hl
  FloatTitle = { link = "GruvboxAqua" },
  FloatBorder = { link = "GruvboxAqua" },
  LspInfoBorder = { link = "GruvboxAqua" },
  FzfLuaBorder = { link = "GruvboxAqua" },
  TelescopeBorder = { link = "GruvboxAqua" },
  NullLsInfoBorder = { link = "GruvboxAqua" },

  -- Vim Matchup
  MatchBackground = { cterm = nil, ctermfg = nil, ctermbg = nil },
  MatchParentCur = { cterm = nil, ctermfg = nil, ctermbg = nil },
  MatchParen = { cterm = nil, ctermfg = nil, ctermbg = nil },
  MatchWord = { cterm = nil, ctermfg = nil, ctermbg = nil },
  MatchWordCur = { cterm = nil, ctermfg = nil, ctermbg = nil },

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

  -- fidget
  FidgetTitle = { link = "GruvboxFg3" },
  FidgetTask = { link = "GruvboxFg4" },

  -- nvim-cmp
  CmpItemAbbrMatch = { link = "GruvboxFg3" },
  CmpItemAbbrMatchFuzzy = { link = "GruvboxFg3" },
  CmpItemKind = { link = "GruvboxFg4" },
  CmpItemMenu = { link = "GruvboxBg4" },
  CmpItemAbbrDeprecated = { strikethrough = true },
}

local base_gruvbox_ts_hls = {
  ["@keyword.import"] = { link = "GruvboxBlue" },
  ["@keyword.exception"] = { link = "GruvboxRed" },
  ["@keyword.operator"] = { link = "GruvboxRed" },

  ["@variable.parameter"] = { link = "white" },
  ["@constant"] = { link = "white" },
  ["@constant.builtin"] = { link = "GruvboxOrange" },

  ["@variable"] = { link = "white" },

  ["@field"] = { link = "white" },
  ["@constructor"] = { link = "white" },

  ["@punctuation.special"] = { link = "GruvboxFg3" },
  ["@punctuation.bracket"] = { link = "GruvboxFg3" },
  ["@punctuation.delimiter"] = { link = "white" },

  ["@method.call"] = { link = "white" },
  ["@function.call"] = { link = "white" },

  -- html
  ["@tag"] = { link = "GruvboxRed" },
  ["@tag.delimiter"] = { link = "GruvboxFg4" },
  ["@tag.attribute"] = { link = "GruvboxAqua" },
}

local frontend_gruvbox_ts_hls = {
  ["@function.call"] = { link = "white" },
  ["@definition.function"] = { link = "GruvboxBlue" },

  ["@repeat"] = { link = "GruvboxRed" },
  ["@property"] = { link = "white" },

  -- ["@method.call"] = { link = "GruvboxBlue" },
  ["@function.method"] = { link = "GruvboxBlue" },

  ["@type"] = { link = "GruvboxYellow" },
  ["@type.builtin"] = { link = "GruvboxYellow" },
}

local python_gruvbox_ts_hls = {
  ["@boolean"] = { link = "GruvboxOrange" },

  ["@type.builtin"] = { link = "GruvboxAqua" }, -- used for exception

  ["@punctuation.special"] = { link = "GruvboxOrange" }, -- { } of f-string
  ["@punctuation.bracket"] = { link = "white" },
  ["@punctuation.delimiter"] = { link = "white" },

  ["@none"] = { link = "GruvboxFg1" }, -- fstring interpolation
  ["@operator"] = { link = "GruvboxFg1" },

  ["@type"] = { link = "GruvboxYellow" },

  ["@variable.builtin"] = { link = "GruvboxBlue" },
  ["@function.builtin"] = { link = "GruvboxYellow" },

  -- functions / methods / calls
  ["@function"] = { link = "GruvboxAqua" },
  ["@function.method"] = { link = "GruvboxAqua" },

  ["@method"] = { link = "GruvboxAqua" },
  ["@definition.function"] = { link = "GruvboxAqua" },

  ["@function.macro"] = { link = "GruvboxGreen" }, -- used for decorators
}

local map_gruvbox_filetype_hls = {
  --
  -- backend:
  python = python_gruvbox_ts_hls,
  --
  -- frontend:
  [{ "typescript", "javascript", "typescriptreact", "javascriptreact" }] = frontend_gruvbox_ts_hls,
  vue = vim.tbl_extend("force", frontend_gruvbox_ts_hls, {
    ["@function.macro"] = { link = "GruvboxBlueBold" },
    ["@field"] = { link = "GruvboxBlue" },
    -- ["@method"] = { link = "GruvboxBlue" }, -- tag binded attribute
  }),
  --
  -- common:
  lua = {
    ["@function"] = { link = "GruvboxBlueBold" },
    ["@function.call"] = { link = "white" },
    ["@function.builtin"] = { link = "GruvboxYellow" },
    ["@comment"] = { link = "Comment" },
    ["@variable"] = { link = "white" },
    ["@variable.member"] = { link = "white" },
  },
  yaml = {
    ["@field"] = { link = "GruvboxBlue" },
  },
  md = {
    ["@function.call"] = { link = "GruvboxGreen" },
  },
}

local ts_augroup = "lang-ts-hl-custom"
vim.api.nvim_create_augroup(ts_augroup, { clear = true })

---Apply TS highlights from a mapping.
---@param tbl table
---@param filetype? string
local function apply_highlights(tbl, filetype)
  for ts_key, hl in pairs(tbl) do
    -- If filetype is given, convert the treesitter key to be applied for this filetype only
    if filetype ~= nil then
      ts_key = ("%s.%s"):format(ts_key, filetype)
    end

    vim.api.nvim_set_hl(0, ts_key, vim.tbl_extend("keep", hl, { default = false }))
  end
end

--Apply TS highlights for gruvbox colorscheme
local function apply_gruvbox_theme()
  apply_highlights(base_gruvbox_hls) -- base highlights
  apply_highlights(base_gruvbox_ts_hls) -- common treesitter highlights

  -- Generate all FileType autocmds for treesitter:
  for filetypes, map_filetype_hls in pairs(map_gruvbox_filetype_hls) do
    if type(filetypes) == "string" then
      apply_highlights(map_filetype_hls, filetypes)
    else
      for _, filetype in ipairs(filetypes) do
        apply_highlights(map_filetype_hls, filetype)
      end
    end
  end
end

--
-------- Apply my TS theme --------
--
apply_gruvbox_theme()

vim.keymap.set("n", "<leader>xc", function()
  vim.cmd("TSHighlightCapturesUnderCursor")
end)

vim.keymap.set("n", "<leader>xz", function()
  require("plenary.reload").reload_module("wax.themes")
  apply_gruvbox_theme()
  vim.api.nvim_exec_autocmds("FileType", { group = ts_augroup })
end)
