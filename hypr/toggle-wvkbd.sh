#!/usr/bin/env bash
set -euo pipefail

source "$HOME/.config/hypr/wvkbd.conf"

if pgrep -x "$WV_KBD_BIN" >/dev/null 2>&1; then
    pkill -RTMIN -x "$WV_KBD_BIN"
    exit 0
fi

exec "$WV_KBD_BIN" \
    -H "$WV_KBD_HEIGHT" \
    -L "$WV_KBD_LANDSCAPE_HEIGHT" \
    -R "$WV_KBD_RADIUS" \
    --fn "$WV_KBD_FONT" \
    -l "$WV_KBD_LAYERS" \
    --landscape-layers "$WV_KBD_LANDSCAPE_LAYERS"
