#!/bin/bash

set -eu

clone-spacemacs() {
  local url=https://github.com/syl20bnr/spacemacs
  local target=$HOME/.emacs.d
  [[ -d $target/.git ]] && return
  git clone --branch develop "$url" "$target"
}
clone-private() {
  local url=https://github.com/hatsusato/private-layer
  local target=$HOME/.emacs.d/private/hatsusato
  [[ -d $target/.git ]] && return
  git clone "$url" "$target"
}
main() {
  clone-spacemacs
  clone-private
  [[ -f $HOME/.spacemacs ]] || emacs
}

main
