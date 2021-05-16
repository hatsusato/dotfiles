#!/bin/bash

set -eu

apt-install() {
  (($#)) || return 0
  local -i n=$(dpkg --no-pager -l "$@" 2>/dev/null | grep ^ii | wc -l)
  (($# == n)) || sudo apt install "$@"
}
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
    apt-install $(grep -m1 '^# apt:' "$src" | sed 's/.*://')
    dst=$HOME/.local/$src
    if [[ -f $dst ]]; then
      diff -q "$src" "$dst" &>/dev/null && continue
    fi
    copy
  done
}

main "$@"
