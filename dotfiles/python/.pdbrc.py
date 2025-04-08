import pdb

try:
    from pygments import token
    from pygments.formatters import terminal
except ImportError:
    HAS_PYGMENTS = False
else:
    HAS_PYGMENTS = True


class Config(pdb.DefaultConfig):
    highlight = True
    filename_color = pdb.Color.blue
    use_terminal256formatter = False
    current_line_color = 10
    prompt = "pdb> "

    def __init__(self):
        # readline.parse_and_bind("set convert-meta on")
        # readline.parse_and_bind("Meta-/: complete")
        # bindkey '^[[1;5D' backward-word
        # bindkey '^[[1;5C' forward-word

        if HAS_PYGMENTS:

            self.colorscheme = terminal.TERMINAL_COLORS.copy()
            self.colorscheme.update(
                {
                    terminal.Keyword: ("red", "red"),
                    terminal.Keyword.Type: ("yellow", "yellow"),
                    #
                    terminal.Number: ("magenta", "magenta"),
                    #
                    terminal.Name.Namespace: None,
                    terminal.Name.Decorator: ("green", "green"),
                    terminal.Name.Class: ("yellow", "yellow"),
                    terminal.Name.Function: ("cyan", "cyan"),
                    terminal.Name.Builtin: ("brightblue", "brightblue"),
                    #
                    token.String: ("green", "green"),
                    token.String.Doc: ("gray", "brightblack"),
                }
            )

    def setup(self, pdb):
        # make 'l' an alias to 'longlist'
        Pdb = pdb.__class__
        Pdb.do_l = Pdb.do_longlist
        Pdb.do_st = Pdb.do_sticky
