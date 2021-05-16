#!/bin/bash

set -eu

copy() {
  local -i mode=555
  [[ $src == *.sh ]] && mode=444
  [[ $src -ot $dst ]] && cp -afTv "$dst" "$src".bak
  install -C -D -m $mode -v -T "$src" "$dst"
}
main() {
  local src dst
  for src; do
    [[ -f $src ]] || continue
    dst=$HOME/.local/$src
    if [[ -f $dst ]]; then
      diff -q "$src" "$dst" &>/dev/null && continue
    fi
    copy
  done
}

main "$@"
