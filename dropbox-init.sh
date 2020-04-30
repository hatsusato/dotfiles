#!/bin/bash

set -eu

readonly msg='最新の状態'
dropbox start 2>/dev/null
status=$(dropbox status)
[[ $status == $msg ]]
