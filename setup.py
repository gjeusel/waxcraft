#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys, os, re
reload(sys)
sys.setdefaultencoding('utf8') # problem with encoding
import subprocess
import datetime

import shutil as sh

import errno # cf error raised bu os.makedirs
import argparse


##############################################
# Global variables :
script_path   = os.path.abspath(sys.argv[0])
waxCraft_path = os.path.dirname(script_path)
home          = os.environ['HOME'] + '/'
config_dir    = home + '.config/'
# config_dir    = os.environ['XDG_HOME_DIR'] + '/'

old_conf_dir = waxCraft_path + '/.old-conf/'

bash_cfg_dir   = waxCraft_path + '/bash-conf/'
vim_cfg_dir    = waxCraft_path + '/vim-conf/'
plasma_cfg_dir = waxCraft_path + '/kde-plasma-conf/'


class bash_cfg_class:
#{{{
    def __init__(self):
        print '--- Installing Bash conf ---'
        self.nml = ['.bash_aliases', '.inputrc']

        now = datetime.datetime.now()
        old_conf_bash_dir = old_conf_dir + 'bash-conf-'
        old_conf_bash_dir+= str(now.day)+'.'+str(now.month)+'.'+str(now.year)+'.'
        old_conf_bash_dir+= str(now.hour)+'.'+str(now.minute)
        old_conf_bash_dir+= '/'

        print 'Making a backup of your bash config files in ',\
              old_conf_bash_dir, ' ...'
        self.save_old_cfg(old_conf_bash_dir)

        print 'Creating symlinks ...'
        for e in self.nml:
            if os.path.exists(home + e):
                os.remove(home + e)
            os.symlink(bash_cfg_dir + e, home + e)

        print 'Adding source bashrc_common.sh to ~/.bashrc file ...'
        self.add_source_to_bashrc()

#{{{
    def save_old_cfg(self, old_conf_bash_dir):
        try:
            os.makedirs(old_conf_bash_dir)
        except OSError as exc: # Python >2.5
            if exc.errno != errno.EEXIST:
                raise

        for e in self.nml :
            if os.path.exists(home + e):
                sh.copyfile(home + e, old_conf_bash_dir + e)

    def add_source_to_bashrc(self):
        str_source = '# waxCraft bashrc_common.sh file sourcing :\n' +\
                     'source ' + bash_cfg_dir + 'bashrc_common.sh'

        if os.path.exists(home+'.bashrc'):
            if str_source not in open(home+'.bashrc').read():
                open(home+'.bashrc', 'a').write('\n'+str_source)
        else :
            open(home+'.bashrc', 'w').write(str_source)
#}}}

#}}}

class vim_cfg_class:
#{{{
    def __init__(self):
        print '--- Installing Vim conf ---'
        self.nml = ['.vimrc.local', '.vimrc.before.local',
                    '.vimrc.bundles.local']

        now = datetime.datetime.now()
        old_conf_vim_dir = old_conf_dir + 'vim-conf-'
        old_conf_vim_dir+= str(now.day)+'.'+str(now.month)+'.'+str(now.year)+'.'
        old_conf_vim_dir+= str(now.hour)+'.'+str(now.minute)
        old_conf_vim_dir+= '/'
        print 'Making a backup of your vim config files in ',\
              old_conf_vim_dir, ' ...'
        self.save_old_cfg(old_conf_vim_dir)

        spf13_path = home + '.spf13-vim-3/'
        if not os.path.exists(spf13_path):
            print 'Installing spf13 ...'
            self.install_spf13()

        print 'Creating symlinks ...'
        for e in self.nml:
            if os.path.exists(home + e):
                os.remove(home + e)
            os.symlink(vim_cfg_dir + e, home + e)
        for e in ['.vimrc', '.vimrc.before', '.vimrc.bundles']:
            if os.path.exists(home + e):
                os.remove(home + e)
            os.symlink(spf13_path + e, home + e)

#{{{
    def save_old_cfg(self, old_conf_vim_dir):
        nml_file_to_backup = self.nml + ['.vimrc', '.vimrc.before',
                                         '.vimrc.bundles']
        try:
            os.makedirs(old_conf_vim_dir)
        except OSError as exc: # Python >2.5
            if exc.errno != errno.EEXIST:
                raise

        for e in nml_file_to_backup :
            if os.path.exists(home + e):
                sh.copyfile(home + e, old_conf_vim_dir + e)

    def install_spf13(self):
        try:
            retcode = subprocess.call('curl --version &> /dev/null',
                                      shell=True)
        except OSError as exc:
            if exc.errno != 0 : # means that git isn't accessible
                print 'ERROR : curl bash cmd is required for spf13 install.'
                raise

        retcode = subprocess.call("curl http://j.mp/spf13-vim3 -L -o - | sh",
                                  shell=True)

    def download_vundle(self):
        try:
            retcode = subprocess.call("git --version &> /dev/null",
                                    shell=True)
        except OSError as exc:
            if exc.errno != 0 : # means that git isn't accessible
                raise

        recode = subprocess.call("git clone " +
            "https://github.com/VundleVim/Vundle.vim.git " +
            ".vim/bundle/Vundle.vim", shell=True)
#}}}

#}}}

class kde_plasma_class:
#{{{
    def __init__(self):
        print "--- Installing KDE's Plasma conf ---"
        self.nml = [
            'kglobalshortcutsrc',
            'ksmserverrc',
            'kwinrc',
            'khotkeysrc',
            'kwalletrc',
            'plasma-org.kde.plasma.desktop-appletsrc'
        ]

        now = datetime.datetime.now()
        old_conf_kde_plasma_dir = old_conf_dir + 'kde-plasma-conf-'
        old_conf_kde_plasma_dir+= str(now.day)+'.'+str(now.month)+'.'+str(now.year)+'.'
        old_conf_kde_plasma_dir+= str(now.hour)+'.'+str(now.minute)
        old_conf_kde_plasma_dir+= '/'
        print 'Making a backup of your kde plasma config files in ',\
              old_conf_kde_plasma_dir, ' ...'
        self.save_old_cfg(old_conf_kde_plasma_dir)

        print 'Copying new config files ...'
        for e in self.nml:
            if os.path.exists(config_dir + e):
                os.remove(config_dir + e)
            sh.copyfile(plasma_cfg_dir + e, config_dir + e)

        print 'Restarting Xorg and Plasma by disconnecting ...'
        retcode = subprocess.call("loginctl terminate-user " +
                                  str(os.environ['USER']),
                                  shell=True)

#{{{
    def save_old_cfg(self, old_conf_kde_plasma_dir):
        try:
            os.makedirs(old_conf_kde_plasma_dir)
        except OSError as exc: # Python >2.5
            if exc.errno != errno.EEXIST:
                raise

        for e in self.nml :
            if os.path.exists(config_dir + e):
                sh.copyfile(config_dir + e, old_conf_kde_plasma_dir + e)

#}}}

#}}}

def setup_argparser():
#{{{
    """ Define and return the command argument parser. """
    parser = argparse.ArgumentParser(description='''waxCraft config setup.''')

    parser.add_argument('cfg_list', nargs='+',
                        choices=['bash', 'vim', 'plasma', 'nixos'],
                        help='''cfg to install''')

    parser.add_argument('-v', '--verbose', dest='verbose', required=False,
                        default=0, type=int,
                        help='Verbose level: 0 for errors, 1 for info or 2 for debug.')

    return parser
#}}}


def main(argv=None):

    parser = setup_argparser()

    try:
        args = parser.parse_args()

    except argparse.ArgumentError as exc:
        raise

    # verbose  = args.verbose

    if 'bash' in args.cfg_list :
        bash_cfg = bash_cfg_class()

    if 'vim' in args.cfg_list :
        vim_cfg = vim_cfg_class()

    if 'plasma' in args.cfg_list :
        plasma_cfg = kde_plasma_class()


if __name__ == "__main__":
    sys.exit(main())
