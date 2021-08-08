#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/function/apt-is-installed
source "${BASH_SOURCE%/*}"/function/apt-register
source "${BASH_SOURCE%/*}"/function/error

main() {
  local file=$1 pkg=google-chrome-stable
  apt-is-installed "$pkg" && exit
  sudo apt-get -qq install "$file" || error failed to install
  apt-register "$pkg"
}

main "$@"