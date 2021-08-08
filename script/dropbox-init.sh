#!/bin/bash

set -eu

main() {
  dropbox start -i
  dropbox status
  dropbox status | grep -Fqx '最新の状態'
}

main "$@"
