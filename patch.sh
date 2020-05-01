#!/bin/bash

set -eu

patch=${1#/}.patch
./expand.sh "$patch" | patch --dry-run -f -p0 -R -s "$1" >/dev/null && exit
./expand.sh "$patch" | sudo patch -b -f -p0 -Vt "$1"
