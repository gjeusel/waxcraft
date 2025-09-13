local lush = require("lush")
local hsl = lush.hsl

local p = {
  -- rose-pine main variant
  base = hsl("#191724"),
  surface = hsl("#1f1d2e"),
  overlay = hsl("#26233a"),
  muted = hsl("#6e6a86"),
  subtle = hsl("#908caa"),
  text = hsl("#e0def4"),
  love = hsl("#eb6f92"),
  gold = hsl("#f6c177"),
  rose = hsl("#ebbcba"),
  pine = hsl("#31748f"),
  foam = hsl("#9ccfd8"),
  iris = hsl("#c4a7e7"),
  highlight_low = hsl("#21202e"),
  highlight_med = hsl("#403d52"),
  highlight_high = hsl("#524f67"),
}

local theme = lush(function(injected_functions)
  local sym = injected_functions.sym

  -- stylua: ignore start
  return {
    Normal         { fg=p.text }, -- Normal text

    ColorColumn    { bg=p.highlight_med }, -- Columns set with 'colorcolumn'
    Cursor         { bg=p.surface }, -- Character under the cursor
    CursorLine     { bg=p.highlight_low }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.

    CurSearch      { bg=p.love.darken(65) }, -- Highlighting a search pattern under the cursor (see 'hlsearch')
    Search         { bg=p.gold.darken(75)}, -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
    IncSearch      { CurSearch }, -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
    Substitute     { bg=p.love.darken(55)}, -- |:substitute| replacement text highlighting

    -- Git
    DiffAdd        { bg=p.pine.darken(75), blend=80 }, -- Diff mode: Added line |diff.txt|
    DiffChange     { bg=p.gold.darken(75) }, -- Diff mode: Changed line |diff.txt|
    DiffDelete     { bg=p.love.darken(75) }, -- Diff mode: Deleted line |diff.txt|
    DiffText       { bg=p.foam.darken(70) }, -- Diff mode: Changed text within a changed line |diff.txt|

    ErrorMsg       { fg=p.love }, -- Error messages on the command line
    VertSplit      { fg=p.text }, -- Column separating vertically split windows
    Folded         { fg=Normal.fg, blend=20, gui="bold" }, -- Line used for closed folds
    FoldColumn     { }, -- 'foldcolumn'
    SignColumn     { }, -- Column where |signs| are displayed
    CursorLineNr   { fg=p.text }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    MatchParen     { bg=p.highlight_med }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
    -- NonText        { fg=p.foam }, -- character like linebreak ⤷

    FloatTitle     { fg=p.text, gui="bold" }, -- Title of floating windows.
    FloatShadow    { bg=p.surface },
    NormalFloat    { Normal }, -- Normal text in floating windows.
    FloatBorder    { Normal }, -- Border of floating windows.

    Title          { gui="bold" }, -- Titles for output from ":set all", ":autocmd" etc.
    Visual         { bg=p.surface }, -- Visual mode selection

    Pmenu          { bg=p.highlight_low, fg=p.subtle },
    PmenuSel       { bg=p.highlight_med, fg=p.text },

    -- Common vim syntax groups used for all kinds of code and markup.
    -- Commented-out groups should chain up to their preferred (*) group
    -- by default. (See :h group-name)

    Comment        { fg=p.muted.darken(-20) }, -- Any comment
    String         { fg=p.gold }, --   A string constant: "this is a string"
    Boolean        { fg=p.rose }, --   A boolean constant: TRUE, false
    Number         { fg=p.iris }, --   A number constant: 234, 0xff
    Float          { Number }, --   A floating point constant: 2.3e10

    Identifier     { }, -- (*) Any variable name
    Statement      { }, -- (*) Any statement
    Operator       { }, --   "sizeof", "+", "*", etc.

    Function       { fg=p.foam }, --   Function name (also: methods for classes)

    Keyword        { fg=p.pine }, --   any other keyword
    Conditional    { Keyword }, --   if, then, else, endif, switch, etc.
    Repeat         { Keyword }, --   for, do, while, etc.
    Label          { Keyword }, --   case, default, etc.
    Exception      { Keyword }, --   try, catch, throw

    PreProc        { }, -- (*) Generic Preprocessor
    Include        { }, --   Preprocessor #include
    Define         { }, --   Preprocessor #define
    Macro          { }, --   Same as Define
    PreCondit      { }, --   Preprocessor #if, #else, #endif, etc.

    Type           { fg=p.foam }, -- (*) int, long, char, etc.
    StorageClass   { fg=p.foam }, --   static, register, volatile, etc.
    Structure      { fg=p.foam }, --   struct, union, enum, etc.
    Typedef        { fg=p.foam }, --   A typedef

    Special        { fg=p.subtle.darken(-30) }, -- (*) Any special symbol
    SpecialChar    { }, --   Special character in a constant
    Tag            { fg=p.foam.darken(-20) }, --   You can use CTRL-] on this
    Delimiter      { }, --   Character that needs attention
    SpecialComment { }, --   Special things inside a comment (e.g. '\n')
    Debug          { fg = p.foam, bg = p.highlight_low }, --   Debugging statements

    Underlined     { gui = "underline" }, -- Text that stands out, HTML links
    Ignore         { }, -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
    Error          { bg=p.love.darken(50), gui="bold" }, -- Any erroneous construct
    Todo           { gui = "bold" }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX

    Statusline     { Normal },
    StatuslineNC   { fg=p.muted.darken(-20) },

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
    DiagnosticError            { fg = p.love } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticWarn             { fg = p.gold } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticInfo             { fg = p.text } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticHint             { fg = p.foam } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticOk               { fg = p.pine } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
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
    Directory { fg=p.foam },

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
    sym"@punctuation.bracket"       { fg=p.subtle.darken(-20) }, -- Delimiter

    -- sym"@constant"          { }, -- Constant
    sym"@constant.builtin"  { fg=p.rose}, -- Special
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
    sym"@function.builtin"   { fg=p.foam } , -- Special
    sym"@function.macro"     { Function }, -- Macro
    sym"@function.method"    { Function }, -- Macro
    sym"@function.call"      {  }, -- Function call
    sym"@function.macro.vue" { fg=p.iris }, -- Macro

    sym"@method"            { Function }, -- Function
    sym"@method.call"        {  }, -- Macro

    -- sym"@parameter"         { }, -- Identifier
    -- sym"@field"             { }, -- Identifier
    sym"@property"          { }, -- Identifier
    sym"@property.yaml"     { fg=p.foam }, -- Identifier
    sym"@property.jsonc"     { fg=p.foam }, -- Identifier
    sym"@constructor"       { }, -- Special
    -- sym"@conditional"       { }, -- Conditional
    sym"@repeat"            { fg=p.pine}, -- Repeat
    -- sym"@label"             { }, -- Label
    sym"@operator"          { Operator }, -- Operator

    sym"@keyword"           { fg=p.pine }, -- Keyword
    sym"@keyword.vim"       { fg=p.foam }, -- Keyword
    sym"@keyword.import"    { fg=p.foam }, -- Keyword
    sym"@keyword.exception" { Exception }, -- Keyword

    -- sym"@exception"         { }, -- Exception

    sym"@variable"                 { }, -- Identifier
    sym"@variable.builtin"         { fg=p.foam }, -- Identifier
    sym"@variable.member"          { fg=p.foam }, -- Identifier
    sym"@variable.member.python"   { Normal }, -- Identifier
    sym"@variable.member.lua"      { Normal }, -- Identifier
    sym"@variable.parameter.bash"       { Special },

    sym"@module.builtin" { },

    sym"@type"              { Type }, -- Type
    sym"@type.builtin"      { fg=p.rose }, -- Type builtin
    sym"@type.builtin.typescript" { fg=p.gold }, -- Type builtin
    -- sym"@type.definition"   { }, -- Typedef
    -- sym"@storageclass"      { }, -- StorageClass
    -- sym"@structure"         { }, -- Structure
    -- sym"@namespace"         { }, -- Identifier
    -- sym"@include"           { }, -- Include
    -- sym"@preproc"           { }, -- PreProc
    -- sym"@debug"             { }, -- Debug
    sym"@tag"               { Tag }, -- Tag
    sym"@tag.attribute"     { fg=p.foam },
    sym"@none"              { Normal }, -- Tag
    sym"@markup.heading.1"  { fg=p.love },
    sym"@markup.heading.2"  { fg=p.gold },
    sym"@markup.heading.3"  { fg=p.rose },
    sym"@markup.heading.4"  { fg=p.pine },
    sym"@markup.heading.5"  { fg=p.foam },
    sym"@markup.heading.6"  { fg=p.iris },

    -- for commit diff view:
    sym"@diff.minus" { fg=p.love },
    sym"@diff.plus"  { fg=p.pine },

    ---- Plugins ----

    -- mini indent
    MiniIndentscopeSymbol { fg = p.muted },

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
    BufferCurrent      { fg=p.foam },
    BufferCurrentSign  { fg=p.foam },
    BufferCurrentMod   { fg=p.foam },
    BufferVisible      { fg=p.pine },
    BufferVisibleSign  { fg=p.pine },
    BufferVisibleMod   { fg=p.pine },
    BufferInactive     { Comment },
    BufferInactiveSign { Comment },
    BufferInactiveMod  { Comment },

    -- fidget
    FidgetTitle  { fg=p.subtle.darken(-40) },
    FidgetTask   { Comment },

    -- nvim-cmp
    CmpItemAbbrMatch        { fg=p.subtle.darken(-40) },
    CmpItemAbbrMatchFuzzy   { CmpItemAbbrMatch },
    CmpItemKind             { fg=p.muted.darken(-50) },
    CmpItemMenu             { fg=p.overlay },
    CmpItemAbbrDeprecated   { fg=p.surface },
    CmpItemKindSupermaven   { fg=p.surface },

    -- blink-cmp
    BlinkCmpKind              { fg=p.surface.darken(-30) },
    BlinkCmpSource            { BlinkCmpKind },
    BlinkCmpLabelMatch        { fg=p.subtle.darken(10) },
    BlinkCmpMenu              { fg=p.surface.darken(-50) },

    -- lualine
    LualineA { Comment },
    LualineB { Comment },
    LualineC { Comment },
    LualineX { Comment },
    LualineY { Comment },
    LualineZ { Comment },

    -- vim startify
    StartifyBracket   { Special },
    StartifyFile      { fg=p.text },
    StartifyPath      { StartifyFile },
    StartifySlash     { StartifyFile },
    StartifySection   { fg=p.foam },
    StartifyHeader    { fg=p.pine },

    -- nvim treesitter context
    TreesitterContextSeparator  { Comment },

  }

  -- stylua: ignore end
end)

return theme

