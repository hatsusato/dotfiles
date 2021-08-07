#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/error

prepare-log() {
  mkdir -p "${log%/*}"
  touch "$log"
  [[ -w $log ]] || error "file not writable: $log"
}
main() {
  local log=$HOME/.config/local/.install pkg
  prepare-log
  for pkg; do
    grep -qx "$pkg" "$log" && continue
    tee -a "$log" <<<"$pkg" >/dev/null
  done
}

main "$@"
