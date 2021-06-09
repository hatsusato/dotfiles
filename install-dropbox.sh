#!/bin/bash

set -eu

install-dropbox() {
  dpkg -l nautilus-dropbox 2>/dev/null | grep -q ^ii && return
  sudo apt-get install -qq nautilus-dropbox
}
main() {
  install-dropbox
  dropbox start -i
  dropbox status
  dropbox status | grep -Fqx '最新の状態'
}

main
