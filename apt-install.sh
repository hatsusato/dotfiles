#!/bin/bash

set -eu

todo=()
for pkg in "$@"; do
    dpkg --no-pager -l "$pkg" &>/dev/null && continue
    todo+=("$pkg")
done
((${#todo[@]})) && sudo apt-get install -qq "${todo[@]}"
