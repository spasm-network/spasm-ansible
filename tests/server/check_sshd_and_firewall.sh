#!/usr/bin/env bash
set -e
port="${1:-22}"
ss_out=$(ss -ltnp 2>/dev/null || true)
if echo "$ss_out" | grep -q ":$port "; then
  echo "OK: listening on tcp port $port"
else
  echo "NOT LISTENING on port $port"
fi
if command -v ufw >/dev/null 2>&1; then
  echo "UFW status:"
  ufw status verbose || true
else
  echo "UFW not installed"
fi
if systemctl is-active --quiet fail2ban; then
  echo "OK: fail2ban active"
else
  echo "fail2ban not active"
fi
