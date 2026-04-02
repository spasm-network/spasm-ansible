#!/usr/bin/env bash
set -e
users=("${1:-user}" "${2:-admin}")
for u in "${users[@]}"; do
  if getent passwd "$u" > /dev/null; then
    home=$(getent passwd "$u" | cut -d: -f6)
    echo "OK: user $u exists, home=$home"
  else
    echo "MISSING: user $u"
    exit 2
  fi
done
