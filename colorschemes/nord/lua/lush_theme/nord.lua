local lush = require("lush")
local hsl = lush.hsl

local p = {
  --
  night0 = hsl("#2e3440"),
  night1 = hsl("#3b4252"),
  night2 = hsl("#434c5e"),
  night3 = hsl("#4c566a"),
  --
  storm0 = hsl("#d8dee9"),
  storm1 = hsl("#e5e9f0"),
  storm2 = hsl("#eceff4"),
  --
  frost0 = hsl("#8fbcbb"),
  frost1 = hsl("#88c0d0"),
  frost2 = hsl("#81a1c1"),
  frost3 = hsl("#5e81ac"),
  --
  -- aurora
  red = hsl("#bf616a"),
  orange = hsl("#d08770"),
  yellow = hsl("#ebcb8b"),
  green = hsl("#a3be8c"),
  purple = hsl("#b48ead"),
}

local theme = lush(function(injected_functions)
  local sym = injected_functions.sym

  -- stylua: ignore start
  return {
    Normal         { fg=p.storm0 }, -- Normal text

    ColorColumn    { bg=p.night0 }, -- Columns set with 'colorcolumn'
    Cursor         { bg=p.night1 }, -- Character under the cursor
    CursorLine     { bg=p.night0 }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.

    CurSearch      { bg=p.orange.darken(65) }, -- Highlighting a search pattern under the cursor (see 'hlsearch')
    Search         { bg=p.yellow.darken(75)}, -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
    IncSearch      { CurSearch }, -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
    Substitute     { bg=p.orange.darken(55)}, -- |:substitute| replacement text highlighting

    -- Git
    DiffAdd        { bg=p.green.darken(75), blend=80 }, -- Diff mode: Added line |diff.txt|
    DiffChange     { bg=p.yellow.darken(75) }, -- Diff mode: Changed line |diff.txt|
    DiffDelete     { bg=p.red.darken(75) }, -- Diff mode: Deleted line |diff.txt|
    DiffText       { bg=p.frost2.darken(70) }, -- Diff mode: Changed text within a changed line |diff.txt|

    ErrorMsg       { fg=p.red }, -- Error messages on the command line
    VertSplit      { fg=p.storm0 }, -- Column separating vertically split windows
    Folded         { fg=Normal.fg.darken(25), gui="bold" }, -- Line used for closed folds
    FoldColumn     { }, -- 'foldcolumn'
    SignColumn     { }, -- Column where |signs| are displayed
    CursorLineNr   { fg=p.storm0 }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    MatchParen     { bg=p.night3 }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
    -- NonText        { fg=p.frost0 }, -- character like linebreak ⤷

    FloatTitle     { fg=p.storm2, gui="bold" }, -- Title of floating windows.
    FloatShadow    { bg=p.night1 },
    NormalFloat    { Normal }, -- Normal text in floating windows.
    FloatBorder    { Normal }, -- Border of floating windows.

    Title          { gui="bold" }, -- Titles for output from ":set all", ":autocmd" etc.
    Visual         { bg=p.night1 }, -- Visual mode selection

    Pmenu          { bg=p.night0, fg=p.storm1 },
    PmenuSel       { bg=p.night3, fg=p.storm0 },

    -- Common vim syntax groups used for all kinds of code and markup.
    -- Commented-out groups should chain up to their preferred (*) group
    -- by default. (See :h group-name)

    Comment        { fg=p.night3.darken(-20) }, -- Any comment
    String         { fg=p.green }, --   A string constant: "this is a string"
    Boolean        { fg=p.orange }, --   A boolean constant: TRUE, false
    Number         { fg=p.purple }, --   A number constant: 234, 0xff
    Float          { Number }, --   A floating point constant: 2.3e10

    Identifier     { }, -- (*) Any variable name
    Statement      { }, -- (*) Any statement
    Operator       { }, --   "sizeof", "+", "*", etc.

    Function       { fg=p.frost2 }, --   Function name (also: methods for classes)

    Keyword        { fg=p.red }, --   any other keyword
    Conditional    { Keyword }, --   if, then, else, endif, switch, etc.
    Repeat         { Keyword }, --   for, do, while, etc.
    Label          { Keyword }, --   case, default, etc.
    Exception      { Keyword }, --   try, catch, throw

    PreProc        { }, -- (*) Generic Preprocessor
    Include        { }, --   Preprocessor #include
    Define         { }, --   Preprocessor #define
    Macro          { }, --   Same as Define
    PreCondit      { }, --   Preprocessor #if, #else, #endif, etc.

    Type           { fg=p.yellow }, -- (*) int, long, char, etc.
    StorageClass   { fg=p.yellow }, --   static, register, volatile, etc.
    Structure      { fg=p.yellow }, --   struct, union, enum, etc.
    Typedef        { fg=p.yellow }, --   A typedef

    Special        { fg=p.night3.darken(-30) }, -- (*) Any special symbol
    SpecialChar    { }, --   Special character in a constant
    Tag            { fg=p.frost0.darken(-20) }, --   You can use CTRL-] on this
    Delimiter      { }, --   Character that needs attention
    SpecialComment { }, --   Special things inside a comment (e.g. '\n')
    Debug          { fg = p.frost2, bg = p.night0 }, --   Debugging statements

    Underlined     { gui = "underline" }, -- Text that stands out, HTML links
    Ignore         { }, -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
    Error          { bg=p.red.darken(50), gui="bold" }, -- Any erroneous construct
    Todo           { gui = "bold" }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX

    Statusline     { Normal },
    StatuslineNC   { fg=p.night3.darken(-20) },

    -- These groups are for the native LSP client and diagnostic system. Some
    -- other LSP clients may use these groups, or use their own. Consult your
    -- LSP client's documentation. (See :h lsp-highlight)

    -- LspReferenceText            { } , -- Used for highlighting "text" references
    -- LspReferenceRead            { } , -- Used for highlighting "read" references
    -- LspReferenceWrite           { } , -- Used for highlighting "write" references
    -- LspCodeLens                 { } , -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
    -- LspCodeLensSeparator        { } , -- Used to color the seperator between two or more code lens.
    -- LspSignatureActiveParameter { } , -- Used to highlight the active parameter in the signature help. See |vim.lsp.handlers.signature_help()|.

    -- (See :h diagnostic-highlights)
    DiagnosticError            { fg = p.red } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticWarn             { fg = p.yellow } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticInfo             { fg = p.storm0 } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticHint             { fg = p.frost2 } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticOk               { fg = p.green } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticVirtualTextError { } , -- Used for "Error" diagnostic virtual text.
    -- DiagnosticVirtualTextWarn  { } , -- Used for "Warn" diagnostic virtual text.
    -- DiagnosticVirtualTextInfo  { } , -- Used for "Info" diagnostic virtual text.
    -- DiagnosticVirtualTextHint  { } , -- Used for "Hint" diagnostic virtual text.
    -- DiagnosticVirtualTextOk    { } , -- Used for "Ok" diagnostic virtual text.
    -- DiagnosticUnderlineError   { } , -- Used to underline "Error" diagnostics.
    -- DiagnosticUnderlineWarn    { } , -- Used to underline "Warn" diagnostics.
    -- DiagnosticUnderlineInfo    { } , -- Used to underline "Info" diagnostics.
    -- DiagnosticUnderlineHint    { } , -- Used to underline "Hint" diagnostics.
    -- DiagnosticUnderlineOk      { } , -- Used to underline "Ok" diagnostics.
    -- DiagnosticFloatingError    { } , -- Used to color "Error" diagnostic messages in diagnostics float. See |vim.diagnostic.open_float()|
    -- DiagnosticFloatingWarn     { } , -- Used to color "Warn" diagnostic messages in diagnostics float.
    -- DiagnosticFloatingInfo     { } , -- Used to color "Info" diagnostic messages in diagnostics float.
    -- DiagnosticFloatingHint     { } , -- Used to color "Hint" diagnostic messages in diagnostics float.
    -- DiagnosticFloatingOk       { } , -- Used to color "Ok" diagnostic messages in diagnostics float.
    -- DiagnosticSignError        { } , -- Used for "Error" signs in sign column.
    -- DiagnosticSignWarn         { } , -- Used for "Warn" signs in sign column.
    -- DiagnosticSignInfo         { } , -- Used for "Info" signs in sign column.
    -- DiagnosticSignHint         { } , -- Used for "Hint" signs in sign column.
    -- DiagnosticSignOk           { } , -- Used for "Ok" signs in sign column.

    -- netrw
    Directory { fg=p.frost2 },

    -- Tree-Sitter syntax groups. (See :h treesitter-highlight-groups)

    -- sym"@text.literal"      { }, -- Comment
    -- sym"@text.reference"    { }, -- Identifier
    -- sym"@text.title"        { }, -- Title
    -- sym"@text.uri"          { }, -- Underlined
    -- sym"@text.underline"    { }, -- Underlined
    -- sym"@text.todo"         { }, -- Todo

    sym"@comment"           { Comment }, -- Comment

    sym"@punctuation"       { }, -- Delimiter
    sym"@punctuation.special"       { Special }, -- Delimiter
    sym"@punctuation.bracket"       { fg=p.night3.darken(-20) }, -- Delimiter

    -- sym"@constant"          { }, -- Constant
    sym"@constant.builtin"  { fg=p.orange}, -- Special
    -- sym"@constant.macro"    { }, -- Define

    -- sym"@define"            { }, -- Define
    -- sym"@macro"             { }, -- Macro

    sym"@string"            { String }, -- String
    -- sym"@string.escape"     { }, -- SpecialChar
    -- sym"@string.special"    { }, -- SpecialChar

    -- sym"@character"         { }, -- Character
    -- sym"@character.special" { }, -- SpecialChar

    sym"@number"            { Number }, -- Number
    sym"@number.float"      { Number }, -- Float

    sym"@boolean"           { Boolean }, -- Boolean

    sym"@function"           { Function }, -- Function
    sym"@function.builtin"   { fg=p.frost1 }, -- Special
    sym"@function.macro"     { Function }, -- Macro
    sym"@function.method"    { Function }, -- Macro
    sym"@function.call"      {  }, -- Function call
    sym"@function.macro.vue" { fg=p.frost3 }, -- Macro

    sym"@method"            { Function }, -- Function
    sym"@method.call"        {  }, -- Macro

    -- sym"@parameter"         { }, -- Identifier
    -- sym"@field"             { }, -- Identifier
    sym"@property"          { }, -- Identifier
    sym"@property.yaml"     { fg=p.frost2 }, -- Identifier
    sym"@property.jsonc"     { fg=p.frost2 }, -- Identifier
    sym"@constructor"       { }, -- Special
    -- sym"@conditional"       { }, -- Conditional
    sym"@repeat"            { fg=p.red}, -- Repeat
    -- sym"@label"             { }, -- Label
    sym"@operator"          { Operator }, -- Operator

    sym"@keyword"           { fg=p.red }, -- Keyword
    sym"@keyword.vim"       { fg=p.frost2 }, -- Keyword
    sym"@keyword.import"    { fg=p.frost2 }, -- Keyword
    sym"@keyword.exception" { Exception }, -- Keyword

    -- sym"@exception"         { }, -- Exception

    sym"@variable"                 { }, -- Identifier
    sym"@variable.builtin"         { fg=p.frost2 }, -- Identifier
    sym"@variable.member"          { fg=p.frost2 }, -- Identifier
    sym"@variable.member.python"   { Normal }, -- Identifier
    sym"@variable.member.lua"      { Normal }, -- Identifier
    sym"@variable.parameter.bash"       { Special },

    sym"@module.builtin" { },

    sym"@type"              { Type }, -- Type
    sym"@type.builtin"      { fg=p.orange }, -- Type builtin
    sym"@type.builtin.typescript" { fg=p.yellow }, -- Type builtin
    -- sym"@type.definition"   { }, -- Typedef
    -- sym"@storageclass"      { }, -- StorageClass
    -- sym"@structure"         { }, -- Structure
    -- sym"@namespace"         { }, -- Identifier
    -- sym"@include"           { }, -- Include
    -- sym"@preproc"           { }, -- PreProc
    -- sym"@debug"             { }, -- Debug
    sym"@tag"               { Tag }, -- Tag
    sym"@tag.attribute"     { fg=p.frost2 },
    sym"@none"              { Normal }, -- Tag
    sym"@markup.heading.1"  { fg=p.frost0 },
    sym"@markup.heading.2"  { fg=p.frost1 },
    sym"@markup.heading.3"  { fg=p.frost2 },
    sym"@markup.heading.4"  { fg=p.frost3 },
    sym"@markup.heading.5"  { fg=p.frost3 },
    sym"@markup.heading.6"  { fg=p.frost3 },

    -- for commit diff view:
    sym"@diff.minus" { fg=p.red },
    sym"@diff.plus"  { fg=p.green },

    ---- Plugins ----

    -- mini indent
    MiniIndentscopeSymbol { fg = p.night3 },

    -- vim matchup
    MatchBackground {},
    MatchParentCur  {},
    MatchWord       {},
    MatchWordCur    {},

    -- DAP
    DapStoppedLine { Visual },

    -- Better floating window
    LspInfoBorder    { FloatBorder },
    FzfLuaBorder     { FloatBorder },
    TelescopeBorder  { FloatBorder },
    NullLsInfoBorder { FloatBorder },

    -- barbar
    BufferCurrent      { fg=p.frost0 },
    BufferCurrentSign  { fg=p.frost0 },
    BufferCurrentMod   { fg=p.frost0 },
    BufferVisible      { fg=p.frost2 },
    BufferVisibleSign  { fg=p.frost2 },
    BufferVisibleMod   { fg=p.frost2 },
    BufferInactive     { Comment },
    BufferInactiveSign { Comment },
    BufferInactiveMod  { Comment },

    -- fidget
    FidgetTitle  { fg=p.night3.darken(-40) },
    FidgetTask   { Comment },

    -- nvim-cmp
    CmpItemAbbrMatch        { fg=p.night3.darken(-40) },
    CmpItemAbbrMatchFuzzy   { CmpItemAbbrMatch },
    CmpItemKind             { fg=p.night3.darken(-50) },
    CmpItemMenu             { fg=p.night2 },
    CmpItemAbbrDeprecated   { fg=p.night1 },

    -- lualine
    LualineA { Comment },
    LualineB { Comment },
    LualineC { Comment },
    LualineX { Comment },
    LualineY { Comment },
    LualineZ { Comment },

    -- vim startify
    StartifyBracket   { Special },
    StartifyFile      { fg=p.storm2 },
    StartifyPath      { StartifyFile },
    StartifySlash     { StartifyFile },
    StartifySection   { fg=p.frost2 },
    StartifyHeader    { fg=p.frost1 },

  }

  -- stylua: ignore end
end)

return theme
