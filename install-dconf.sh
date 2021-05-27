#!/bin/bash

set -eu

install-etc() {
  local etc=/etc/dconf/profile/user
  [[ -f $etc ]] || ./install.sh "$etc"
}
main() {
  local src dst
  src=.config/dconf/user.txt
  dst=$HOME/$src
  install-etc
  [[ -f $src && -f $dst ]] || return
  [[ -f $dst-lock ]] || sudo dconf update
}

main
