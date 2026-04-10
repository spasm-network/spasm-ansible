#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="${HOME:-/home/$(id -un)}"
LOG_FILE="$HOME_DIR/.local/share/podman-auto-start-spasm.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec >> "$LOG_FILE" 2>&1

compose_candidates=(docker-compose.yml docker-compose.yaml compose.yml compose.yaml)

# enable nullglob once
shopt -s nullglob

for base in "$HOME_DIR" "$HOME_DIR/apps"; do
  [ -d "$base" ] || continue
  for dir in "$base"/spasm-docker*; do
    [ -d "$dir" ] || continue

    found=""
    for cf in "${compose_candidates[@]}"; do
      if [ -f "$dir/$cf" ]; then
        found="$cf"
        break
      fi
    done
    [ -n "$found" ] || continue

    if ! (cd "$dir" && \
          echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Starting $dir with $found" && \
          /usr/bin/podman compose -f "$found" up -d); then
      echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR: podman compose failed in $dir"
    fi
  done
done

shopt -u nullglob
