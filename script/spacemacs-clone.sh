#!/bin/bash

set -eu

main() {
  local target=$HOME/.emacs.d
  local url=https://github.com/syl20bnr/spacemacs
  [[ -d $target/.git ]] && return
  git clone --branch develop "$url" "$target"
}

main "$@"
