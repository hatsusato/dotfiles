#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error

setup-dir() {
  [[ -d $dir && -w $dir ]] && return
  sudo mkdir -p "$dir"
  sudo chown $USER:$USER "$dir"
}
download() {
  [[ -f $file ]] && return
  wget --no-verbose --show-progress -O "$file" "$url"
}
main() {
  local pkg deb url dir file
  pkg=google-chrome-stable
  deb=${pkg}_current_amd64.deb
  url=https://dl.google.com/linux/direct/$deb
  dir=/usr/local/src/$USER
  file=$dir/$deb
  setup-dir
  download || error failed to download
  "${BASH_SOURCE%/*}"/apt-installed.sh "$pkg" && exit
  sudo apt-get -qq install "$file" || error failed to install
  "${BASH_SOURCE%/*}"/apt-register.sh "$pkg"
}

main
