[<img src="coq.png" width="150" alt="logo"/>](https://github.com/gjeusel/waxcraft)

----
# waxCraft

This repository is about my Unix config.
- Linux distro used : [NixOs](http://nixos.org/)
- Package Manager : [nixpkgs](http://nixos.org/nixpkgs/manual/)
- Text editor : **vim** & [spf13](http://vim.spf13.com/)
- Linux shell : **bash**
- Desktop Environment : [KDE's Plasma](https://www.kde.org/plasma-desktop)

Note : **vim** and **bash** configs are kept separated from nixos files for more
flexibility, cf <br/> :
[how to include vimrc config in nixos](https://www.mpscholten.de/nixos/2016/04/11/setting-up-vim-on-nixos.html)
and [how to include bashrc config in nixos](https://nixos.org/nixos/options.html#bash).


----
## Installation :
python 2.7 script available : **wax.py**

- usage see :
```python wax.py --help```
- example :
```python setup.py vim bash```

Note:
```python setup.py vim``` Requires Curl 7+, Git 1.7+ and Vim 7.3+
