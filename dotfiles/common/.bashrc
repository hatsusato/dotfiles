#!/usr/bin/env bash

# Eval main.sh output to source modules
# Fail-safe: continue on error, do not exit
[[ -f ~/.config/bash/main.sh ]] && eval "$(source ~/.config/bash/main.sh)" || true
