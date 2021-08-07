#!/bin/bash

set -eu

main() {
  dpkg -l "$@" 2>/dev/null | tail -n+6 | grep -q ^ii
}

main "$@"
