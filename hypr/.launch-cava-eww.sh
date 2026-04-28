#!/usr/bin/env bash

set -euo pipefail

export EWW_CONFIG_DIR="$HOME/.config/eww"
FIFO=/tmp/cava.fifo
CACHE_DIR=/tmp/eww-cava
CACHE_FILE="$CACHE_DIR/current"
CAVA_CONFIG="$HOME/.config/cava/config-eww"
DISPATCHER="$HOME/.config/eww/scripts/cava-dispatch.sh"

pkill -f 'cava -p .*/config-eww' >/dev/null 2>&1 || true
pkill -f 'cava-dispatch.sh' >/dev/null 2>&1 || true

mkdir -p "$CACHE_DIR"
: > "$CACHE_FILE"
rm -f "$FIFO"
mkfifo "$FIFO"

"$DISPATCHER" >/dev/null 2>&1 &
sleep 0.2

eww daemon >/dev/null 2>&1 || true
eww open --force-wayland cava_overlay >/dev/null 2>&1 || true

exec cava -p "$CAVA_CONFIG"
