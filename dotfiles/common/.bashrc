#!/usr/bin/env bash

# Eval main.sh output to source modules
# This pattern isolates main.sh's loop variables to a subshell,
# preventing variable leakage into the .bashrc namespace
if [[ -f ~/.config/bash/main.sh ]]; then
	eval "$(~/.config/bash/main.sh)" || exit 1
fi
