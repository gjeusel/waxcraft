import pdb
from pathlib import Path


def enter_shell():
    try:
        from ptpython.repl import embed, run_config
    except ImportError:
        pass
    else:
        confdir = Path.home() / ".ptpython"

        # Apply config file
        def configure(repl):
            path = confdir / "config.py"
            if path.exists():
                run_config(repl, path.as_posix())

        history_path = confdir / "pdb_history"
        new = embed(
            history_filename=history_path,
            configure=configure,
            locals=locals(),
            globals=globals(),
            title="Python REPL (ptpython)",
        )


class Config(pdb.DefaultConfig):
    highlight = True
    filename_color = pdb.Color.lightgray
    use_terminal256formatter = False
    current_line_color = 10

    def __init__(self):
        # readline.parse_and_bind('set convert-meta on')
        # readline.parse_and_bind('Meta-/: complete')

        try:
            from pygments.formatters import terminal
        except ImportError:
            pass
        else:
            self.colorscheme = terminal.TERMINAL_COLORS.copy()
            self.colorscheme.update(
                {
                    terminal.Keyword: ("darkred", "red"),
                    terminal.Number: ("darkyellow", "yellow"),
                    terminal.String: ("brown", "green"),
                    terminal.Name.Function: ("darkgreen", "blue"),
                    # terminal.Name.Namespace: ('teal', 'turquoise'),
                }
            )

    def setup(self, pdb):
        # make 'l' an alias to 'longlist'
        Pdb = pdb.__class__
        Pdb.do_l = Pdb.do_longlist
        Pdb.do_st = Pdb.do_sticky

        globals()["psh"] = enter_shell
