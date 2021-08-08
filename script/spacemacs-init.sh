#!/bin/bash

set -eu

main() {
  [[ -f $HOME/.spacemacs ]] || emacs
}

main "$@"
