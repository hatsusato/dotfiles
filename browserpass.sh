#!/bin/bash

set -eu

repo=$1
remote=$(pass git remote get-url origin 2>/dev/null)
[[ $remote == $repo ]] || pass git remote add origin "$repo"
pass git fetch
pass git reset --hard origin/master
