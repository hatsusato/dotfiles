# ~/.bashrc — Linux-specific shell configuration
# Sourced for interactive non-login shells.

# Source global definitions
[[ -f /etc/bashrc ]] && source /etc/bashrc

# Prompt
PS1='\u@\h:\w\$ '

# Aliases
alias ll='ls -la'
alias la='ls -A'
