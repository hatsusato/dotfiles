#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/.local/bin/function/error

copy() {
  local sudo=sudo
  local -a install=(install -D -v -T)
  if [[ $dst == $HOME/* ]]; then
    sudo=
    if [[ -x $src ]]; then
      install+=(-m 555)
    else
      install+=(-m 444)
    fi
  fi
  LANG=C $sudo "${install[@]}" "$src" "$dst"
}
main() {
  local src dst
  (($# == 2)) || exit
  src=$1
  dst=$2
  [[ $dst == /* ]] || error not full path: "$dst"
  [[ -f $src ]] || error source not found: "$src"
  copy
}

main "$@"
