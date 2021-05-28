#!/bin/bash

set -eu

extract() {
  pkg=${pkg##*/}
  pkg=${pkg%%_*}
}
append() {
  local pkg dot log
  dot=.config/local/.install
  log=$HOME/$dot
  ./append.sh "$dot" "$log"
  for pkg; do
    [[ $pkg == *.deb ]] && extract
    grep -xq "$pkg" "$log" &>/dev/null && continue
    tee -a "$log" <<<"$pkg" >/dev/null
  done
}
show-dpkg() {
  dpkg --no-pager -l "$@" 2>/dev/null | tail -n+6
}
is-installed() {
  local pkg
  for pkg; do
    [[ $pkg == *.deb ]] && extract
    show-dpkg "$pkg" | grep -q ^ii || return
  done
}
main() {
  is-installed "$@" && return
  sudo apt-get install -qq "$@"
  append "$@"
}

main "$@"
