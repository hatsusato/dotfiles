#!/bin/bash

error() {
  local -i err=$?
  ((err == 0)) && err=1
  cat <<EOF >&2
ERROR: $@
EOF
  [[ -t 2 ]] || notify-send -u critical ERROR "$*"
  exit $err
}
