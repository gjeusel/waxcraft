#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging
import sys
import os
import subprocess
from pathlib import Path
import shutil
import urllib
from datetime import datetime

import shutil as sh

import errno  # cf error raised bu os.makedirs
import argparse

logger = logging.getLogger(__file__)
logger.setLevel(logging.INFO)


# Global variables :
waxCraft_dir = dir(__file__).parent()
wax_dotfile_dir = waxCraft_dir / 'dotfiles'
wax_config_dir = waxCraft_dir / 'dotfiles/.config'
wax_backup_dir = waxCraft_dir / 'backup'
if not wax_backup_dir.exists():
    wax_backup_dir.mkdir()


def pcall(cmd, args, env=None):
    try:
        return subprocess.check_call([cmd] + args, env=env)
    except OSError:
        # path might be unset on windows and also debian derivatives
        raise OSError('command %r failed.' % cmd)


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

    def __init__(self):
        pass

    def _symlink_lst_files(self, lst_rpath_files, from_dir, target_dir):
        """Create symlink from from_dir to target_dir for all relative files
        in lst_rpath_files."""
        for f in lst_rpath_files:
            logger.info('Symlinking {ffrom} to {fto}'.format(
                ffrom=(from_dir / f).as_posix(),
                fto=(target_dir / f)/as_posix()))
            if (from_dir / f).exists():  # backup
                assert (from_dir / f).is_file()
                logger.info('Backing up {ffrom} in {fto}'.format(
                    ffrom=(from_dir / f).as_posix(),
                    fto=(target_dir / f)/as_posix()))
                shutil.copy((from_dir / f).as_posix(),
                            (wax_backup_dir / f).as_posix())
            from_dir.symlink_to(target_dir / f)

    def neovim(self):
        """Install neovim config files."""
        assert shutil.which('nvim') is not None  # check in PATH
        try:
            response = urllib.urlopen(
                "https://raw.githubusercontent.com/Shougo/dein.vim/master/bin/installer.sh", timeout=5)
            content = response.read()
            f = open(wax_backup_dir/'installer_dein.sh', 'w')
            f.write(content).close()
        except urllib2.URLError as e:
            raise("Could not download dein installer for neovim.")

        bundle_dir = Path.home() / '.vim/bundle'
        if not bundle_dir.exists():
            bundle_dir.mkdir()

        pcall('sh', [(wax_backup_dir / 'installer_dein.sh').as_posix(),
                     bundle_dir.as_posix(), ])

        nvim_dir = Path.home() / '.config/nvim'
        nvim_dir.symlink_to(wax_dotfile_dir / '.config/nvim',
                            target_is_directory=True)

        # nvim execute:
        pcall('nvim', ['+"call dein#install()"', '+q'])

    def bash(self):
        """Install bash config files & else"""
        str_source = ('# waxCraft bashrc_common.sh file sourcing :\n'
                      'source ' + (wax_dotfile_dir / 'bashrc_common.sh').as_posix())

        fbashrc = (Path.home() / '.bashrc')
        if not fbashrc.exists():
            fbashrc.touch()
        if str_source not in open(fbashrc.as_posix()).read():
            logger.info('Appending ~/.bashrc with {}'.format(str_source))
            open(fbashrc.as_posix(), 'a').write('\n' + str_source)

        lst_rpath_files = ['.bash_aliases', '.inputrc',
                           '.gitconfig', '.hgrc',
                           ]
        self._symlink_lst_files(lst_rpath_files, Path.home(), wax_dotfile_dir)

    def vim(self):
        """Install vim config files."""
        lst_rpath_files = ['.vimrc', '.vimrc_local', '.vimrc.bundles',
                           '.vimrc.bundles.local', '.vimrc.before',
                           '.vimrc.before.local']
        self._symlink_lst_files(lst_rpath_files, Path.home(), wax_dotfile_dir)

        quest = ('\nDo you want to install all' + bcolors.BOLD + bcolors.YELLOW,
                 ' Vim Plugin ' + bcolors.ENDC + 'now ?')
        if query_yes_no(quest):
            vundle_dir = Path.home() / '.vim/bundle/vundle'
            if not vundle_dir.exists():
                assert shutil.which('git') is not None  # check in PATH
                pcall('git clone', ['https://github.com/VundleVim/Vundle.vim.git',
                                    (Path.home() / '.vim/bundle/vundle').as_posix()])
            pcall('vim', ['+set nomore', '+BundleInstall!',
                          '+BundleClean', '+qall'])

    def plasma(self):
        lst_rpath_files = ['kglobalshortcutsrc',
                           'khotkeysrc',
                           'kwinrc',
                           'xfce4/terminal/terminalrc'
                           # 'ksmserverrc',
                           # 'kwalletrc',
                           # 'plasma-org.kde.plasma.desktop-appletsrc',
                           ]
        quest = 'Session need to restart, are your sure you want to quite?'
        if query_yes_no(query_yes_no):
            self._symlink_lst_files(lst_rpath_files, Path.home() / '.config',
                                    wax_config_dir)
        pcall("loginctl", ['terminate-user', str(os.environ['USER'])])


def setup_argparser():
    """ Define and return the command argument parser. """
    parser = argparse.ArgumentParser(description='''waxCraft config setup.''')

    parser.add_argument('cfg_list', nargs='+',
                        choices=['bash', 'vim', 'plasma', 'nixpkgs'],
                        help='''cfg to install''')
    return parser



if __name__ == "__main__":
    parser = setup_argparser()

    try:
        args = parser.parse_args()

    except argparse.ArgumentError as exc:
        raise

    wax = Wax()
    if 'bash' in args.cfg_list:
        wax.bash()
    if 'vim' in args.cfg_list:
        vim.bash()
    if 'neovim' in args.cfg_list:
        neovim.bash()
    if 'plasma' in args.cfg_list:
        plasma.bash()
