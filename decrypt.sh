#!/bin/bash

set -eu

init() {
    cat <<EOF
YubiKey Initialization Instruction
gpg/card> fetch
gpg/card> quit
EOF
    until gpg-connect-agent -q 'scd serialno' /bye | grep -q ^OK; do
        read -n1 -p 'Insert YubiKey and Hit Any Key.' -s
        echo
    done
    gpg --card-edit
}
clip() {
    local wait_time=$1
    local uuid=56073f53-2dec-4232-a1ac-63f2d4c16e80
    local clipin='base64 -d | xclip -selection clipboard'
    local clipout='xclip -o -selection clipboard | base64'
    if pkill -f ^$uuid; then
        sleep 0.1
    fi
    local pass=$(base64)
    local before=$(eval $clipout)
    echo "$pass" | eval $clipin
    (
        (exec -a $uuid sleep $wait_time) &
        wait
        local now=$(eval $clipout)
        [[ $now == $pass ]] || return 0
        echo "$before" | eval $clipin
    ) &
}

export GNUPGHOME=/tmp/.gnupg
gpg -k YubiKey &>/dev/null || init
(($#)) || exit
content=$(gpg -d "$@" 2>/dev/null)
sed -n '1p' <<<$content | clip 15
sed -n '2,$p' <<<$content
