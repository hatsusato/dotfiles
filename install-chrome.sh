#!/bin/bash

set -eu

download() {
  mkdir -m700 -p "${file%/*}"
  wget --no-verbose --show-progress -O "$file" "$url" || exit
}
is-installed() {
  dpkg --no-pager -l $pkg 2>/dev/null | grep -q ^ii
}
apt-install() {
  sudo apt-get install -qq "$file"
}
main() {
  local pkg deb url file
  pkg=google-chrome-stable
  deb=${pkg}_current_amd64.deb
  url=https://dl.google.com/linux/direct/$deb
  file=/usr/local/src/$USER/$deb
  [[ -f $file ]] || download
  is-installed || apt-install
}

main
