#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

# Global variables :
waxCraft_dir = Path(__file__).parent.absolute()
wax_dotfile_dir = waxCraft_dir / "dotfiles"
wax_config_dir = waxCraft_dir / "dotfiles/.config"
wax_backup_dir = waxCraft_dir / "backup"
if not wax_backup_dir.exists():
    wax_backup_dir.mkdir()

if not (Path.home() / ".config").exists():
    (Path.home() / ".config").mkdir()


def pcall(cmd, args, env=None):
    try:
        print("Executing bash cmd: > {}".format(cmd + " " + " ".join(args)))
        return subprocess.check_call([cmd] + args, env=env)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            "command '{}' return with error (code {}): {}".format(
                e.cmd, e.returncode, e.output))


def query_yes_no(question, default="yes"):
    """Ask a yes/no question via input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
        It must be "yes" (the default), "no" or None (meaning
        an answer is required of the user).

    The "answer" return value is True for "yes" or False for "no".
    """
    valid = {"yes": True, "y": True, "ye": True, "no": False, "n": False}
    if default is None:
        prompt = " [y/n] "
    elif default == "yes":
        prompt = " [Y/n] "
    elif default == "no":
        prompt = " [y/N] "
    else:
        raise ValueError("invalid default answer: '%s'" % default)

    while True:
        sys.stdout.write(question + prompt)
        choice = input().lower()
        if default is not None and choice == "":
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no' "
                             "(or 'y' or 'n').\n")


# Low level conveniant functions:
def _robust_copy_or_symlink(from_obj, to_obj, mode):
    """
    Args:
        from_obj (pathlib.Path): copy (or symlink) this object
        to_obj (pathlib.Path): into this one
        mode (str): 'copy' or 'symlink'
    """
    print("{} -- {} to {}".format(mode, to_obj, from_obj))

    if not from_obj.exists():
        raise ValueError("from_obj {} do not exists.".format(from_obj))

    if mode not in ["copy", "symlink"]:
        raise ValueError("mode incorrect: {}".format(mode))

    to_dir = to_obj.parent
    if not to_dir.exists():
        to_dir.mkdir(parents=True)

    if to_obj.exists():

        if to_obj.is_symlink():  # if symlink, unlink it
            to_obj.unlink()

        elif to_obj.is_file():  # if file, backup it
            backup_fpath = wax_backup_dir / to_obj.name
            print("Backing up {} in {}".format(to_obj, backup_fpath))
            shutil.copyfile(to_obj, backup_fpath)
            to_obj.unlink()

        elif to_obj.is_dir():  # if dir, backup it
            backup_dpath = wax_backup_dir / to_obj.name
            print("Backing up {} in {}".format(to_obj, backup_dpath))
            shutil.copytree(to_obj, backup_dpath)
            shutil.rmtree(to_obj)
        else:
            raise ValueError

    if mode == "symlink":
        to_obj.symlink_to(from_obj)
    elif mode == "copy":
        if from_obj.is_file():
            shutil.copyfile(from_obj, to_obj)
        elif from_obj.is_dir():
            shutil.copytree(from_obj, to_obj)


def create_symlinks_robust(relative_paths, from_dir, to_dir):
    """Create symlink from from_dir to to_dir for all relative files
    in relative_paths.

    Example:
        create_symlinks_robust(
            relative_paths=['.inputrc', '.bash_aliases'],
            from_dir=wax_dotfile_dir,
            to_dir=Path.home(),
            )

    """
    for f in relative_paths:
        from_file = from_dir / f
        to_file = to_dir / f
        _robust_copy_or_symlink(from_file, to_file, mode="symlink")


def copy_robust(relative_paths, from_dir, to_dir):
    for f in relative_paths:
        from_file = from_dir / f
        to_file = to_dir / f
        _robust_copy_or_symlink(from_file, to_file, mode="copy")


# High Level functions:
def neovim():
    """Install neovim config files."""
    assert shutil.which("nvim") is not None  # check in PATH

    nvim_init = ".config/nvim/init.lua"
    lua = ".config/nvim/lua"
    nvim_snippets = ".config/nvim/mysnippets"

    relative_paths = [
        nvim_init,
        nvim_snippets,
        lua,
    ]
    create_symlinks_robust(
        relative_paths=relative_paths,
        from_dir=wax_dotfile_dir,
        to_dir=Path.home())


def alacritty():
    """install Alacritty."""
    relative_paths = [".config/alacritty"]
    create_symlinks_robust(
        relative_paths, from_dir=wax_dotfile_dir, to_dir=Path.home())


def tmux():
    """Install tmux config files."""
    relative_paths = [".tmux.conf", ".config/tmuxp"]
    create_symlinks_robust(
        relative_paths, from_dir=wax_dotfile_dir, to_dir=Path.home())


def _common_bash_zsh():
    relative_paths = [".inputrc", ".aliases", ".zlogin"]
    create_symlinks_robust(
        relative_paths, from_dir=wax_dotfile_dir, to_dir=Path.home())


def zsh():
    """Instal zsh."""
    # source ~/waxcraft/dotfiles/zshrc_common.zsh
    str_source = (
        "# source aliases:",
        "if [ -f ~/.aliases ]; then",
        "  . ~/.aliases",
        "fi",
        "",
        "# Specific config here",
        ""
        "# waxCraft zshrc_common.zsh file sourcing :",
        "source {}".format((wax_dotfile_dir / "zshrc_common.zsh").as_posix()),
    )

    str_source = "\n".join(str_source)

    fzshrc = Path.home() / ".zshrc"
    if not fzshrc.exists():
        fzshrc.touch()
    if str_source not in open(fzshrc.as_posix()).read():
        print("Appending ~/.zshrc with {}".format(str_source))
        open(fzshrc.as_posix(), "a").write("\n" + str_source)

    _common_bash_zsh()


def plasma():
    relative_paths = [
        "kglobalshortcutsrc",
        "khotkeysrc",
        "kwinrc",
        "xfce4/terminal/terminalrc",
    ]
    quest = "Session need to restart, are your sure you want to quite?"
    if not query_yes_no(quest):  # if answered no, quit
        return
    copy_robust(
        relative_paths, from_dir=wax_config_dir, to_dir=Path.home / ".config")
    pcall("loginctl", ["terminate-user", str(os.environ["USER"])])


def python():
    """Install python config files."""
    ipythonhome = Path.home() / ".ipython"
    ptpythonhome = Path.home() / ".ptpython"
    profilehome = ipythonhome / "profile_default"
    startuppath = profilehome / "startup"
    if not any([
            ipythonhome.exists(),
            ptpythonhome.exists(),
            profilehome.exists(),
            startuppath.exists()
    ]):
        startuppath.mkdir(parents=True)

    relative_paths = [
        ".python_startup.py",
        ".pdbrc",
        ".pdbrc.py",
        ".config/flake8",
        ".ipython/profile_default/ipython_config.py",
        ".ipython/profile_default/startup/common.py",
        ".ptpython/config.py",
    ]
    create_symlinks_robust(
        relative_paths, from_dir=wax_dotfile_dir, to_dir=Path.home())


def setup_argparser():
    """ Define and return the command argument parser. """
    parser = argparse.ArgumentParser(description="""waxCraft config setup.""")

    help_str = "Config to install among ['zsh', 'vim', 'python', 'tmux', 'plasma']"
    parser.add_argument(
        "cfg_list",
        nargs="+",
        # choices=["zsh", "neovim", "vim", "plasma", "nixpkgs", "ipython"],
        help=help_str,
    )
    return parser


if __name__ == "__main__":

    parser = setup_argparser()

    try:
        args = parser.parse_args()

    except argparse.ArgumentError as exc:
        print(exc)
        raise

    optlist = args.cfg_list
    msg = "------------<     Installing    {}    >-------------"

    if "zsh" in optlist:
        print(msg.format("zsh"))
        zsh()

    if any(v in optlist for v in ["vim", "nvim", "neovim"]):
        print(msg.format("neovim"))
        neovim()

    if "plasma" in optlist:
        print(msg.format("plasma"))
        plasma()

    if any(p in optlist for p in ["python", "ipython"]):
        print(msg.format("python"))
        python()

    if "tmux" in optlist:
        print(msg.format("tmux"))
        tmux()

    if any(v in optlist for v in ["ala", "alacritty"]):
        print(msg.format("Alacritty"))
        alacritty()
