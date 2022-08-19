#!/bin/bash

if command -v xhost >/dev/null; then
  if ! xhost &>/dev/null; then
    export LANG=C LANGUAGE=C LC_ALL=C
  fi
fi

if command -v gpg-agent-ssh-socket >/dev/null; then
  if gpg-agent-ssh-socket >/dev/null; then
    unset -v SSH_AGENT_PID
    export SSH_AUTH_SOCK=$(gpg-agent-ssh-socket)
  fi
fi

export LESS='-M -R -x4'
export LESSHISTFILE=/dev/null

export PASSWORD_STORE_GENERATED_LENGTH=32
