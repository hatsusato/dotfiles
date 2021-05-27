#!/bin/bash

error() {
  local -i err=$?
  ((err == 0)) && err=1
  cat <<EOF >&2
ERROR: $@
EOF
  exit $err
}
