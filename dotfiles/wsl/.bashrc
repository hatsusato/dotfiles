# ~/.bashrc — WSL-specific shell configuration
# Sourced for interactive non-login shells.

# Source global definitions
[[ -f /etc/bashrc ]] && source /etc/bashrc

# Prompt (indicates WSL context)
PS1='[WSL] \u@\h:\w\$ '

# Aliases
alias ll='ls -la'
alias la='ls -A'

# Windows interop: add Windows tools to PATH selectively
# export PATH="$PATH:/mnt/c/Windows/System32"
