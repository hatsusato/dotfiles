#!/bin/bash

set -eu

notify() {
  if [[ -t 2 ]]; then
    echo "$1" >&2
  else
    notify-send -i emacs emacs-daemon "$1"
  fi
}
exists-daemon() {
  local err=0
  timeout 1s emacsclient -a false -e t &>/dev/null || err=$?
  if ((err == 124)); then
    notify 'ERROR: no response from spacemacs-daemon'
    exit $err
  else
    return $err
  fi
}
