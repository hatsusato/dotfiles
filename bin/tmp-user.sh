#!/bin/bash

set -eu

tmp-user() {
    local dir=/tmp/$USER
    mkdir -m700 -p "$dir"
    (($#)) && dir+=/$1
    echo "$dir"
}
