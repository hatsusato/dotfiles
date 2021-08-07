#!/bin/bash

set -eu

message() {
  cat <<EOF
1. OK
2. YES
3. [x] fcitx -> OK
4. OK
EOF
}
main() {
  local msg=$(message) title='im-config instructions'
  notify-send -u critical "$title" "$msg"
}

main
