#!/bin/bash

(
  umask 0077
  mkdir -p /tmp/"$USER"/Downloads
  mkdir -p "$HOME"/develop
  mkdir -p "$HOME"/Private
  mkdir -p "$HOME"/.config/google-chrome
  ln -sf {"$HOME"/,/tmp/"$USER"/}Downloads
  ln -sf "$HOME"/{,Dropbox/}Documents
  ln -sf "$HOME"/{,Private/}.password-store
  ln -sf "$HOME"/{,.config/local/}.bash_aliases
  ln -sf "$HOME"/{,.config/local/}.bash_completion
  ln -sf "$HOME"/{,.config/local/}.clang-format
  ln -sf "$HOME"/{,.config/local/}.inputrc
  ln -sf "$HOME"/{,.config/local/}.netrc
  ln -sf "$HOME"/{,.config/local/}.wgetrc
  ln -sf "$HOME"/.config/google-chrome/NativeMessagingHosts /etc/chromium/native-messaging-hosts
)
if command -v xkb-monitor >/dev/null; then
  xkb-monitor || :
fi
