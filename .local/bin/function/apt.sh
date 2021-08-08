#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/apt-installed-all
source "${BASH_SOURCE%/*}"/apt-register

main() {
  local pkg
  local -a pkgs=()
  for pkg; do
    apt-installed-all "$pkg" || pkgs+=("$pkg")
  done
  ((${#pkgs[@]} == 0)) && return
  sudo apt-get -y install "${pkgs[@]}"
  apt-register "${pkgs[@]}"
}

main "$@"
