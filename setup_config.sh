#!/bin/bash

if [ $# -lt 1 ] ; then
  echo "USAGE : arg1=label"
  exit
fi

waxCraft_path=$( cd "$( dirname "$0" )" && pwd )

vim_conf_dir="$waxCraft_path/vim-conf"
bash_conf_dir="$waxCraft_path/bash-conf"
kde_plasma_conf_dir="$waxCraft_path/kde-plasma-conf"
nixpkgs_conf_dir="$waxCraft_path/nix/nixpkgs"

if [ ! -d "$waxCraft_path/old_conf" ]; then
  mkdir "$waxCraft_path/old_conf"
fi

function _save_config() { #{{{
  _label=$1
  _files_of_interests=$2
  _prefix_dir=$3
  _path_to_save=$4

  echo " --- Saving $_label configuration files modified into $_path_to_save ..."

  for f in $_files_of_interests
  do
    _path_to_save_interm="$_path_to_save/$(dirname $f)"
    _file_to_save="${_prefix_dir}/$f"
    if [ -e $_file_to_save ]; then
      if [ ! -d $_path_to_save_interm ]; then
        mkdir -p $_path_to_save_interm
      fi
      cp $_file_to_save $_path_to_save_interm
    fi
  done
}
#}}}

function _create_symlink() { #{{{
  _files_of_interests=$1
  _prefix_dir=$2
  _path_to_conf_dir=$3

  for f in $_files_of_interests
  do
    echo "Creating symlink for $_prefix_dir/$f ---> \"$_path_to_conf_dir/$f\""
    _dir_to_create_symlink="$_prefix_dir/$(dirname $f)"
    if [ ! -d $_dir_to_create_symlink ]; then
      mkdir -p $_dir_to_create_symlink
    fi
    ln -sf $_path_to_conf_dir/$f $_prefix_dir/$f
  done
}
#}}}

function _copy_files() { #{{{
  _files_of_interests=$1
  _prefix_dir=$2
  _path_to_conf_dir=$3

  for f in $_files_of_interests
  do
    echo "Copying \"$_path_to_conf_dir/$f\" to $_prefix_dir/$f ..."
    _dir_to_copy="$_prefix_dir/$(dirname $f)"
    if [ ! -d $_dir_to_copy ]; then
      mkdir -p $_dir_to_copy
    fi
    cp --force $_path_to_conf_dir/$f $_prefix_dir/$f
  done
}
#}}}

function _vim_conf() { #{{{

  # Absolute path for files of interests in $vim_conf_dir :
  _waxCraft_vim_files_abs=$(find $vim_conf_dir -type f)
  # Relative path for files of interest :
  _files_of_interests=$(realpath --relative-to=$vim_conf_dir $_waxCraft_vim_files_abs)

  _prefix_dir=${HOME}

  _path_to_save="$waxCraft_path/old_conf/vim_old_conf"

  _save_config "vim" "$_files_of_interests" "$_prefix_dir" "$_path_to_save"

  _create_symlink "$_files_of_interests" "$_prefix_dir" "$vim_conf_dir"

}
#}}}

function _bash_conf() { #{{{

  # Absolute path for files of interests in $bash_conf_dir :
  _waxCraft_bash_files_abs=$(find $bash_conf_dir -type f)

  # Relative path for files of interest :
  _files_of_interests_interm=$(realpath --relative-to=$bash_conf_dir $_waxCraft_bash_files_abs)
  _files_of_interests=()
  for f in $_files_of_interests_interm
  do
    if [ "$f" != "bashrc_common.sh" ]; then
      _files_of_interests+=$f$'\n'
    fi
  done

  _prefix_dir=${HOME}

  _path_to_save="$waxCraft_path/old_conf/bash_old_conf"

  _save_config "bash" "$_files_of_interests" "$_prefix_dir" "$_path_to_save"

  _create_symlink "$_files_of_interests" "$_prefix_dir" "$bash_conf_dir"

  # Include a line that source bashrc of myconfig at the end of the native bashrc
  echo "Adding the following line to the ~/.bashrc file : \"source $bash_conf_dir/bashrc_common.sh\" ..."
  printf "\n# waxCraft bashrc_common.sh file sourcing :\nsource $bash_conf_dir/bashrc_common.sh" >> ${HOME}/.bashrc

}
#}}}

function _kde_plasma_conf() { #{{{

  # Absolute path for files in $kde_plasma_conf_dir :
  _waxCraft_kde_plasma_files_abs=$(find $kde_plasma_conf_dir -type f)
  # Relative path for files of interest :
  _files_of_interests=$(realpath --relative-to=$kde_plasma_conf_dir $_waxCraft_kde_plasma_files_abs)

  _prefix_dir="${HOME}/.config"

  _path_to_save="$waxCraft_path/old_conf/kde_plasma_old_conf"

  _save_config "kde_plasma" "$_files_of_interests" "$_prefix_dir" "$_path_to_save"

  _copy_files "$_files_of_interests" "$_prefix_dir" "$kde_plasma_conf_dir"
}
#}}}

function _nixpkgs_conf() { #{{{

  # Absolute path for files of interest in $nixpkgs_conf_dir :
  _waxCraft_nixpkgs_files_abs="$waxCraft_path/nix/nixpkgs/config.nix"
  # Relative path for files of interest :
  _files_of_interests=$(realpath --relative-to=$nixpkgs_conf_dir $_waxCraft_nixpkgs_files_abs)

  _prefix_dir="${HOME}/.nixpkgs"

  _path_to_save="$waxCraft_path/old_conf/nix/nixpkgs"

  _save_config "nixpkgs" "$_files_of_interests" "$_prefix_dir" "$_path_to_save"

  _create_symlink "$_files_of_interests" "$_prefix_dir" "$nixpkgs_conf_dir"

}
#}}}

if [ $1 == "dryrun" ]; then
  echo "dry run ended."
fi

if [ $1 == "vim" ]; then
  _vim_conf
fi

if [ $1 == "bash" ]; then
  _bash_conf
fi

if [ $1 == "kde_plasma" ]; then
  _kde_plasma_conf
fi

if [ $1 == "all" ]; then
  _vim_conf
  _bash_conf
  _kde_plasma_conf
fi

if [ $1 == "nixpkgs" ]; then
  _nixpkgs_conf
fi

