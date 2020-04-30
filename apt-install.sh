#!/bin/bash

set -eu

dpkg --no-pager -l "$1" &>/dev/null && exit
sudo apt-get install -qq "$1"
