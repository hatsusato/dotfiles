#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/apt-register
source "${BASH_SOURCE%/*}"/error

main() {
  local file=$1 pkg=google-chrome-stable
  "${BASH_SOURCE%/*}"/apt-installed.sh "$pkg" && exit
  sudo apt-get -qq install "$file" || error failed to install
  apt-register "$pkg"
}

main "$@"
