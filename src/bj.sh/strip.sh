#!/usr/bin/env bash

grep -Ev '^\s*$|^\s\s*#|^\s*:\s' "$1" \
  | sed 's/\s\s*#.*//' \
  > "${2:-/dev/stdout}"
