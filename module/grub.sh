#!/bin/bash

set -eu

main() {
  make /etc/default/grub
	sudo update-grub
}

main
