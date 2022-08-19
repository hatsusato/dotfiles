#!/bin/bash

set -eu

backup() {
  local src=$1 bak=$1.bak
  mv "$src" "$bak" &>/dev/null || return 0
  echo "'$src' => '$bak'"
}
prepare() {
  local dst=$1
  rmdir "$dst" &>/dev/null || return 0
  backup "$dst"
}
link() {
  local to=$1 from=$2
  [[ -h $from ]] || prepare "$from"
  ln -fnsv "$to" "$from"
}

apt='apt-get -qy'
mkdir='mkdir -p'
packages=()
packages+=(code google-chrome-stable slack-desktop)
packages+=(linux-image-surface linux-headers-surface iptsd libwacom-surface)

link {Private,"$HOME"}/.password-store
link {Dropbox,"$HOME"}/Documents
link {/tmp/"$USER","$HOME"}/Downloads
chmod 700 "$HOME"/.gnupg
$mkdir "$HOME"/.local/share/tig
im-config -n fcitx5
sudo dconf update
sudo $apt update
sudo $apt install "${packages[@]}"
sudo systemctl enable iptsd
sudo $apt install linux-surface-secureboot-mok
sudo update-grub
