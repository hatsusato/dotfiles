#!/bin/bash

(
  umask 0077
  mkdir -p /tmp/"$USER"/Downloads
  mkdir -p "$HOME"/develop
  mkdir -p "$HOME"/Private
  mkdir -p "$HOME"/.config/google-chrome
)
if command -v ensure-link >/dev/null; then
  ensure-link {"$HOME"/,/tmp/"$USER"/}Downloads
  ensure-link "$HOME"/{,Dropbox/}Documents
  ensure-link "$HOME"/{,Private/}.password-store
  ensure-link "$HOME"/{,.config/local/}.bash_aliases
  ensure-link "$HOME"/{,.config/local/}.bash_completion
  ensure-link "$HOME"/{,.config/local/}.clang-format
  ensure-link "$HOME"/{,.config/local/}.inputrc
  ensure-link "$HOME"/{,.config/local/}.netrc
  ensure-link "$HOME"/{,.config/local/}.wgetrc
  ensure-link "$HOME"/.config/google-chrome/NativeMessagingHosts /etc/chromium/native-messaging-hosts
fi
if command -v xkb-monitor >/dev/null; then
  xkb-monitor || :
fi
