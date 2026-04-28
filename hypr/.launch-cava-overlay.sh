#!/usr/bin/env bash

set -euo pipefail

if pgrep -af "foot.*--app-id cava-overlay" >/dev/null; then
  exit 0
fi

exec foot \
  --config "$HOME/.config/foot/cava-overlay.ini" \
  --app-id cava-overlay \
  --title cava-overlay \
  --window-size-pixels=640x160 \
  cava
