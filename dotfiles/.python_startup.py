import sys
from pathlib import Path

import __main__

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

    history_path = confdir / "history"
    new = embed(
        history_filename=history_path,
        configure=configure,
        locals=__main__.__dict__,
        globals=__main__.__dict__,
        title='Python REPL (ptpython)',
    )
    sys.exit(new)
