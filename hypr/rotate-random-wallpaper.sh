#!/usr/bin/env bash
set -euo pipefail

INTERVAL="${INTERVAL:-3600}"
INITIAL_DELAY="${INITIAL_DELAY:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$INITIAL_DELAY" -gt 0 ] 2>/dev/null; then
  sleep "$INITIAL_DELAY"
fi

while true; do
  if [ -f "$SCRIPT_DIR/switch-random-wallpaper.sh" ]; then
    if ! bash "$SCRIPT_DIR/switch-random-wallpaper.sh"; then
      exit 1
    fi
  else
    echo "error: missing $SCRIPT_DIR/switch-random-wallpaper.sh" >&2
    exit 1
  fi

  sleep "$INTERVAL"
done
