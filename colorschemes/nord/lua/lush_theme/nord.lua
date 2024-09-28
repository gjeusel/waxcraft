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

    CurSearch      { bg=p.orange.darken(50) }, -- Highlighting a search pattern under the cursor (see 'hlsearch')
    Search         { bg=p.yellow.darken(70)}, -- Last search pattern highlighting (see 'hlsearch'). Also used for similar items that need to stand out.
    IncSearch      { CurSearch }, -- 'incsearch' highlighting; also used for the text replaced with ":s///c"
    Substitute     { bg=p.orange.darken(40)}, -- |:substitute| replacement text highlighting

    -- Git
    -- DiffAdd        { }, -- Diff mode: Added line |diff.txt|
    -- DiffChange     { }, -- Diff mode: Changed line |diff.txt|
    -- DiffDelete     { }, -- Diff mode: Deleted line |diff.txt|
    -- DiffText       { }, -- Diff mode: Changed text within a changed line |diff.txt|

    ErrorMsg       { fg=p.red }, -- Error messages on the command line
    VertSplit      { fg=p.storm0 }, -- Column separating vertically split windows
    Folded         { fg=Normal.fg.darken(25), gui="bold" }, -- Line used for closed folds
    FoldColumn     { }, -- 'foldcolumn'
    SignColumn     { }, -- Column where |signs| are displayed
    LineNr         { fg=p.night3}, -- Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
    CursorLineNr   { fg=p.storm0}, -- Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    MatchParen     { bg=p.night3 }, -- Character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|

    NormalFloat    { Normal }, -- Normal text in floating windows.
    FloatBorder    { Normal }, -- Border of floating windows.
    FloatTitle     { fg=p.storm2 }, -- Title of floating windows.

    -- Title          { }, -- Titles for output from ":set all", ":autocmd" etc.
    Visual         { bg=p.night1}, -- Visual mode selection

    -- Common vim syntax groups used for all kinds of code and markup.
    -- Commented-out groups should chain up to their preferred (*) group
    -- by default.
    --
    -- See :h group-name
    --
    -- Uncomment and edit if you want more specific syntax highlighting.

    -- Comment        { }, -- Any comment

    -- Constant       { }, -- (*) Any constant
    -- String         { }, --   A string constant: "this is a string"
    -- Character      { }, --   A character constant: 'c', '\n'
    -- Number         { }, --   A number constant: 234, 0xff
    -- Boolean        { }, --   A boolean constant: TRUE, false
    -- Float          { }, --   A floating point constant: 2.3e10

    -- Identifier     { }, -- (*) Any variable name
    -- Function       { }, --   Function name (also: methods for classes)

    -- Statement      { }, -- (*) Any statement
    -- Conditional    { }, --   if, then, else, endif, switch, etc.
    -- Repeat         { }, --   for, do, while, etc.
    -- Label          { }, --   case, default, etc.
    -- Operator       { }, --   "sizeof", "+", "*", etc.
    -- Keyword        { }, --   any other keyword
    -- Exception      { }, --   try, catch, throw

    -- PreProc        { }, -- (*) Generic Preprocessor
    -- Include        { }, --   Preprocessor #include
    -- Define         { }, --   Preprocessor #define
    -- Macro          { }, --   Same as Define
    -- PreCondit      { }, --   Preprocessor #if, #else, #endif, etc.

    -- Type           { }, -- (*) int, long, char, etc.
    -- StorageClass   { }, --   static, register, volatile, etc.
    -- Structure      { }, --   struct, union, enum, etc.
    -- Typedef        { }, --   A typedef

    -- Special        { }, -- (*) Any special symbol
    -- SpecialChar    { }, --   Special character in a constant
    -- Tag            { }, --   You can use CTRL-] on this
    -- Delimiter      { }, --   Character that needs attention
    -- SpecialComment { }, --   Special things inside a comment (e.g. '\n')
    -- Debug          { }, --   Debugging statements

    -- Underlined     { gui = "underline" }, -- Text that stands out, HTML links
    -- Ignore         { }, -- Left blank, hidden |hl-Ignore| (NOTE: May be invisible here in template)
    -- Error          { }, -- Any erroneous construct
    -- Todo           { }, -- Anything that needs extra attention; mostly the keywords TODO FIXME and XXX

    -- These groups are for the native LSP client and diagnostic system. Some
    -- other LSP clients may use these groups, or use their own. Consult your
    -- LSP client's documentation.

    -- See :h lsp-highlight, some groups may not be listed, submit a PR fix to lush-template!
    --
    -- LspReferenceText            { } , -- Used for highlighting "text" references
    -- LspReferenceRead            { } , -- Used for highlighting "read" references
    -- LspReferenceWrite           { } , -- Used for highlighting "write" references
    -- LspCodeLens                 { } , -- Used to color the virtual text of the codelens. See |nvim_buf_set_extmark()|.
    -- LspCodeLensSeparator        { } , -- Used to color the seperator between two or more code lens.
    -- LspSignatureActiveParameter { } , -- Used to highlight the active parameter in the signature help. See |vim.lsp.handlers.signature_help()|.

    -- See :h diagnostic-highlights, some groups may not be listed, submit a PR fix to lush-template!
    --
    -- DiagnosticError            { } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticWarn             { } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticInfo             { } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticHint             { } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
    -- DiagnosticOk               { } , -- Used as the base highlight group. Other Diagnostic highlights link to this by default (except Underline)
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

    -- Plugins
    -- MiniIndentscopeSymbol = {p.night3},

    -- Tree-Sitter syntax groups.
    --
    -- See :h treesitter-highlight-groups, some groups may not be listed,
    -- submit a PR fix to lush-template!
    --
    -- Tree-Sitter groups are defined with an "@" symbol, which must be
    -- specially handled to be valid lua code, we do this via the special
    -- sym function. The following are all valid ways to call the sym function,
    -- for more details see https://www.lua.org/pil/5.html
    --
    -- sym("@text.literal")
    -- sym('@text.literal')
    -- sym"@text.literal"
    -- sym'@text.literal'
    --
    -- For more information see https://github.com/rktjmp/lush.nvim/issues/109

    -- sym"@text.literal"      { }, -- Comment
    -- sym"@text.reference"    { }, -- Identifier
    -- sym"@text.title"        { }, -- Title
    -- sym"@text.uri"          { }, -- Underlined
    -- sym"@text.underline"    { }, -- Underlined
    -- sym"@text.todo"         { }, -- Todo
    sym"@comment"           { fg=p.night3.darken(-20) }, -- Comment
    sym"@punctuation"       { }, -- Delimiter
    sym"@punctuation.special"       { fg=p.night3.darken(-20) }, -- Delimiter
    sym"@punctuation.bracket"       { fg=p.night3.darken(-20) }, -- Delimiter
    -- sym"@constant"          { }, -- Constant
    sym"@constant.builtin"  { fg=p.orange}, -- Special
    -- sym"@constant.macro"    { }, -- Define
    -- sym"@define"            { }, -- Define
    -- sym"@macro"             { }, -- Macro
    sym"@string"            { fg=p.green }, -- String
    -- sym"@string.escape"     { }, -- SpecialChar
    -- sym"@string.special"    { }, -- SpecialChar
    -- sym"@character"         { }, -- Character
    -- sym"@character.special" { }, -- SpecialChar
    sym"@number"            { fg=p.purple}, -- Number
    sym"@number.float"      { fg=p.purple}, -- Float
    sym"@boolean"           { fg=p.orange}, -- Boolean
    sym"@function"          { fg=p.frost2 }, -- Function
    sym"@function.builtin"  { fg=p.frost1 }, -- Special
    sym"@function.macro"    { fg=p.frost2 }, -- Macro
    sym"@function.macro.vue"{ fg=p.frost3 }, -- Macro
    sym"@function.method"    { fg=p.frost2 }, -- Macro
    sym"@function.call"     {  }, -- Function call
    -- sym"@parameter"         { }, -- Identifier
    -- sym"@method"            { }, -- Function
    -- sym"@field"             { }, -- Identifier
    sym"@property"          { }, -- Identifier
    -- sym"@constructor"       { }, -- Special
    -- sym"@conditional"       { }, -- Conditional
    sym"@repeat"            { fg=p.red}, -- Repeat
    -- sym"@label"             { }, -- Label
    -- sym"@operator"          { }, -- Operator
    sym"@keyword"           { fg=p.red }, -- Keyword
    sym"@keyword.import"    { fg=p.frost2 }, -- Keyword
    sym"@keyword.exception" { fg=p.frost3 }, -- Keyword
    -- sym"@exception"         { }, -- Exception
    sym"@variable"          { }, -- Identifier
    sym"@variable.builtin"  { fg=p.frost2 }, -- Identifier
    sym"@variable.member"  { fg=p.frost2 }, -- Identifier
    sym"@variable.member.python"  { Normal }, -- Identifier
    sym"@type"              { fg=p.yellow}, -- Type
    sym"@type.builtin"      { fg=p.orange}, -- Type builtin
    -- sym"@type.definition"   { }, -- Typedef
    -- sym"@storageclass"      { }, -- StorageClass
    -- sym"@structure"         { }, -- Structure
    -- sym"@namespace"         { }, -- Identifier
    -- sym"@include"           { }, -- Include
    -- sym"@preproc"           { }, -- PreProc
    -- sym"@debug"             { }, -- Debug
    sym"@tag"               { fg=p.frost0.darken(-20)}, -- Tag
    sym"@none"               { Normal }, -- Tag
  }
  -- stylua: ignore end
end)

return theme
