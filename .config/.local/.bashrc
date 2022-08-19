#!/bin/bash

set +o ignoreeof
if command -v stty >/dev/null; then
  stty kill undef # unix-line-discard
  stty stop undef
  stty start undef
  stty werase undef # unix-word-rubout
  stty lnext $'\cQ'
fi

if command -v xbindkeys >/dev/null; then
  if ! pgrep -x xbindkeys >/dev/null; then
    xbindkeys
  fi
fi

(umask 0077; mkdir -p /tmp/"$USER"/Downloads)
