#!/bin/bash
# conf.d/05-path.sh — Core user PATH configuration
# Prepends user-local directories to PATH for pip, user scripts, and Rust tools

# .cargo/bin (Rust toolchain via rustup) - added first so it appears last in precedence
[[ -d ~/.cargo/bin ]] && PATH="$HOME/.cargo/bin:$PATH"

# ~/bin (user's custom shell scripts) - added second
[[ -d ~/bin ]] && PATH="$HOME/bin:$PATH"

# .local/bin (Python pip packages, user-installed tools) - added last so it appears first in precedence
[[ -d ~/.local/bin ]] && PATH="$HOME/.local/bin:$PATH"

export PATH
