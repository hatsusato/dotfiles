#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error.sh

join() {
  tr '\n' '\0' <"$1"
}
contains() {
  [[ -f $dst ]] || return
  grep -Fqz -f <(join "$src") <(join "$dst")
}
main() {
  local src dst sudo=sudo
  (($# == 2)) || exit
  src=$1
  dst=$2
  [[ -f $src ]] || error file not found: "$src"
  [[ -d ${dst%/*} ]] || error directory not found: "${dst%/*}"
  contains && exit
  [[ $dst == $HOME/* ]] && sudo=
  $sudo tee -a "$dst" <"$src" >/dev/null
}

main "$@"
