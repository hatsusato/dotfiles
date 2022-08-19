#!/bin/bash

if [[ ! -v DISPLAY ]]; then
  export LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8
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
