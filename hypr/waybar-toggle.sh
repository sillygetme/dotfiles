#!/usr/bin/env bash

self=$$
found=""

while read -r pid cmd; do
  [ "$pid" = "$self" ] && continue
  found=1
  kill "$pid"
done < <(pgrep -af '(^|/)(waybar)( |$)' | awk '{pid=$1; $1=""; sub(/^ /,""); print pid "\t" $0}')

if [ -z "$found" ]; then
  nohup waybar >/dev/null 2>&1 &
fi
