#!/bin/bash

set -eu

setup-dir() {
  sudo mkdir -p "$dir"
  sudo chown $USER:$USER "$dir"
}
download() {
  wget --no-verbose --show-progress -O "$file" "$url" || exit
}
install-chrome() {
  dpkg -l "$pkg" 2>/dev/null | grep ^ii && exit
  sudo apt-get install -qq "$file" || exit failed to install
}
append() {
  local log=$HOME/.config/local/.install
  [[ -f $log ]] || exit file not found: "$log"
  grep -xq "$pkg" "$log" &>/dev/null && return
}
main() {
  local pkg deb url dir file
  pkg=google-chrome-stable
  deb=${pkg}_current_amd64.deb
  url=https://dl.google.com/linux/direct/$deb
  dir=/usr/local/src/$USER
  file=$dir/$deb
  [[ -d $dir && -w $dir ]] || setup-dir
  [[ -f $file ]] || download
  install-chrome
  append
}

main
