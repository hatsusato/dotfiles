#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error

is-installed() {
  dpkg -l "$pkg" 2>/dev/null | tail -n+6 | grep -q ^ii
}
filter-pkgs() {
  local pkg
  pkgs=()
  for pkg; do
    is-installed "$pkg" && continue
    pkgs+=("$pkg")
  done
}
register-pkgs() {
  local pkg
  for pkg; do
    grep -qx "$pkg" "$log" && continue
    tee -a "$log" <<<"$pkg" >/dev/null
  done
}
main() {
  local log=$HOME/.config/local/.install
  local -a pkgs
  mkdir -p "${log%/*}"
  touch "$log"
  [[ -w $log ]] || error "file not writable: $log"
  filter-pkgs "${pkgs[@]}"
  ((${#pkgs[@]} == 0)) && return
  sudo apt-get -y install "${pkgs[@]}"
  register-pkgs "${pkgs[@]}"
}

main "$@"
