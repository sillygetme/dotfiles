#!/usr/bin/env bash

set -euo pipefail

colors_sh="$HOME/.cache/wal/colors.sh"
bars_glsl="$HOME/.config/glava/bars.glsl"
launcher="$HOME/.config/hypr/launch-glava.sh"

if [[ ! -f "$colors_sh" || ! -f "$bars_glsl" ]]; then
  exit 0
fi

# shellcheck disable=SC1090
source "$colors_sh"

primary="${color12#\#}"

sed -i \
  -e "s/^#define COLOR (.*/#define COLOR (#${primary} * GRADIENT)/" \
  "$bars_glsl"

if pgrep -x glava >/dev/null 2>&1 && [[ -x "$launcher" ]]; then
  "$launcher" >/dev/null 2>&1 &
fi
