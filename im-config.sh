#!/bin/bash

set -eu

title=$(cat im-config/title)
body=$(cat im-config/body)
notify-send -u critical "$title" "$body"
im-config
