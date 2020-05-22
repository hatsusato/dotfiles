#!/bin/bash

set -eu

installed() {
  [[ $1 == -* ]] && return
  dpkg -l --no-pager "$1" 2>/dev/null | grep -q ^ii
}
append() {
  [[ $1 == -* ]] && return
  local log=$HOME/.config/local/.install
  mkdir -p "${log%/*}"
  grep -xq "$1" "$log" 2>/dev/null && return
  echo "$1" >>"$log"
}
from-stdin() {
  local line
  while read -r line; do
    args+=("$line")
  done
}
filter() {
  local pkg
  args=()
  for pkg in "$@"; do
    installed "$pkg" && continue
    append "$pkg"
    args+=("$pkg")
  done
}

args=("$@")
[[ -t 0 ]] || from-stdin
filter "${args[@]}"
((${#args[@]})) && sudo apt install "${args[@]}"
