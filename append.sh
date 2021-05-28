#!/bin/bash

set -eu

join() {
  tr '\n' '\0' <"$1"
}
contains() {
  [[ -f $dst ]] || return
  grep -Fqz -f <(join "$src") <(join "$dst")
}
main() {
  (($# == 2)) || return
  local src=$1 dst=$2
  [[ -f $src ]] || error file not found: "$src"
  contains && return
  tee -a "$dst" <"$src" >/dev/null
}

main "$@"
