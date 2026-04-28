#!/usr/bin/env bash
set -euo pipefail

PLUGIN_PATH="/run/current-system/sw/lib/libhyprgrass.so"
CONFIG_PATH="$HOME/.config/hypr/touchscreen.conf"

if ! hyprctl plugin list 2>/dev/null | rg -q 'hyprgrass'; then
    hyprctl plugin load "$PLUGIN_PATH"
fi

hyprctl keyword source "$CONFIG_PATH"
