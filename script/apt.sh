#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error

is-installed() {
  dpkg -l "$pkg" 2>/dev/null | tail -n+6 | grep -q ^ii
}
main() {
  local pkg
  local -a pkgs=()
  for pkg; do
    "${BASH_SOURCE%/*}"/apt-installed.sh "$pkg" && continue
    pkgs+=("$pkg")
  done
  ((${#pkgs[@]} == 0)) && return
  sudo apt-get -y install "${pkgs[@]}"
  "${BASH_SOURCE%/*}"/apt-register.sh "${pkgs[@]}"
}

main "$@"
