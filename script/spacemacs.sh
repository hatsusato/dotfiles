#!/bin/bash

set -eu

main() {
  local target=$1
  local url=https://github.com/syl20bnr/spacemacs
  [[ -d $target/.git ]] && return
  git clone --branch develop "$url" "$target"
  "${BASH_SOURCE%/*}"/apt.sh emacs emacs-mozc
  [[ -f $HOME/.spacemacs ]] || emacs
}

main "$@"
