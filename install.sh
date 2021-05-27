#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/.local/bin/function/error.sh

usage() {
  cat <<EOF >&2
USAGE: ${0##*/} TARGET
    install file to TARGET, which must be full path
    install from \${TARGET#\$HOME/} if TARGET begins with \$HOME;
    from \${TARGET#/} otherwise
EOF
  exit 1
}
apt-comment() {
  grep '^#' "$src" | grep -m1 'apt:' | cut -d: -f2-
}
apt-install() {
  APT_OPTION=-qq .local/bin/apt-wrapper install $(apt-comment)
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
  local src=${1#$HOME} dst=$1
  src=${src#/}
  [[ $dst == /* ]] || error not full path: "$dst"
  [[ -f $src ]] || error source not found: "$src"
  [[ -f $dst ]] && backup
  [[ $src == .local/bin/* ]] && apt-install
  copy
}

(($# == 1)) || usage
main "$@"
