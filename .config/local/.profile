#!/bin/bash

(
  umask 0077
  mkdir -p /tmp/"$USER"/Downloads
)
if command -v xkb-monitor >/dev/null; then
  xkb-monitor || :
fi
