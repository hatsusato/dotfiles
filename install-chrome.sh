#!/bin/bash

set -eu

download() {
  mkdir -m700 -p "${file%/*}"
  wget --no-verbose --show-progress -O "$file" "$url" || exit
}
show-dpkg() {
  dpkg --no-pager -l "$@" 2>/dev/null | tail -n+6
}
is-installed() {
  show-dpkg $pkg | grep -q ^ii
}
apt-install() {
  sudo apt-get install -qq "$file"
}
append() {
  local log=$HOME/.config/local/.install
  [[ -f $log ]] || error file not found: "$log"
  grep -xq $pkg "$log" && return
  tee -a "$log" <<<"$pkg" >/dev/null
}
main() {
  local pkg deb url file
  pkg=google-chrome-stable
  deb=${pkg}_current_amd64.deb
  url=https://dl.google.com/linux/direct/$deb
  file=/usr/local/src/$USER/$deb
  [[ -f $file ]] || download
  is-installed || apt-install
  append
}

main
