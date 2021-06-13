#!/bin/bash

set -eu

main() {
  make /etc/dconf/profile/user
  make "$HOME"/.config/dconf/user.txt
	sudo dconf update
}

main
