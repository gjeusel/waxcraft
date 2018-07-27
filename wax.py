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
wax_dotfile_dir = waxCraft_dir / 'dotfiles'
wax_config_dir = waxCraft_dir / 'dotfiles/.config'
wax_ipython_dir = waxCraft_dir / 'dotfiles/.ipython'
wax_backup_dir = waxCraft_dir / 'backup'
if not wax_backup_dir.exists():
    wax_backup_dir.mkdir()


def pcall(cmd, args, env=None):
    try:
        print('Executing bash cmd: > {}'.format(cmd + ' ' + ' '.join(args)))
        return subprocess.check_call([cmd] + args, env=env)
    except subprocess.CalledProcessError as e:
        raise RuntimeError("command '{}' return with error (code {}): {}".format(
            e.cmd, e.returncode, e.output))


def query_yes_no(question, default="yes"):
    """Ask a yes/no question via input() and return their answer.

    "question" is a string that is presented to the user.
    "default" is the presumed answer if the user just hits <Enter>.
        It must be "yes" (the default), "no" or None (meaning
        an answer is required of the user).

    The "answer" return value is True for "yes" or False for "no".
    """
    valid = {"yes": True, "y": True, "ye": True,
             "no": False, "n": False}
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
        if default is not None and choice == '':
            return valid[default]
        elif choice in valid:
            return valid[choice]
        else:
            sys.stdout.write("Please respond with 'yes' or 'no' "
                             "(or 'y' or 'n').\n")


class bcolors:
    HEADER = '\033[95m'
    WARNING = '\033[93m'

    FAIL = '\033[91m'

    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

    GREEN = '\033[38;5;002m'
    YELLOW = '\033[38;5;003m'
    BLUE = '\033[38;5;004m'

    ENDC = '\033[0m'


class Wax():
    """Entry point to setup configurations."""

    def __init__(self):
        if not (Path.home() / '.config').exists():
            (Path.home() / '.config').mkdir()
        pass

    def _symlink_lst_files(self, relative_paths, from_dir, target_dir):
        """Create symlink from from_dir to target_dir for all relative files
        in relative_paths.

        Example:
            self._symlink_lst_files(
                relative_paths=['.inputrc', '.bash_aliases'],
                from_dir=Path.home(),
                target_dir=wax_dotfile_dir)

        """
        for f in relative_paths:
            print('Symlinking {ffrom} to {fto}'.format(
                ffrom=(from_dir / f).as_posix(),
                fto=(target_dir / f).as_posix()))
            if (from_dir / f).exists():  # backup
                assert (from_dir / f).is_file()
                print('Backing up {ffrom} in {fto}'.format(
                    ffrom=(from_dir / f).as_posix(),
                    fto=(target_dir / f).as_posix()))
                if not (wax_backup_dir / f).parent.exists():
                    (wax_backup_dir / f).mkdir(parents=True)
                shutil.copy((from_dir / f).as_posix(),
                            (wax_backup_dir / f).as_posix())
                (from_dir / f).unlink()
            (from_dir / f).symlink_to((target_dir / f).as_posix())

    def _copy_lst_files(self, relative_paths, from_dir, to_dir):
        """Copy relative_paths from from_dir to target_dir, creating required directories.

        ..note:
            Be carefull with the syntax that is not equivalent to _symlink_lst_files
            regarding folders.
        """
        for f in relative_paths:
            print('Copying {ffrom} to {fto}'.format(
                ffrom=(from_dir / f).as_posix(),
                fto=(to_dir / f).as_posix()))
            if (to_dir / f).exists():  # backup
                assert (to_dir / f).is_file()
                print('Backing up {ffrom} in {fto}'.format(
                    ffrom=(from_dir / f).as_posix(),
                    fto=(to_dir / f).as_posix()))
                if not (wax_backup_dir / f).parent.exists():
                    (wax_backup_dir / f).parent.mkdir(parents=True)
                shutil.copy((from_dir / f).as_posix(),
                            (wax_backup_dir / f).as_posix())
                (from_dir / f).unlink()
            else:
                if not (to_dir / f).parent.exists():
                    (to_dir / f).parent.mkdir(parents=True)

            shutil.copy((to_dir / f).as_posix(),
                        (from_dir / f).as_posix())

    def neovim(self):
        """Install neovim config files."""
        assert shutil.which('nvim') is not None  # check in PATH
        pcall('wget', [
              "https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh",
              "-O", (wax_backup_dir / 'installer_dein.sh').as_posix(),
              ])
        bundle_dir = Path.home() / '.vim/bundle'
        if not bundle_dir.exists():
            bundle_dir.mkdir(parents=True)  # mkdir -r

        pcall('sh', [(wax_backup_dir / 'installer_dein.sh').as_posix(),
                     bundle_dir.as_posix(), ])

        nvim_dir = Path.home() / '.config/nvim'

        if nvim_dir.exists():
            if nvim_dir.is_symlink():
                nvim_dir.unlink()
            else:
                shutil.copy(nvim_dir.as_posix(), wax_backup_dir.as_posix())
                nvim_dir.rmdir()
        nvim_dir.symlink_to(wax_dotfile_dir / '.config/nvim',
                            target_is_directory=True)

    def _common_bash_zsh(self):
        relative_paths = ['.bash_aliases', '.inputrc',
                          '.gitconfig', '.hgrc',
                          '.config/flake8',
                          '.tmux.conf',
                          '.conkyrc',
                          ]
        self._symlink_lst_files(relative_paths, Path.home(), wax_dotfile_dir)

    def zsh(self):
        """Instal zsh."""
        # source ~/waxcraft/dotfiles/zshrc_common.sh
        str_source = ('# waxCraft zshrc_common.sh file sourcing :\n'
                      'source ' + (wax_dotfile_dir / 'zshrc_common.sh').as_posix())

        fzshrc = (Path.home() / '.zshrc')
        if not fzshrc.exists():
            fzshrc.touch()
        if str_source not in open(fzshrc.as_posix()).read():
            print('Appending ~/.zshrc with {}'.format(str_source))
            open(fzshrc.as_posix(), 'a').write('\n' + str_source)

        self._common_bash_zsh()

    def bash(self):
        """Install bash config files & else"""
        str_source = ('# waxCraft bashrc_common.sh file sourcing :\n'
                      'source ' + (wax_dotfile_dir / 'bashrc_common.sh').as_posix())

        fbashrc = (Path.home() / '.bashrc')
        if not fbashrc.exists():
            fbashrc.touch()
        if str_source not in open(fbashrc.as_posix()).read():
            print('Appending ~/.bashrc with {}'.format(str_source))
            open(fbashrc.as_posix(), 'a').write('\n' + str_source)

        self._common_bash_zsh()

    def plasma(self):
        relative_paths = ['kglobalshortcutsrc',
                          'khotkeysrc',
                          'kwinrc',
                          'xfce4/terminal/terminalrc'
                          # 'ksmserverrc',
                          # 'kwalletrc',
                          # 'plasma-org.kde.plasma.desktop-appletsrc',
                          ]
        quest = 'Session need to restart, are your sure you want to quite?'
        if query_yes_no(quest):
            xfce_path = Path.home() / '.config/xfce4/terminal'
            if not xfce_path.exists():
                xfce_path.mkdir(parents=True)
            self._copy_lst_files(relative_paths, Path.home() / '.config',
                                 wax_config_dir)
        pcall("loginctl", ['terminate-user', str(os.environ['USER'])])

    def python(self):
        """Install python config files."""
        ipythonhome = Path.home() / '.ipython'
        profilehome = ipythonhome / 'profile_default'
        startuppath = profilehome / 'startup'
        if not any([ipythonhome.exists(), profilehome.exists(), startuppath.exists()]):
            startuppath.mkdir(parents=True)

        relative_paths = ['profile_default/ipython_config.py',
                          'profile_default/startup/common.py']
        self._symlink_lst_files(relative_paths, ipythonhome, wax_ipython_dir)

        self._symlink_lst_files(['.pdbrc.py'], Path.home(), wax_dotfile_dir)


if __name__ == "__main__":

    def setup_argparser():
        """ Define and return the command argument parser. """
        parser = argparse.ArgumentParser(
            description='''waxCraft config setup.''')

        parser.add_argument('cfg_list', nargs='+',
                            choices=['bash', 'zsh', 'neovim', 'vim', 'plasma',
                                     'nixpkgs', 'ipython'],
                            help='''cfg to install''')
        return parser

    parser = setup_argparser()

    try:
        args = parser.parse_args()

    except argparse.ArgumentError as exc:
        raise

    wax = Wax()
    if 'bash' in args.cfg_list:
        wax.bash()
    if 'zsh' in args.cfg_list:
        wax.zsh()
    if 'neovim' in args.cfg_list:
        wax.neovim()
    if 'plasma' in args.cfg_list:
        wax.plasma()
    if 'ipython' in args.cfg_list:
        wax.ipython()
