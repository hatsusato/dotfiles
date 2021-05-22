#!/bin/bash

set -eu

readonly TOP_DIR=${BASH_SOURCE%/*}

apt-comment() {
  grep '^#' "$src" | grep -m1 'apt:' | cut -d: -f2
}
apt-install() {
  local -a apt=("$TOP_DIR"/.local/bin/apt-wrapper install)
  apt+=($(apt-comment))
  export APT_OPTION=--yes
  "${apt[@]}"
}
backup() {
  local patch=$TOP_DIR/${src##*/}.patch
  local -a diff=(diff -u)
  diff+=(--label "$src")
  diff+=(--label "$src")
  diff+=("$src" "$dst")
  "${diff[@]}" &>/dev/null && return
  echo "generate patch: ${patch@Q}"
  "${diff[@]}" >"$patch" || :
}
copy() {
  local -i mode=444
  [[ -x $src ]] && mode=555
  LANG=C install -C -D -m $mode -v -T "$src" "$dst"
}
main() {
  local src dst
  for src; do
    [[ -f $src ]] || continue
    apt-install
    dst=$HOME/$src
    [[ -f $dst ]] && backup
    copy
  done
}

main "$@"
