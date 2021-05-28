#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error.sh

apt-install() {
  local pkgs=$(grep '^#' "$src" | grep -m1 'apt:' | cut -d: -f2-)
  ./apt-install.sh $pkgs
}
backup() {
  local patch=${src##*/}.patch
  local -a diff=(diff -u)
  diff+=(--label "$src")
  diff+=(--label "$src")
  diff+=("$src" "$dst")
  [[ $src -nt $dst ]] && return
  "${diff[@]}" &>/dev/null && return
  echo "generate patch: ${patch@Q}"
  "${diff[@]}" >"$patch" || :
}
copy() {
  local -a sudo=(sudo) install=(install -D -v -T)
  if [[ $dst == $HOME/* ]]; then
    sudo=()
    if [[ -x $src ]]; then
      install+=(-m 555)
    else
      install+=(-m 444)
    fi
  fi
  LANG=C ${sudo[@]} "${install[@]}" "$src" "$dst"
}
main() {
  (($# == 2)) || return
  local src=$1 dst=$2
  [[ $dst == /* ]] || error not full path: "$dst"
  [[ -f $src ]] || error source not found: "$src"
  [[ -f $dst ]] && backup
  [[ $src == .local/bin/* ]] && apt-install
  copy
}

main "$@"
