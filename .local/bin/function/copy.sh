#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error

copy() {
  local -a install=(install -D -v -T)
  if [[ -x $src ]]; then
    install+=(-m 555)
  else
    install+=(-m 444)
  fi
  LANG=C $sudo "${install[@]}" "$src" "$dst"
}
main() {
  local src dst sudo=sudo
  (($# == 2)) || exit
  src=$1
  dst=$2
  [[ -f $src ]] || error source not found: "$src"
  [[ $dst == /* ]] || error not full path: "$dst"
  [[ $dst == $HOME/* ]] && sudo=
  copy
}

main "$@"
