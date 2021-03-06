#!/bin/bash

# Copyright (C) 2010 Stéphane Robert Richard.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the project nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE PROJECT AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE PROJECT OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.


###
## readonly vars

  pushd $(dirname $(readlink -f "$BASH_SOURCE")) > /dev/null
  readonly script_dir="$PWD"
  popd > /dev/null

  readonly script_name=$(basename $0)
  build_id="$(date +'%Y-%m-%d-%H-%M-%S')"

##
###


###
## Configuration: Here you have the oportunity, expected that you know what you're doing, to tweak the configuration to suit your needs. 

  # Where do you want your out of disto softwares to be installed? 
  # If you want to put them in /opt or /usr/local, 
  # you may need to change this script in order to call sudo before make install
  # or to run this script as root, neither of the two ideas being very bright...
  opt_dir="$HOME/opt"

  # Where should we retrieve and look for git repositories?
  src_dir="$HOME/src/git"

  # Where do you want your razor sharp gimp to be installed?
  gimp_install_dir="$opt_dir/gimp/build_$build_id"

  # Sources directories for gimp, babl and gegl
  gimp_src_dir="$src_dir/gimp"
  babl_src_dir="$src_dir/babl"
  gegl_src_dir="$src_dir/gegl"
  pixman_src_dir="$src_dir/pixman"  
  cairo_src_dir="$src_dir/cairo"
  glib_src_dir="$src_dir/glib"
  gexiv2_src_dir="$src_dir/gexiv2"

  # How many processor to use for compilation. The default below will use them all.
  processors="$(cat /proc/cpuinfo | grep processor | wc -l)"
  
  # Exports needed outside of this script's scope, 
  # you probably don't need to tweak things here.
  export PATH="$gimp_install_dir/bin:$PATH"
  export PKG_CONFIG_PATH="$gimp_install_dir/lib/pkgconfig:$PKG_CONFIG_PATH"
  export LD_LIBRARY_PATH="$gimp_install_dir/lib:$LD_LIBRARY_PATH"

  # The package management command to run
  pkg_cmd="sudo apt-get install"
  
  # The packages to install
  # These are specific to Ubuntu 11.x
  # If you're running another distro, you'll need to pich the list by yourself
  # Read the ${gimp_src_dir}/INSTALL, 
  # and do trial'n errors by running this script until you've resolved all dependencies
  # Ubuntu 12.04 add the following package: zlib, libbzip2 and liblzma
  deps="fontconfig gtk-doc-tools intltool libcairo2 libdbus-glib-1-2 libexif-dev libfontconfig1 libfreetype6 libgdk-pixbuf2.0-0 libgtk-3-0 libjasper-dev libjpeg-dev liblcms1-dev liblcms-dev libmng-dev libopenexr-dev libpango1.0-0 libpng-dev libpoppler-dev librsvg2-common librsvg2-dev libtiff4-dev libtiff-tools libtool libwebkit-dev libwmf-dev pkg-config python-dev python-gtk2-dev ruby libghc-zlib-dev libbz2-dev liblzma-dev libexiv2-dev"

##
###



###
## FUNCTIONS

  ###
  ## HELPERS

    log_entry() {
      echo
      printf -vch  "%80s" ""
      printf "%s\n" "${ch// /$1}"
      echo "$1$1  $2"
      echo
    }

    log_task(){
      log_entry '#' "$@"
    }

    log_section() {
      log_entry '=' "$@"
    }

    log_message() {
      log_entry '-' "$@"
    }

    ask_user() {
      echo -n "--  $@: "
    }

    exit_with(){
      echo "ERROR (exit code $?): $1"
      exit $?
    }

  ##
  ###


  ###
  ## TASKS

    mkdirs(){
      log_section "Creating directories"
      local dirs=( "$opt_dir" "$src_dir" "$gimp_install_dir" )
      for dir in ${dirs[@]}; do
        mkdir -vp $dir || exit_with "An error occured while trying to create $dir"
      done
    }

    install_apt_deps(){
      log_section "Installing required apt dependencies"
      ${pkg_cmd} $deps || exit_with "package manager fail while trying to install dependencies $deps"
    }

    update_git_repository(){
      local repo_name="$(basename $1)"
      ##local repo="git://git.gnome.org/$repo_name"
      ##--------------------------
      local repo=""

      if [ $repo_name = "cairo" ]; then
        repo="git://anongit.freedesktop.org/git/$repo_name"
        ##echo $repo
      elif [ $repo_name = "pixman" ]; then   
		repo="git://anongit.freedesktop.org/git/pixman.git"
      elif [ $repo_name = "gexiv2" ]; then   
		repo="git://git.yorba.org/gexiv2"
      elif [ $repo_name = "glib" ]; then   
		repo="git://git.gnome.org/glib"
	  else
		repo="git://git.gnome.org/$repo_name"
	  fi	
      ##--------------------------
      log_section "Checking state of git repository $repo"
      if [ -d "$1" ]; then
        cd "$1"
        if git status; then
          log_message "Local repository $repo_name already exist, updating from remote master"
          git pull --rebase || exit_with "git failed while trying to pull from master repository $repo"
        else
          log_message "$1 is not a git repository, cleaning"
          ask_user "$script_name is going to remove the directory $1 and all it's content. Proceed? [Y/n]"
          read input
          [ "$(echo ${input:-Y} | tr [a-z] [A-Z])" == 'Y' ] && rm -rfv "$1"
          update_git_repository
        fi
      else
        ##log_message "Cloning git://git.gnome.org/$repo_name in $1"
        log_message "Cloning $repo in $1"
        cd "$(dirname $1)"
        ##git clone "git://git.gnome.org/$repo_name" || exit_with "git failed while trying to clone repository $repo"
        git clone "$repo" || exit_with "git failed while trying to clone repository $repo"
      fi
    }

    update_repositories(){
      log_section "Updating repositories"
      ##for repo in babl gegl gimp; do
      for repo in babl gegl pixman gexiv2 cairo glib gimp; do
          update_git_repository "$src_dir/$repo"
      done      
    }

    get_commit_id(){
      cd "$gimp_src_dir"
      echo "git describe" | tr 'A-Z' 'a-z' | sed 's/[^a-zA-Z0-9_-]/-/g'
    }

    build(){
      local name="$(basename $1)"
      log_section "Building $name"
      cd "$1"
      if [ $name = "gexiv2" ]; then
        ./configure --prefix="$gimp_install_dir" || exit_with "while configuring ${name}"
        make clean || exit_with "while executing 'make clean' for $name"
        make -j $processors || exit_with "while executing 'make' for $name"
        make install || exit_with "while executing 'make install' for $name"
	  else
        ./autogen.sh --prefix="$gimp_install_dir" || exit_with "while executing ${name}'s autogen.sh"
        make clean || exit_with "while executing 'make clean' for $name"
        make -j $processors || exit_with "while executing 'make' for $name"
        make install || exit_with "while executing 'make install' for $name"
	  fi
    }

    build_all(){
      build "$babl_src_dir"
      build "$glib_src_dir"
      build "$gegl_src_dir"
      build "$pixman_src_dir"
      build "$gexiv2_src_dir"
      build "$cairo_src_dir"
      build "$gimp_src_dir"      
    }

    test_build(){
      "$gimp_install_dir/bin/gimp-2.9" || exit_with "while trying to launch your rounded edge gimp :("
    }

  ##
  ###

##
###


###
## Main
 
  log_task "Install distribution dependencies"
  install_apt_deps

  log_task "Retrieving or updating sources"
  mkdirs
  update_repositories

  log_task "Building from sources"
  build_all
  
  log_task "Launching your cutting edge gimp, behave yourself..."
  test_build

##
###
