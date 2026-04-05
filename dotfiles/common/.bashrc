#!/usr/bin/env bash

# Eval main.sh output to source modules
# Fail-safe: continue on error, do not exit
if [[ -f ~/.config/bash/main.sh ]]; then
	eval "$(source ~/.config/bash/main.sh)" || true
fi
