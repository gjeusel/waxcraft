#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import subprocess
from datetime import datetims

import shutil as sh

import errno  # cf error raised bu os.makedirs
import argparse


##############################################
# Global variables :
script_path = os.path.abspath(sys.argv[0])
waxCraft_path = os.path.dirname(script_path)
home = os.environ['HOME'] + '/'
config_dir = home + '.config/'
# config_dir    = os.environ['XDG_HOME_DIR'] + '/'


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


class waxCraft:
    old_conf_dir = waxCraft_path + '/.old-conf/'

    dotfile_dir = waxCraft_path + '/dotfiles/'

    bash_cfg_dir = dotfile_dir
    vim_cfg_dir = dotfile_dir
    plasma_cfg_dir = dotfile_dir

    nixpkgs_cfg_dir = waxCraft_path + '/nix/nixpkgs/'

    def __init__(self, cfg_list):
        self.cfg_list = cfg_list

        now = datetime.now()
        now_str = now.strftime('%Y-%m-%d-%H-%M')

        dict_cfg = {
            'vim': dict(config_dir=self.vim_cfg_dir,
                        old_conf_dir=self.old_conf_dir+'vim-'+now_str,
                        nml=['.vimrc',
                             '.vimrc.before',
                             '.vimrc.bundles',
                             '.vimrc.local',
                             '.vimrc.before.local',
                             '.vimrc.bundles.local'],
                        ),

            'bash': dict(config_dir=self.bash_cfg_dir,
                         old_conf_dir=self.old_conf_dir+'bash-'+now_str,
                         nml=['.bash_aliases', '.inputrc'],
                         ),

            'plasma': dict(config_dir=self.plasma_cfg_dir,
                           old_conf_dir=self.old_conf_dir+'plasma-'+now_str,
                           nml=['kglobalshortcutsrc',
                                'ksmserverrc',
                                'kwinrc',
                                'khotkeysrc',
                                'kwalletrc',
                                'plasma-org.kde.plasma.desktop-appletsrc',
                                'xfce4/terminal/terminalrc'
                                ]
                           ),
        }

        self.dict_cfg = dict_cfg

    def save_old_cfg(self, cfg):
        print('Backup in ' + self.dict_cfg[cfg]['old_conf_dir'] + ' ...')
        try:
            os.makedirs(self.dict_cfg[cfg]['old_conf_dir'])
        except OSError as exc:  # Python >2.5
            if exc.errno != errno.EEXIST:
                raise

        for e in self.dict_cfg[cfg]['nml']:
            if os.path.exists(home + e):
                sh.copyfile(home + e, self.dict_cfg[cfg]['old_conf_dir'] + e)

    def create_symlinks(self, cfg):
        print('Creating symlinks ...')
        for e in self.dict_cfg[cfg]['nml']:
            try:
                os.remove(home + e)
            except OSError as exc:
                if exc.errno != 2:  # means that no such file or directory
                    raise
            os.symlink(self.dict_cfg[cfg]['config_dir'] + e, home + e)

    def copy_files(self, cfg):
        print('Copying files ...')
        for e in self.dict_cfg[cfg]['nml']:
            src = self.dict_cfg[cfg]['config_dir'] + e
            dest = home + '.config/' + e

            # Remove existing file
            try:
                os.remove(dest)
            except OSError as exc:
                if exc.errno != 2:  # means that no such file or directory
                    raise

            # Create directories if not already existing
            alr_exist = bool(os.path.exists(os.path.dirname(dest)))
            if (not alr_exist):
                try:
                    os.makedirs(os.path.dirname(dest))
                except OSError as exc:  # Guard against race condition
                    if exc.errno != errno.EEXIST:
                        raise

            # copy file :
            sh.copy(src, dest)

    def install_vim(self):
        print('--- Installing Vim conf ---')
        self.save_old_cfg('vim')

        self.create_symlinks('vim')

        def install_vundle():
            try:
                retcode = subprocess.call("git --version &> /dev/null",
                                          shell=True)
            except OSError as exc:
                if exc.errno != 0:  # means that git isn't accessible
                    raise

            recode = subprocess.call(
                "git clone " +
                "https://github.com/VundleVim/Vundle.vim.git " +
                ".vim/bundle/vundle",
                shell=True)

        if not os.path.exists(home+'.vim/bundle/vundle'):
            install_vundle()

        quest = '\nDo you want to install all' + bcolors.BOLD + bcolors.YELLOW\
            + ' Vim Plugin ' + bcolors.ENDC + 'now ?'
        if query_yes_no(quest):
            cmd = "vim -u "+self.vim_cfg_dir+".vimrc.bundles.default "\
                  + "+set nomore "\
                  + "+BundleInstall! "\
                  + "+BundleClean "\
                  + "+qall"
            retcode = subprocess.call(cmd, shell=True)

    def install_bash(self):
        print('--- Installing Bash conf ---')
        self.save_old_cfg('bash')
        self.create_symlinks('bash')

        # Adding line in ~/.bashrc to source baschrc_common.sh
        str_source = '# waxCraft bashrc_common.sh file sourcing :\n' +\
                     'source ' + self.dict_cfg['bash']['config_dir'] + 'bashrc_common.sh'

        if os.path.exists(home+'.bashrc'):
            if str_source not in open(home+'.bashrc').read():
                open(home+'.bashrc', 'a').write('\n'+str_source)
        else:
            open(home+'.bashrc', 'w').write(str_source)

    def install_plasma(self):
        print('--- Installing Plasma conf ---')
        self.save_old_cfg('plasma')
        self.copy_files('plasma')

        quest = 'Session need to restart, are your sure you want to quite'
        if query_yes_no(query_yes_no):
            retcode = subprocess.call("loginctl terminate-user " +
                                      str(os.environ['USER']),
                                      shell=True)

    def install(self):
        if 'vim' in self.cfg_list:
            self.install_vim()

        if 'bash' in self.cfg_list:
            self.install_bash()

        if 'plasma' in self.cfg_list:
            self.install_plasma()


class nixpkgs_class:
    nixpkgs_cfg_dir = waxCraft_path + '/nix/nixpkgs/'

    def __init__(self):
        print("--- Installing nixpkgs conf ---")
        self.nml = ['.nixpkgs/config.nix']
        print('Creating symlinks ...')
        if not os.path.isdir(home+'.nixpkgs'):
            os.makedirs(home+'.nixpkgs')

        for e in self.nml:
            os.symlink(self.nixpkgs_cfg_dir + 'custom-packages.nix', home + e)


def setup_argparser():
    """ Define and return the command argument parser. """
    parser = argparse.ArgumentParser(description='''waxCraft config setup.''')

    parser.add_argument('cfg_list', nargs='+', choices=['bash', 'vim',
                                                        'plasma', 'nixpkgs'],
                        help='''cfg to install''')

    parser.add_argument(
        '-v',
        '--verbose',
        dest='verbose',
        required=False,
        default=0,
        type=int,
        help='Verbose level: 0 for errors, 1 for info or 2 for debug.')

    return parser


def main(argv=None):

    parser = setup_argparser()

    try:
        args = parser.parse_args()

    except argparse.ArgumentError as exc:
        raise

    wax = waxCraft(args.cfg_list)
    wax.install()

    if 'nixpkgs' in args.cfg_list:
        nixpkgs_cfg = nixpkgs_class()


if __name__ == "__main__":
    sys.exit(main())
