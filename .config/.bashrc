set +o ignoreeof
if [ -x /usr/bin/stty ]; then
  stty kill undef # unix-line-discard
  stty stop undef
  stty start undef
  stty werase undef # unix-word-rubout
  stty lnext $'\cQ'
fi
if [ -x /usr/bin/xhost ]; then
  if xhost &>/dev/null; then
    [ -x /usr/bin/xkbset ] && xkbset nullify lock
  else
    export LANG LC_ALL
    LANG=C
    LC_ALL=C
  fi
fi
if [ -x /usr/bin/tput ]; then
  export PS1
  if tput setaf 1 &>/dev/null; then
    PS1='(\[\033[01;31m\]$?\[\033[00m\])'${PS1-}
  else
    PS1='($?)'${PS1-}
  fi
fi
if command -v gpg-agent-init >/dev/null; then
  eval $(gpg-agent-init)
fi

export LESS LESSHISTFILE LESSSECURE PASSWORD_STORE_GENERATED_LENGTH
LESS='-M -R -x4'
LESSHISTFILE=/dev/null
LESSSECURE=1
PASSWORD_STORE_GENERATED_LENGTH=32
