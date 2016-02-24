#!/bin/bash

if [ $# -lt 1 ] ; then
  echo "USAGE : arg1=label"
  stop
fi

#this_script_path="`dirname $0`/` basename $0`"

myconfig_path=$( cd "$( dirname "$0" )" && pwd )
old_conf_dir="$myconfig_path/old_conf"
if [ ! -d $old_conf_dir ]; then
  mkdir $old_conf_dir
fi

function _save_config() {
  _label=$1
  _path_to_save=$2
  _files_to_save=$3
  echo "Saving $_label configuration files into $_path_to_save ..."
  if [ ! -d $_path_to_save ]; then
    mkdir $_path_to_save
  fi
  for f in $_files_to_save
  do
    cp $f $_path_to_save
  done
}

function _vim_conf() {
  vim_conf_dir="$myconfig_path/vim-conf"
  _save_config "vim" "$myconfig_path/old_conf/vim_old_conf/" "$(ls $vim_conf_dir/*)"
  for f in `ls $vim_conf_dir`
  do
    echo "Creating symlink for ${HOME}/.$f ---> \"$vim_conf_dir/$f\""
    ln -sf $vim_conf_dir/$f $HOME/.$f
  done
}

if [ $1 == "vim" ]; then
  _vim_conf $old_conf_dir
fi


#try_dir="/root/tempFiles/try_cpy_myconfig"

## Include a line that source bashrc of myconfig at the end of the native bashrc
#bash_conf_dir="$myconfig_path/bash-conf"

## Save old files :
#cp ${HOME}/.bashrc $old_conf_dir
#cp ${HOME}/.inputrc $old_conf_dir
#cp ${HOME}/.bash_aliases $old_conf_dir

#printf "\n# Myconfig bashrc file sourcing :\nsource $bash_conf_dir/bashrc" >> ${HOME}/.bashrc

## Creating symlink toward myconfig files :
#echo "Creating symlink for ${HOME}/.inputrc ---> \"$bash_conf_dir/inputrc\""
#ln -sf $bash_conf_dir/inputrc ${HOME}/.inputrc
#echo "Creating symlink for ${HOME}/.bash_aliases ---> \"$bash_conf_dir/bash_aliases\""
#ln -sf $bash_conf_dir/bash_aliases ${HOME}/.bash_aliases
