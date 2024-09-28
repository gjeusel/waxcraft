local lush = require("lush")
local hsl = lush.hsl

local p = {
  --
  dark0 = hsl("#282828"),
  dark1 = hsl("#3c3836"),
  dark2 = hsl("#504945"),
  dark3 = hsl("#665c54"),
  dark4 = hsl("#7c6f64"),
  --
  gray = hsl("#928374"),
  --
  light0 = hsl("#fbf1c7"),
  light1 = hsl("#ebdbb2"),
  light2 = hsl("#d5c4a1"),
  light3 = hsl("#bdae93"),
  light4 = hsl("#a89984"),
  --
  -- aurora
  red = hsl("#cc241d"),
  green = hsl("#98971a"),
  yellow = hsl("#d79921"),
  blue = hsl("#458588"),
  purple = hsl("#b16286"),
  aqua = hsl("#689d6a"),
  orange = hsl("#d65d0e"),
}

local theme = lush(function(injected_functions)
  local sym = injected_functions.sym

  -- stylua: ignore start
  return {
    Normal         { fg=p.light0.darken(-80) }, -- Normal text

    ColorColumn    { bg=p.dark1 }, -- Columns set with 'colorcolumn'
    Cursor         { bg=p.dark4 }, -- Character under the cursor
    CursorLine     { bg=p.dark2 }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.

    CurSearch      { bg=p.orange.darken(30) }, -- Highlighting a search pattern under the cursor (see 'hlsearch')
    Search         { bg=p.yellow.darken(40)}, -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
    IncSearch      { CurSearch }, -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
    Substitute     { bg=p.orange.darken(40)}, -- |:substitute| replacement text highlighting

    -- Git
    DiffAdd        { fg=p.green }, -- Diff mode: Added line |diff.txt|
    DiffChange     { fg=p.yellow }, -- Diff mode: Changed line |diff.txt|
    DiffDelete     { fg=p.red }, -- Diff mode: Deleted line |diff.txt|
    DiffText       { fg=p.blue }, -- Diff mode: Changed text within a changed line |diff.txt|

    ErrorMsg       { fg=p.red }, -- Error messages on the command line
    VertSplit      { fg=p.light4 }, -- Column separating vertically split windows
    Folded         { fg=p.gray, gui="bold" }, -- Line used for closed folds
    FoldColumn     { }, -- 'foldcolumn'
    SignColumn     { }, -- Column where |signs| are displayed
    CursorLineNr   { fg=p.light2 }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    MatchParen     { bg=p.dark2 }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|

    FloatTitle     { fg=p.light4, gui="bold" }, -- Title of floating windows.
    NormalFloat    { Normal }, -- Normal text in floating windows.
    FloatBorder    { Normal }, -- Border of floating windows.

    Title          { gui="bold" }, -- Titles for output from ":set all", ":autocmd" etc.
    Visual         { bg=p.dark1 }, -- Visual mode selection

    -- Common vim syntax groups used for all kinds of code and markup.
    -- Commented-out groups should chain up to their preferred (*) group
    -- by default. (See :h group-name)

    Comment        { fg=p.dark1.darken(-20) }, -- Any comment
    String         { fg=p.green }, --   A string constant: "this is a string"
    Boolean        { fg=p.orange }, --   A boolean constant: TRUE, false
    Number         { fg=p.purple }, --   A number constant: 234, 0xff
    Float          { Number }, --   A floating point constant: 2.3e10

    -- Identifier     { }, -- (*) Any variable name
    -- Statement      { }, -- (*) Any statement
    -- Operator       { }, --   "sizeof", "+", "*", etc.

    -- Function       { fg=p.frost2 }, --   Function name (also: methods for classes)

    -- Keyword        { fg=p.red }, --   any other keyword
    -- Conditional    { Keyword }, --   if, then, else, endif, switch, etc.
    -- Repeat         { Keyword }, --   for, do, while, etc.
    -- Label          { Keyword }, --   case, default, etc.
    -- Exception      { Keyword }, --   try, catch, throw

    -- PreProc        { }, -- (*) Generic Preprocessor
    -- Include        { }, --   Preprocessor #include
    -- Define         { }, --   Preprocessor #define
    -- Macro          { }, --   Same as Define
    -- PreCondit      { }, --   Preprocessor #if, #else, #endif, etc.

    -- Type           { fg=p.yellow }, -- (*) int, long, char, etc.
    -- StorageClass   { fg=p.yellow }, --   static, register, volatile, etc.
    -- Structure      { fg=p.yellow }, --   struct, union, enum, etc.
    -- Typedef        { fg=p.yellow }, --   A typedef

    -- Special        { fg=p.night3.darken(-30) }, -- (*) Any special symbol
    -- SpecialChar    { }, --   Special character in a constant
    -- Tag            { fg=p.frost0.darken(-20) }, --   You can use CTRL-] on this
    -- Delimiter      { }, --   Character that needs attention
    -- SpecialComment { }, --   Special things inside a comment (e.g. '\n')
    -- Debug          { fg = p.frost2, bg = p.night0 }, --   Debugging statements

    -- Underlined     { gui = "underline" }, -- Text that stands out, HTML links
    -- Ignore         { }, -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
    -- Error          { bg=p.red.darken(50), gui="bold" }, -- Any erroneous construct
    -- Todo           { gui = "bold" }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX

    -- Statusline     { Normal },
    -- StatuslineNC   { fg=p.night3.darken(-20) },

    -- -- These groups are for the native LSP client and diagnostic system. Some
    -- -- other LSP clients may use these groups, or use their own. Consult your
    -- -- LSP client's documentation. (See :h lsp-highlight)

    -- -- LspReferenceText            { } , -- Used for highlighting "text" references
    -- -- LspReferenceRead            { } , -- Used for highlighting "read" references
    -- -- LspReferenceWrite           { } , -- Used for highlighting "write" references
    -- -- LspCodeLens                 { } , -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
    -- -- LspCodeLensSeparator        { } , -- Used to color the seperator between two or more code lens.
    -- -- LspSignatureActiveParameter { } , -- Used to highlight the active parameter in the signature help. See |vim.lsp.handlers.signature_help()|.

    -- -- (See :h diagnostic-highlights)
    -- DiagnosticError            { fg = p.red } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticWarn             { fg = p.yellow } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticInfo             { fg = p.storm0 } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticHint             { fg = p.frost2 } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticOk               { fg = p.green } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- -- DiagnosticVirtualTextError { } , -- Used for "Error" diagnostic virtual text.
    -- -- DiagnosticVirtualTextWarn  { } , -- Used for "Warn" diagnostic virtual text.
    -- -- DiagnosticVirtualTextInfo  { } , -- Used for "Info" diagnostic virtual text.
    -- -- DiagnosticVirtualTextHint  { } , -- Used for "Hint" diagnostic virtual text.
    -- -- DiagnosticVirtualTextOk    { } , -- Used for "Ok" diagnostic virtual text.
    -- -- DiagnosticUnderlineError   { } , -- Used to underline "Error" diagnostics.
    -- -- DiagnosticUnderlineWarn    { } , -- Used to underline "Warn" diagnostics.
    -- -- DiagnosticUnderlineInfo    { } , -- Used to underline "Info" diagnostics.
    -- -- DiagnosticUnderlineHint    { } , -- Used to underline "Hint" diagnostics.
    -- -- DiagnosticUnderlineOk      { } , -- Used to underline "Ok" diagnostics.
    -- -- DiagnosticFloatingError    { } , -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
    -- -- DiagnosticFloatingWarn     { } , -- Used to color "Warn" diagnostic messages in diagnostics float.
    -- -- DiagnosticFloatingInfo     { } , -- Used to color "Info" diagnostic messages in diagnostics float.
    -- -- DiagnosticFloatingHint     { } , -- Used to color "Hint" diagnostic messages in diagnostics float.
    -- -- DiagnosticFloatingOk       { } , -- Used to color "Ok" diagnostic messages in diagnostics float.
    -- -- DiagnosticSignError        { } , -- Used for "Error" signs in sign column.
    -- -- DiagnosticSignWarn         { } , -- Used for "Warn" signs in sign column.
    -- -- DiagnosticSignInfo         { } , -- Used for "Info" signs in sign column.
    -- -- DiagnosticSignHint         { } , -- Used for "Hint" signs in sign column.
    -- -- DiagnosticSignOk           { } , -- Used for "Ok" signs in sign column.

    -- -- Tree-Sitter syntax groups. (See :h treesitter-highlight-groups)

    -- -- sym"@text.literal"      { }, -- Comment
    -- -- sym"@text.reference"    { }, -- Identifier
    -- -- sym"@text.title"        { }, -- Title
    -- -- sym"@text.uri"          { }, -- Underlined
    -- -- sym"@text.underline"    { }, -- Underlined
    -- -- sym"@text.todo"         { }, -- Todo

    -- sym"@comment"           { Comment }, -- Comment

    -- sym"@punctuation"       { }, -- Delimiter
    -- sym"@punctuation.special"       { Special }, -- Delimiter
    -- sym"@punctuation.bracket"       { fg=p.night3.darken(-20) }, -- Delimiter

    -- -- sym"@constant"          { }, -- Constant
    -- sym"@constant.builtin"  { fg=p.orange}, -- Special
    -- -- sym"@constant.macro"    { }, -- Define

    -- -- sym"@define"            { }, -- Define
    -- -- sym"@macro"             { }, -- Macro

    -- sym"@string"            { String }, -- String
    -- -- sym"@string.escape"     { }, -- SpecialChar
    -- -- sym"@string.special"    { }, -- SpecialChar

    -- -- sym"@character"         { }, -- Character
    -- -- sym"@character.special" { }, -- SpecialChar

    -- sym"@number"            { Number }, -- Number
    -- sym"@number.float"      { Number }, -- Float

    -- sym"@boolean"           { Boolean }, -- Boolean

    -- sym"@function"           { Function }, -- Function
    -- sym"@function.builtin"   { fg=p.frost1 }, -- Special
    -- sym"@function.macro"     { Function }, -- Macro
    -- sym"@function.method"    { Function }, -- Macro
    -- sym"@function.call"      {  }, -- Function call
    -- sym"@function.macro.vue" { fg=p.frost3 }, -- Macro

    -- sym"@method"            { Function }, -- Function
    -- sym"@method.call"        {  }, -- Macro

    -- -- sym"@parameter"         { }, -- Identifier
    -- -- sym"@field"             { }, -- Identifier
    -- sym"@property"          { }, -- Identifier
    -- sym"@constructor"       { }, -- Special
    -- -- sym"@conditional"       { }, -- Conditional
    -- sym"@repeat"            { fg=p.red}, -- Repeat
    -- -- sym"@label"             { }, -- Label
    -- sym"@operator"          { Operator }, -- Operator

    -- sym"@keyword"           { fg=p.red }, -- Keyword
    -- sym"@keyword.import"    { fg=p.frost2 }, -- Keyword
    -- sym"@keyword.exception" { Exception }, -- Keyword

    -- -- sym"@exception"         { }, -- Exception

    -- sym"@variable"                 { }, -- Identifier
    -- sym"@variable.builtin"         { fg=p.frost2 }, -- Identifier
    -- sym"@variable.member"          { fg=p.frost2 }, -- Identifier
    -- sym"@variable.member.python"   { Normal }, -- Identifier
    -- sym"@variable.parameter.bash"       { Special },

    -- sym"@type"              { Type }, -- Type
    -- sym"@type.builtin"      { fg=p.orange }, -- Type builtin
    -- sym"@type.builtin.typescript" { fg=p.yellow }, -- Type builtin
    -- -- sym"@type.definition"   { }, -- Typedef
    -- -- sym"@storageclass"      { }, -- StorageClass
    -- -- sym"@structure"         { }, -- Structure
    -- -- sym"@namespace"         { }, -- Identifier
    -- -- sym"@include"           { }, -- Include
    -- -- sym"@preproc"           { }, -- PreProc
    -- -- sym"@debug"             { }, -- Debug
    -- sym"@tag"               { Tag }, -- Tag
    -- sym"@tag.attribute"     { fg=p.frost2 },
    -- sym"@none"              { Normal }, -- Tag
    -- sym"@markup.heading.1"  { fg=p.frost0 },
    -- sym"@markup.heading.2"  { fg=p.frost1 },
    -- sym"@markup.heading.3"  { fg=p.frost2 },
    -- sym"@markup.heading.4"  { fg=p.frost3 },
    -- sym"@markup.heading.5"  { fg=p.frost3 },
    -- sym"@markup.heading.6"  { fg=p.frost3 },

    -- ---- Plugins ----

    -- -- mini indent
    -- MiniIndentscopeSymbol { fg = p.night3 },

    -- -- vim matchup
    -- MatchBackground {},
    -- MatchParentCur  {},
    -- MatchWord       {},
    -- MatchWordCur    {},

    -- -- DAP
    -- DapStoppedLine { Visual },

    -- -- Better floating window
    -- LspInfoBorder    { FloatBorder },
    -- FzfLuaBorder     { FloatBorder },
    -- TelescopeBorder  { FloatBorder },
    -- NullLsInfoBorder { FloatBorder },

    -- -- barbar
    -- BufferCurrent      { fg=p.frost0 },
    -- BufferCurrentSign  { fg=p.frost0 },
    -- BufferCurrentMod   { fg=p.frost0 },
    -- BufferVisible      { fg=p.frost2 },
    -- BufferVisibleSign  { fg=p.frost2 },
    -- BufferVisibleMod   { fg=p.frost2 },
    -- BufferInactive     { Comment },
    -- BufferInactiveSign { Comment },
    -- BufferInactiveMod  { Comment },

    -- -- fidget
    -- FidgetTitle  { fg=p.night3.darken(-40) },
    -- FidgetTask   { Comment },

    -- -- nvim-cmp
    -- CmpItemAbbrMatch        { fg=p.night3.darken(-40) },
    -- CmpItemAbbrMatchFuzzy   { CmpItemAbbrMatch },
    -- CmpItemKind             { fg=p.night3.darken(-50) },
    -- CmpItemMenu             { fg=p.night2 },
    -- CmpItemAbbrDeprecated   { fg=p.night1 },

    -- -- lualine
    -- LualineA { Comment },
    -- LualineB { Comment },
    -- LualineC { Comment },
    -- LualineX { Comment },
    -- LualineY { Comment },
    -- LualineZ { Comment },

  }

  -- stylua: ignore end
end)

return theme
