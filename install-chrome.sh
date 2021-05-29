#!/bin/bash

set -eu

download() {
  mkdir -m700 -p "${file%/*}"
  wget --no-verbose --show-progress -O "$file" "$url" || exit
}
main() {
  local deb url file
  deb=google-chrome-stable_current_amd64.deb
  url=https://dl.google.com/linux/direct/$deb
  file=/usr/local/src/$USER/$deb
  [[ -f $file ]] || download
  ./install-apt.sh "$file"
}

main
