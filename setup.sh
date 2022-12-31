#!/bin/bash

set -eu

readonly pkgs=(
  build-essential clang 'fonts-noto*' git gocryptfs libterm-readkey-perl
  neovim paperkey scdaemon sshfs tig webext-browserpass xclip xkbset
)
readonly url=https://github.com/hatsusato/dotfiles.git
readonly log=$HOME/.config/.local/.install
readonly tmp=/tmp/$USER/dotfiles-XXXXXX

main() {
  mkdir -p "${log%/*}"
  touch "$log"
  sudo apt-get install -q "${pkgs[@]}"
  local pkg
  for pkg in "${pkgs[@]}"; do
    fgrep -qx "$pkg" "$log" &>/dev/null || echo "$pkg"
  done | tee -a "$log" >/dev/null
  umask 0077
  mkdir -p "${tmp%/*}"
  local dir=$(mktemp -d "$tmp")
  git clone "$url" "$dir"
  make -C "$dir"
}

main
