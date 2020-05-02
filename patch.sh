#!/bin/bash

set -eu

patch=${1#$HOME}
patch=${patch#/}.patch
expand() {
    local script= var
    while read var; do
        if [[ -n $var && -n ${!var+x} ]]; then
            script+="s/\${$var}/${!var}/g;"
        else
            echo "$0: \${$var}: unbound variable" >&2
            exit 1
        fi
    done < <(grep -o '${[A-Z_]*}' "$1" | tr -d '${}' | sort -u)
    sed -e "$script" "$patch"
}

expand | patch --dry-run -f -p0 -R -s "$1" >/dev/null && exit
if [[ -w "$1" ]]; then
    patch -b -f -p0 -Vt "$1"
else
    sudo patch -b -f -p0 -Vt "$1"
fi < <(expand)
