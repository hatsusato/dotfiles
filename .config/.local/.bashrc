#!/bin/bash

PS1='($?)'${PS1% }$'\n\$ '
if command -v tput >/dev/null; then
  if tput setaf 1 &>/dev/null; then
    PS1='(\[\033[01;31m\]$?\[\033[00m\])'${PS1#'($?)'}
  fi
fi

shopt -s globstar
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

if [[ -f "$HOME"/.local/share/bash-completion/completions/cd ]]; then
  complete -r cd
fi

mkdir -m 700 -p /tmp/"$USER"{,/Downloads}
