#!/bin/bash

set -eu

main() {
  local from to
  (($# == 2)) || exit
  to=$1
  from=$2
  [[ -h $from && $(readlink -f "$from") == $to ]] && return
  rm -rf "$from"
  ln -sfv "$to" "$from"
}

main "$@"
