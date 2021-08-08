#!/bin/bash

set -eu
source "${BASH_SOURCE%/*}"/function/error

setup-dir() {
  [[ -d $dir && -w $dir ]] && return
  sudo mkdir -p "$dir"
  sudo chown $USER:$USER "$dir"
}
download() {
  [[ -f $file ]] && return
  wget --no-verbose --show-progress -O "$file" "$url"
}
main() {
  local file=$1 dir deb url
  dir=${file%/*}
  deb=${file##*/}
  url=https://dl.google.com/linux/direct/$deb
  setup-dir
  download || error failed to download
}

main "$@"
