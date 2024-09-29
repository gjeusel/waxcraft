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
  gray = hsl("#8A8A8A"),
  --
  light0 = hsl("#FFFFAF"),
  light1 = hsl("#FFD8AF"),
  light2 = hsl("#BCBCBC"),
  light3 = hsl("#A8A8A8"),
  light4 = hsl("#8A8A8A"),
  --
  -- aurora
  red = hsl("#D75F5F"),
  green = hsl("#AFAF00"),
  yellow = hsl("#FFAF01"),
  blue = hsl("#87AFAF"),
  purple = hsl("#D787AF"),
  aqua = hsl("#87AF87"),
  orange = hsl("#FF8700"),
}

local theme = lush(function(injected_functions)
  local sym = injected_functions.sym

  -- stylua: ignore start
  return {
    Normal         { fg=p.light1.lighten(30) }, -- Normal text

    ColorColumn    { bg=p.dark1 }, -- Columns set with 'colorcolumn'
    Cursor         { bg=p.dark4 }, -- Character under the cursor
    CursorLine     { bg=p.dark2 }, -- Screen-line at the cursor, when 'cursorline' is set. Low-priority if foreground (ctermfg OR guifg) is not set.

    CurSearch      { bg=p.orange.darken(30) }, -- Highlighting a search pattern under the cursor (see 'hlsearch')
    Search         { bg=p.yellow.darken(40)}, -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
    IncSearch      { CurSearch }, -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
    Substitute     { bg=p.orange.darken(40)}, -- |:substitute| replacement text highlighting

    -- Git
    DiffAdd        { fg=p.green }, -- Diff mode: Added line |diff.txt|
    DiffChange     { fg=p.aqua }, -- Diff mode: Changed line |diff.txt|
    DiffDelete     { fg=p.red }, -- Diff mode: Deleted line |diff.txt|
    DiffText       { fg=p.blue }, -- Diff mode: Changed text within a changed line |diff.txt|

    ErrorMsg       { fg=p.red }, -- Error messages on the command line
    VertSplit      { fg=p.light3 }, -- Column separating vertically split windows
    Folded         { fg=p.light3, gui="bold" }, -- Line used for closed folds
    FoldColumn     { }, -- 'foldcolumn'
    SignColumn     { }, -- Column where |signs| are displayed
    CursorLineNr   { fg=p.light2 }, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    MatchParen     { bg=p.dark2 }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|

    FloatTitle     { fg=p.aqua, gui="bold" }, -- Title of floating windows.
    NormalFloat    { Normal }, -- Normal text in floating windows.
    FloatBorder    { fg=p.aqua }, -- Border of floating windows.

    Title          { gui="bold" }, -- Titles for output from ":set all", ":autocmd" etc.
    Visual         { bg=p.dark1 }, -- Visual mode selection

    -- Common vim syntax groups used for all kinds of code and markup.
    -- Commented-out groups should chain up to their preferred (*) group
    -- by default. (See :h group-name)

    Comment        { fg=p.gray }, -- Any comment
    String         { fg=p.green }, --   A string constant: "this is a string"
    Boolean        { fg=p.orange }, --   A boolean constant: TRUE, false
    Number         { fg=p.purple }, --   A number constant: 234, 0xff
    Float          { Number }, --   A floating point constant: 2.3e10

    Identifier     { }, -- (*) Any variable name
    Statement      { }, -- (*) Any statement
    Operator       { }, --   "sizeof", "+", "*", etc.

    Function       { fg=p.aqua }, --   Function name (also: methods for classes)

    Keyword        { fg=p.red }, --   any other keyword
    Conditional    { Keyword }, --   if, then, else, endif, switch, etc.
    Repeat         { Keyword }, --   for, do, while, etc.
    Label          { Keyword }, --   case, default, etc.
    Exception      { Keyword }, --   try, catch, throw

    -- PreProc        { }, -- (*) Generic Preprocessor
    -- Include        { }, --   Preprocessor #include
    -- Define         { }, --   Preprocessor #define
    -- Macro          { }, --   Same as Define
    -- PreCondit      { }, --   Preprocessor #if, #else, #endif, etc.

    Type           { fg=p.yellow }, -- (*) int, long, char, etc.
    StorageClass   { fg=p.yellow }, --   static, register, volatile, etc.
    Structure      { fg=p.yellow }, --   struct, union, enum, etc.
    Typedef        { fg=p.yellow }, --   A typedef

    Special        { fg=p.dark2.darken(-30) }, -- (*) Any special symbol
    SpecialChar    { }, --   Special character in a constant
    Tag            { fg=p.red }, --   You can use CTRL-] on this
    Delimiter      { fg=p.light4 }, --   Character that needs attention
    SpecialComment { }, --   Special things inside a comment (e.g. '\n')
    Debug          { fg = p.light2, bg = p.dark1 }, --   Debugging statements

    Underlined     { gui = "underline" }, -- Text that stands out, HTML links
    Ignore         { }, -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
    Error          { bg=p.red.darken(50), gui="bold" }, -- Any erroneous construct
    Todo           { gui = "bold" }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX

    Statusline     { fg=p.light3 },
    StatuslineNC   { fg=p.light4 },

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
    DiagnosticInfo             { fg = p.light3 } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    DiagnosticHint             { fg = p.blue } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
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

    -- Tree-Sitter syntax groups. (See :h treesitter-highlight-groups)

    -- sym"@text.literal"      { }, -- Comment
    -- sym"@text.reference"    { }, -- Identifier
    -- sym"@text.title"        { }, -- Title
    -- sym"@text.uri"          { }, -- Underlined
    -- sym"@text.underline"    { }, -- Underlined
    -- sym"@text.todo"         { }, -- Todo

    sym"@comment"           { Comment }, -- Comment

    sym"@punctuation"                   { fg=p.light3 }, -- Delimiter
    sym"@punctuation.special"           { sym"@punctuation" }, -- Delimiter
    sym"@punctuation.bracket"           { sym"@punctuation" }, -- Delimiter
    sym"@punctuation.delimiter"         { sym"@punctuation" }, -- Delimiter
    sym"@punctuation.special.python"    { fg=p.orange }, -- Delimiter
    sym"@punctuation.bracket.python"    { Normal }, -- Delimiter
    sym"@punctuation.delimiter.python"  { Normal }, -- Delimiter

    sym"@constant"          { Normal }, -- Constant
    sym"@constant.builtin"  { fg=p.orange}, -- Special
    sym"@constant.macro"    { }, -- Define

    -- -- sym"@define"            { }, -- Define
    -- -- sym"@macro"             { }, -- Macro

    sym"@string"            { String }, -- String
    -- sym"@string.escape"     { }, -- SpecialChar
    -- sym"@string.special"    { }, -- SpecialChar

    -- sym"@character"         { }, -- Character
    -- sym"@character.special" { }, -- SpecialChar

    sym"@number"            { Number }, -- Number
    sym"@number.float"      { Number }, -- Float

    sym"@boolean"            { Boolean }, -- Boolean
    sym"@boolean.typescript" { fg=p.purple }, -- Boolean
    sym"@boolean.lua"        { fg=p.purple }, -- Boolean

    sym"@function"                    { Function }, -- Function
    sym"@function.builtin"            { fg=p.yellow }, -- Special
    sym"@function.macro"              { fg=p.green }, -- Macro
    sym"@function.method"             { Function }, -- Macro
    sym"@function.method.javascript"  { fg=p.blue }, -- Macro
    sym"@function.method.typescript"  { fg=p.blue }, -- Macro
    sym"@function.method.jsx"         { fg=p.blue }, -- Macro
    sym"@function.method.tsx"         { fg=p.blue }, -- Macro
    sym"@function.method.vue"         { fg=p.blue }, -- Macro
    sym"@function.call"               { Normal }, -- Function call
    sym"@function.macro.vue"          { fg=p.blue }, -- Macro

    sym"@function.lua"           { fg=p.blue, gui="bold" }, -- Function
    sym"@function.call.lua"      { Normal }, -- Function
    sym"@function.builtin.lua"   { fg=p.yellow }, -- Function

    sym"@function.call.markdown" { fg=p.green }, -- Function

    sym"@definition.function.python"     { Function }, -- Macro
    sym"@definition.function.javascript" { fg=p.blue }, -- Macro
    sym"@definition.function.typescript" { fg=p.blue }, -- Macro
    sym"@definition.function.jsx"        { fg=p.blue }, -- Macro
    sym"@definition.function.tsx"        { fg=p.blue }, -- Macro
    sym"@definition.function.vue"        { fg=p.blue }, -- Macro

    sym"@method"             { Function }, -- Function
    sym"@method.call"        { Normal  }, -- Macro

    -- sym"@parameter"         { }, -- Identifier

    sym"@field"        { Normal }, -- Identifier
    sym"@field.yaml"   { fg=p.blue }, -- Identifier
    sym"@field.vue"    { fg=p.blue }, -- Identifier

    sym"@property"          { Normal }, -- Identifier
    sym"@property.jsonc"    { fg=p.blue }, -- Identifier
    sym"@property.json"    { fg=p.blue }, -- Identifier
    sym"@constructor"       { Normal }, -- Special
    -- sym"@conditional"       { }, -- Conditional
    sym"@repeat"            { fg=p.red}, -- Repeat
    -- sym"@label"             { }, -- Label
    sym"@operator"          { Operator }, -- Operator
    sym"@operator.python"   { fg=p.light1 }, -- Operator

    sym"@keyword"           { fg=p.red }, -- Keyword
    sym"@keyword.import"    { fg=p.blue }, -- Keyword
    sym"@keyword.exception" { Exception }, -- Keyword
    sym"@keyword.operator"  { fg=p.red }, -- Keyword

    -- sym"@exception"         { }, -- Exception

    sym"@variable"                    { Normal }, -- Identifier
    sym"@variable.builtin"            { fg=p.blue }, -- Identifier
    sym"@variable.builtin.typescript" { fg=p.orange }, -- Identifier
    sym"@variable.member"             { Normal }, -- Identifier
    sym"@variable.member.typescript"  { fg=p.aqua }, -- Identifier
    sym"@variable.member.vue"         { fg=p.blue }, -- Identifier
    sym"@variable.parameter"          { Normal },
    sym"@variable.parameter.vue"      { fg=p.orange },
    sym"@variable.parameter.bash"     { Special },

    sym"@type"                    { Type }, -- Type
    sym"@type.builtin"            { fg=p.aqua }, -- Type builtin
    sym"@type.builtin.javascript" { fg=p.yellow }, -- Type builtin
    sym"@type.builtin.typescript" { fg=p.yellow }, -- Type builtin
    sym"@type.builtin.jsx"        { fg=p.yellow }, -- Type builtin
    sym"@type.builtin.tsx"        { fg=p.yellow }, -- Type builtin
    sym"@type.builtin.vue"        { fg=p.yellow }, -- Type builtin
    -- sym"@type.definition"   { }, -- Typedef

    -- sym"@storageclass"      { }, -- StorageClass
    -- sym"@structure"         { }, -- Structure
    -- sym"@namespace"         { }, -- Identifier
    -- sym"@include"           { }, -- Include
    -- sym"@preproc"           { }, -- PreProc
    -- sym"@debug"             { }, -- Debug

    sym"@tag"               { Tag }, -- Tag
    sym"@tag.attribute"     { fg=p.aqua },
    sym"@tag.delimiter"     { Delimiter },

    sym"@none"              { Normal }, -- Tag
    sym"@none.python"              { fg=p.light1 }, -- Tag
    sym"@markup.heading.1"  { fg=p.light0 },
    sym"@markup.heading.2"  { fg=p.light1 },
    sym"@markup.heading.3"  { fg=p.light2 },
    sym"@markup.heading.4"  { fg=p.light4 },
    sym"@markup.heading.5"  { fg=p.light4 },
    sym"@markup.heading.6"  { fg=p.light4 },

    ---- Plugins ----

    -- mini indent
    MiniIndentscopeSymbol { fg = p.dark2 },

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
    BufferCurrent      { Normal },
    BufferCurrentSign  { fg=p.aqua },
    BufferCurrentMod   { BufferCurrent },
    BufferVisible      { fg=p.light3 },
    BufferVisibleSign  { fg=p.blue },
    BufferVisibleMod   { BufferVisible },
    BufferInactive     { fg=p.light4 },
    BufferInactiveSign { BufferInactive },
    BufferInactiveMod  { BufferInactive },

    -- fidget
    FidgetTitle  { fg=p.light3 },
    FidgetTask   { fg=p.light4 },

    -- nvim-cmp
    CmpItemAbbrMatch        { fg=p.light3 },
    CmpItemAbbrMatchFuzzy   { CmpItemAbbrMatch },
    CmpItemKind             { fg=p.light4 },
    CmpItemMenu             { fg=p.dark4 },
    CmpItemAbbrDeprecated   { fg=p.dark2 },

    -- lualine
    LualineA { Comment },
    LualineB { Comment },
    LualineC { Comment },
    LualineX { Comment },
    LualineY { Comment },
    LualineZ { Comment },

    -- gitgutter / gitsigns
    GitSignsAdd { DiffAdd },
    GitSignsChange { DiffChange },
    GitSignsDelete { DiffDelete },

    -- vim startify
    StartifyBracket { fg=p.light3 },
    StartifyFile    { fg=p.light1 },
    StartifyNumber  { fg=p.blue },
    StartifyPath    { fg=p.gray },
    StartifySlash    { fg=p.gray },
    StartifySection    { fg=p.yellow },
    StartifySpecial    { fg=p.dark2 },
    StartifyHeader    { fg=p.orange },
    StartifyFooter    { fg=p.dark2 },
  }

  -- stylua: ignore end
end)

return theme
