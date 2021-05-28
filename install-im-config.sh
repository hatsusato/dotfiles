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
  ./apt-install.sh fcitx fcitx-mozc
  notify-send -u critical "$title" "$msg"
  im-config &>/dev/null &
}

main
