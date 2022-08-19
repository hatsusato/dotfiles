#!/bin/bash

(
  umask 0077
  mkdir -p /tmp/"$USER"/Downloads
)
if command -v xbindkeys >/dev/null; then
  xbindkeys
fi
