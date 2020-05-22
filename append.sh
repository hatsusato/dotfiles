#!/bin/bash

set -eu

join() {
  if [[ -f $1 ]]; then
    cat "$1" | tr '\n' '\0'
  fi
}
grep -F -f <(join "$1") -q -z <(join "$2") && return
cat "$1" | tee -a "$2" >/dev/null
