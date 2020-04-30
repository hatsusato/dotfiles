#!/bin/bash

set -eu

readonly dir=/usr/local/src/$USER
readonly deb=google-chrome-stable_current_amd64.deb
readonly url=https://dl.google.com/linux/direct/$deb
readonly path=$dir/$deb
readonly pkg=${deb%%_*}

[[ -d $dir ]] || sudo install -o "$USER" -g "$USER" -d "$dir"
wget -c -nv -O "$path" "$url"
dpkg --no-pager -l "$pkg" &>/dev/null && exit
sudo apt-get install -qq "$path"
