#!/bin/bash

(
  umask 0077
  mkdir -p /tmp/"$USER"/Downloads
  mkdir -p "$HOME"/.config/google-chrome
  mkdir -p "$HOME"/.config/google-chrome/NativeMessagingHosts
)
if command -v ensure-link >/dev/null; then
  ensure-link {"$HOME"/,/tmp/"$USER"/}Downloads
  ensure-link "$HOME"/{,Private/}.password-store
  ensure-link "$HOME"/{,.config/local/}.netrc
  ensure-link {"$HOME"/.config/google-chrome/NativeMessagingHosts/,/etc/chromium/native-messaging-hosts/}com.github.browserpass.native.json
fi
if command -v xkb-monitor >/dev/null; then
  xkb-monitor || :
fi
