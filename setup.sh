#!/bin/bash

set -eu

setup-pkgs() {
  pkgs+=(
    build-essential clang emacs emacs-mozc fcitx fcitx-mozc 'fonts-noto*'
    git gocryptfs libx11-dev neovim paperkey pass pwgen scdaemon sshfs
    webext-browserpass xclip xkbset
  )
  log=$HOME/.config/local/.install
  mkdir -p "${log%/*}"
  touch "$log"
}
register-pkgs() {
  local pkg
  for pkg; do
    grep -qx "$pkg" "$log" &>/dev/null && continue
    tee -a "$log" <<<"$pkg" >/dev/null
  done
}
install-pkgs() {
  local -a pkgs
  local log
  setup-pkgs
  sudo apt-get install -q "${pkgs[@]}"
  register-pkgs "${pkgs[@]}"
}
setup-tmpdir() {
  local dir=/tmp/$USER
  umask 0077
  mkdir -p "$dir"
  mktemp -d "$dir"/dotfiles-XXXXXX
}
download-zip() {
  local url
  url=https://github.com/hatsusato/dotfiles/archive/refs/heads/master.zip
  dst=$dir/${url##*/}
  wget --no-verbose --show-progress -O "$dst" "$url"
}
setup-zip() {
  local dst
  dir=$(setup-tmpdir)
  download-zip
  unzip -q "$dst" -d "$dir"
  dir+=/dotfiles-master
}
remove-done() {
  local -a todo
  local cmd
  for cmd in ${cmds[@]}; do
    [[ $cmd == $1 ]] || todo+=($cmd)
  done
  cmds=(${todo[@]})
}
prompt() {
  local var
  select var in ${cmds[@]}; do
    if [[ -n $var ]]; then
      remove-done $var
      target=$var
      return
    fi
  done
  return 1
}
main() {
  local dir target
  local -a cmds=(chrome dconf dropbox grub im-config spacemacs)
  install-pkgs
  setup-zip
  make -C "$dir" all
  while prompt; do
    make -C "$dir" install/$target
  done
}

main
