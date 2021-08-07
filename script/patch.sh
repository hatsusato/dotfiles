#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error

is-applied() {
  patch --dry-run -d "$dir" -f -p0 -R <"$src" >/dev/null
}
apply() {
  $sudo patch -d "$dir" -f -p0 <"$src"
}
main() {
  local src dst dir sudo=sudo
  (($# == 2)) || exit
  src=$1
  dst=$2
  dir=${dst%/*}
  [[ -f $src ]] || error file not found: "$src"
  [[ -d $dir ]] || error directory not found: "$dir"
  [[ $dst == $HOME/* ]] && sudo=
  is-applied || apply
}

main "$@"
