#!/bin/bash

set -eu

backup() {
  local src=$1 bak=$1.bak
  mv "$src" "$bak" &>/dev/null || return 0
  echo "'$src' => '$bak'"
}
prepare() {
  local dst=$1
  rmdir "$dst" &>/dev/null || return 0
  backup "$dst"
}
main() {
  local to=$1 from=$2
  [[ -h $from ]] || prepare "$from"
  ln -fnsv "$to" "$from"
}
(($# == 2)) && main "$@"
