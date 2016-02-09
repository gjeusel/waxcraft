#!/bin/bash

#if [ $# -lt 1 ] ; then
#  echo "USAGE : arg1=DirectoryToBeCopied"
#  exit 0
#fi

#this_script_path="`dirname $0`/` basename $0`"

myconfig_path=$( cd "$( dirname "$0" )" && pwd )
old_conf_dir="$myconfig_path/old_conf"
mkdir $old_conf_dir


#try_dir="/root/tempFiles/try_cpy_myconfig"

# Copy vim config files
vim_conf_dir="$myconfig_path/vim-conf"
for f in `ls $vim_conf_dir`
do
  echo "Creating symlink for ${HOME}/.$f ---> \"$vim_conf_dir/$f\""
  cp ${HOME}/.$f $old_conf_dir
  ln -sf $vim_conf_dir/$f $HOME/.$f
done

# Copy bash config files
bash_conf_dir="$myconfig_path/bash-conf"
for f in `ls $bash_conf_dir`
do
  echo "Creating symlink for ${HOME}/.$f ---> \"$bash_conf_dir/$f\""
  cp ${HOME}/.$f $old_conf_dir
  #ln -sf $bash_conf_dir/$f $try_dir/.$f
done
