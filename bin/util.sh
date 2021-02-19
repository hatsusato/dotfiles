#!/bin/bash

readonly top_dir=${BASH_SOURCE%/*}

error() {
  echo "$@" >&2
  exit 1
}
