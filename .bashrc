# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

if [ -f /etc/skel/.bashrc ]; then
    . /etc/skel/.bashrc
elif [ -f ~/.config/.local/skel/.bashrc ]; then
    . ~/.config/.local/skel/.bashrc
fi
if [ -f ~/.config/.local/.bash_aliases ]; then
    . ~/.config/.local/.bash_aliases
fi
if [ -f ~/.config/.local/bash-completion/.bash_completion ]; then
    . ~/.config/.local/bash-completion/.bash_completion
fi
if [ -f ~/.config/.local/.bashrc ]; then
    . ~/.config/.local/.bashrc
fi
