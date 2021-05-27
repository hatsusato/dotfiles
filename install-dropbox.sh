#!/bin/bash

set -eu

show-dpkg() {
  dpkg --no-pager -l "$@" 2>/dev/null | tail -n+6
}
is-installed() {
  show-dpkg $pkg | grep -q ^ii
}
apt-install() {
  sudo apt-get install -qq $pkg
}
append() {
  local log=$HOME/.config/local/.install
  [[ -f $log ]] || error file not found: "$log"
  grep -xq $pkg "$log" && return
  tee -a "$log" <<<"$pkg" >/dev/null
}
main() {
  local pkg=nautilus-dropbox
  is-installed || apt-install
  append
  dropbox start -i
  dropbox status
  dropbox status | grep -Fqx '最新の状態'
}

main
