# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

if [ -f /etc/skel/.profile ]; then
    . /etc/skel/.profile
elif [ -f "$HOME/.config/.local/skel/.profile" ]; then
    . "$HOME/.config/.local/skel/.profile"
fi
if [ -f "$HOME/.config/.local/.profile" ]; then
    . "$HOME/.config/.local/.profile"
fi
