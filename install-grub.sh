#!/bin/bash

set -eu

main() {
  local grub=etc/default/grub
  ./append.sh "$grub" /"$grub"
  sudo update-grub
}

main
