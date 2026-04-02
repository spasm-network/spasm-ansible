#!/usr/bin/env bash
set -e
user="${1:-user}"
home=$(getent passwd "$user" | cut -d: -f6)
dir="$home/.ssh"
auth="$dir/authorized_keys"
if [ -d "$dir" ]; then
  echo "OK: $dir exists"
else
  echo "MISSING: $dir"; exit 2
fi
if [ -f "$auth" ]; then
  echo "OK: $auth exists, perms=$(stat -c %a "$auth") owner=$(stat -c %U "$auth")"
else
  echo "MISSING: $auth"; exit 2
fi
