#!/bin/bash

set -eu

dst=$1
src=${1#/}.patch
cat "$src" | patch --dry-run -f -p0 -R -s "$dst" >/dev/null && exit
cat "$src" | sudo patch -b -f -p0 -Vt "$dst"
