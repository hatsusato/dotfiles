#!/bin/bash

(
  umask 0077
  mkdir -p /tmp/"$USER"/Downloads
)
if command -v ensure-link >/dev/null; then
  ensure-link "$HOME"/{,Private/}.password-store
  ensure-link "$HOME"/{,.config/local/}.netrc
fi
if command -v xkb-monitor >/dev/null; then
  xkb-monitor || :
fi
