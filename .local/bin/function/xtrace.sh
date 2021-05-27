#!/bin/bash

xtrace() {
  local dir=/run/user/$UID/bin
  mkdir -m700 -p "$dir"
  set -x
  exec {BASH_XTRACEFD}>"$dir"/xtrace.log
}

xtrace
