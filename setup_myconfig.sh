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

# Include a line that source bashrc of myconfig at the end of the native bashrc
bash_conf_dir="$myconfig_path/bash-conf"

# Save old files :
cp ${HOME}/.bashrc $old_conf_dir
cp ${HOME}/.inputrc $old_conf_dir
cp ${HOME}/.bash_aliases $old_conf_dir

printf "\n# Myconfig bashrc file sourcing :\nsource $bash_conf_dir/bashrc" >> ${HOME}/.bashrc

# Creating symlink toward myconfig files :
echo "Creating symlink for ${HOME}/.inputrc ---> \"$bash_conf_dir/inputrc\""
ln -sf $bash_conf_dir/inputrc ${HOME}/.inputrc
echo "Creating symlink for ${HOME}/.bash_aliases ---> \"$bash_conf_dir/bash_aliases\""
ln -sf $bash_conf_dir/bash_aliases ${HOME}/.bash_aliases
