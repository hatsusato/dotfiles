#!/bin/bash

set -eu

source "${BASH_SOURCE%/*}"/run-user.sh

yubikey-aid() {
  local pattern='match($1, /^Reader$/) {print $7}'
  AID=$(gpg --card-status --with-colons 2>/dev/null | awk -F: "$pattern")
  [[ -n $AID ]]
}
yubikey-id() {
  local line IFS=:
  while read line; do
    set -- $line
    case $1 in
      sec) KEYID=$5;;
      ssb) [[ ${15} == $AID ]] && return;;
    esac
  done < <(gpg --list-secret-keys --with-colons)
  KEYID=
  return 1
}
yubikey-init() {
  export GNUPGHOME=$(run-user yubikey .gnupg)
  until yubikey-aid; do
    read -n1 -p 'Insert YubiKey and Hit Any Key.' -s
    echo
  done >&2
  until yubikey-id; do
    gpg --batch --command-fd 0 --card-edit <<<$'fetch\nquit\n'
  done >&2 2> >(grep ^gpg:)
}
