#!/bin/bash

set -eu

dpkg --no-pager -l "$1" 2>/dev/null | grep -q '^ii' && exit
((1 < $#)) && shift
sudo apt install -qq "$1"
