#!/bin/bash

set -eu

script=
while read var; do
    if [[ -n $var && -n ${!var+x} ]]; then
        script+="s/\${$var}/${!var}/g;"
    else
        echo "$0: \${$var}: unbound variable" >&2
        exit 1
    fi
done < <(grep -o '${[A-Z_]*}' "$1" | tr -d '${}' | sort -u)
sed -e "$script" "$1"
