waxCraft
________

Aggregation of configuration files & knowledge.

- Text editor: Neovim_
- Terminal Multiplexer: tmux_ and tmuxp_
- Shell: zsh_ with antigen_ plugin manager

Neovim
------
Already better than Vim to my opinion. I develop mainly in python.

Main plugins:

- `vim-plug <https://github.com/junegunn/vim-plug>`_ as the plugin manager.
- `ALE <https://github.com/w0rp/ale>`_ asynchronous Lint engine.
- `deoplete <https://github.com/Shougo/deoplete.nvim>`_ asynchronous auto-completion with `deoplete-jedi <https://github.com/zchee/deoplete-jedi>`_ for python completion.
- `fzf <https://github.com/junegunn/fzf.vim>`_ fuzzy file finder (insanely usefull plugin)
- `vim-test <https://github.com/janko/vim-test>`_ for quick test launch (strategy in tmux pane)
- For the beauty:

  - `vim-bufferline <https://github.com/bling/vim-bufferline>`_
  - `vim-airline <https://github.com/vim-airline/vim-airline>`_
  - `vim-airline-themes <https://github.com/vim-airline/vim-airline-themes>`_
  - `gruvbox colorscheme <https://github.com/morhetz/gruvbox>`_
  - `vim-surround <https://github.com/tpope/vim-surround>`_
  - `rainbow <https://github.com/luochen1990/rainbow>`_

----

|OverviewDevTools|

----

Installation
------------
**Requires**:
  - python 3.6
  - Neovim 0.2+ with python packages: neovim, flake8, yapf, isort

.. code:: bash

    > python wax.py --help

    # Example:
    > python wax.py bash neovim ipython


.. _Neovim: https://neovim.io/
.. _tmux: https://github.com/tmux/tmux
.. _tmuxp: https://github.com/tmux-python/tmuxp
.. _zsh: https://ohmyz.sh/
.. _antigen: https://github.com/zsh-users/antigen


.. |OverviewDevTools| image:: https://github.com/gjeusel/waxcraft/blob/master/_static/img/overview_devtools.png
