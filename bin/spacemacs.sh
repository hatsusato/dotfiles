#!/bin/bash

spacemacs-exists () {
  timeout 1s emacsclient -a false -e t &>/dev/null
}
resolve-hup() {
  local err=0
  spacemacs-exists || err=$?
  ((err == 124)) || return 0
  notify-send -u critical -i emacs spacemacs-daemon 'HUNG-UP DETECTED!'
  pkill -9 -f 'spacemacs --daemon' || return 0
}
