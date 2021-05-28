#!/bin/bash

if command -v mkdir-custom >/dev/null; then
  mkdir-custom -m700 -q /tmp/"$USER"/Downloads || :
  mkdir-custom -m700 -q "$HOME"/Private || :
fi
if command -v ensure-link >/dev/null; then
  ensure-link {"$HOME"/,/tmp/"$USER"/}Downloads || :
  ensure-link "$HOME"/{,Private/}.password-store || :
  ensure-link "$HOME"/{,Private/}.ssh || :
  ensure-link "$HOME"/{,.config/local/}.bash_aliases || :
  ensure-link "$HOME"/{,.config/local/}.bash_completion || :
  ensure-link "$HOME"/{,.config/local/}.clang-format || :
  ensure-link "$HOME"/{,.config/local/}.inputrc || :
  ensure-link "$HOME"/{,.config/local/}.netrc || :
  ensure-link "$HOME"/{,.config/local/}.wgetrc || :
  ensure-link "$HOME"/.config/google-chrome/NativeMessagingHosts \
              /etc/chromium/native-messaging-hosts || :
fi
if command -v xkb-monitor >/dev/null; then
  xkb-monitor || :
fi
