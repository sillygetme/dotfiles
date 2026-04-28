#!/usr/bin/env bash

set -euo pipefail

colors_sh="$HOME/.cache/wal/colors.sh"
scss="$HOME/.config/eww/eww.scss"

if [[ ! -f "$colors_sh" ]]; then
  exit 0
fi

# shellcheck disable=SC1090
source "$colors_sh"

primary="${color12:-$foreground}"
shadow="${background:-#000000}"

cat > "$scss" <<STYLE
* {
  all: unset;
}

.cava-root {
  background-color: transparent;
  min-height: 160px;
  padding: 0 24px 18px 24px;
}

.cava-bars {
  color: ${primary};
  font-family: "Jetbrains mono";
  font-size: 16px;
  font-weight: 700;
  text-shadow: 0 0 8px ${shadow};
}
STYLE

eww reload >/dev/null 2>&1 || true
