waxCraft
________

Aggregation of configuration files & knowledge.

You'll find here my configuration for:

- text editor Neovim_
- Desktop Manager Plasma_
- OS & package manager NixOs_ and nixpkgs_ (**old**)
- bash (but I should take time to investigate on ZSH)
- `cheatsheets <https://github.com/gjeusel/waxCraft/blob/dev/cheatsheets/README.rst>`_

Neovim
------
Already better than Vim to my opinion. I develop mainly in python.

Exhaustive List of plugins I use `here <https://github.com/gjeusel/waxCraft/blob/master/dotfiles/.config/nvim/init.vim#L22>`_.

Among them:

- `dein <https://github.com/Shougo/dein.vim>`_ as the plugin manager.
- `ALE <https://github.com/w0rp/ale>`_ asynchronous Lint engine.
- `deoplete <https://github.com/Shougo/deoplete.nvim>`_ asynchronous auto-completion with `deoplete-jedi <https://github.com/zchee/deoplete-jedi>`_ for python completion.
- For the beauty:
  `vim-bufferline <https://github.com/bling/vim-bufferline>`_,
  `vim-airline <https://github.com/vim-airline/vim-airline>`_,
  `vim-airline-themes <https://github.com/vim-airline/vim-airline-themes>`_,
  `vim-color-solarized <https://github.com/altercation/vim-colors-solarized>`_,
  `vim-surround <https://github.com/tpope/vim-surround>`_,
  `rainbow <https://github.com/luochen1990/rainbow>`_.
- `denite.nvim <https://github.com/Shougo/denite.nvim>`_ instead of `ctrlp <https://github.com/kien/ctrlp.vim>`_.

|OverviewNeovim|

Notes:
  French keyboard remapped to match US motions (for which it was optimized),
  see `here <https://github.com/gjeusel/waxCraft/blob/master/dotfiles/.config/nvim/init.vim#L554>`_.

Plasma
------
Best Desktop Manager Ever.
Only problem: the portability of the configuration.

|OverviewPlasma|

OS & pkg manager
----------------
I used to like NixOs at the time docker weren't out there.
However, now I'm on `Manjaro <https://manjaro.org/>`_, based on ArchLinux.
I even managed to install League Of Legend (using `wine <https://www.winehq.org/>`_)
on my `optimus <https://en.wikipedia.org/wiki/Nvidia_Optimus>`_ laptop.


Installation
------------
**Requires**:
  - python 3.6
  - Neovim 0.2+ with python packages: neovim, flake8, black, isort, autopep8

.. code:: bash

    > python wax.py --help

    # Example:
    > python wax.py bash neovim ipython


.. _NixOs: https://nixos.org/
.. _nixpkgs: https://github.com/NixOS/nixpkgs
.. _Neovim: https://neovim.io/
.. _Plasma: https://www.kde.org/plasma-desktop

.. |OverviewNeovim| image:: https://github.com/gjeusel/waxcraft/blob/master/datas/overview_neovim.png
.. |OverviewPlasma| image:: https://github.com/gjeusel/waxcraft/blob/master/datas/overview_plasma.png
