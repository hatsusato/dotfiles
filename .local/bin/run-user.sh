#!/bin/bash

run-user() {
  local arg dir=${XDG_RUNTIIME_DIR-/run/user/$UID}
  dir+=/bin
  mkdir -m700 -p "$dir"
  for arg in "$@"; do
    mkdir -m700 -p "$dir"
    dir+=/$arg
  done
  echo "$dir"
}
set-lock() {
  local lock=$(run-user "$@" lock)
  declare -g LOCK_DIR=$lock
}
get-lock() {
  mkdir -m700 "$LOCK_DIR" 2>/dev/null
}
clear-lock() {
  rm -fr "$LOCK_DIR"
}
