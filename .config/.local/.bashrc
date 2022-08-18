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
if [[ $(type -t check-enable-ssh-support) != function ]]; then
  check-enable-ssh-support() {
    command -v gpgconf >/dev/null || return
    local script='{if ($1 == "enable-ssh-support") print $10}'
    local enable=$(gpgconf --list-options gpg-agent | awk -F: "$script")
    ((${enable:-0}))
  }
  if check-enable-ssh-support; then
    unset -v SSH_AGENT_PID
    export SSH_AUTH_SOCK
    SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
  fi
  unset -f check-enable-ssh-support
fi
if command -v tmux-wrapper >/dev/null; then
  [ -v TMUX ] || [ -v INSIDE_EMACS ] || tmux-wrapper
fi

export LESS LESSHISTFILE PASSWORD_STORE_GENERATED_LENGTH
LESS='-M -R -x4'
LESSHISTFILE=/dev/null
PASSWORD_STORE_GENERATED_LENGTH=32
