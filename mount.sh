#!/bin/bash

set -eu


awk '{print $1,$2}' /etc/mtab | grep -Fqx "$*" && return
gocryptfs "$@"
