#!/usr/bin/env bash

set -euo pipefail

log_file="/tmp/waybar-empty-workspace.log"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
socket_dir="${XDG_RUNTIME_DIR}/hypr/${HYPRLAND_INSTANCE_SIGNATURE}"
socket_path="$socket_dir/.socket2.sock"

printf '%s watcher start socket=%q signature=%q
' "$(date '+%F %T')" "$socket_path" "${HYPRLAND_INSTANCE_SIGNATURE:-}" >> "$log_file"

"$script_dir/toggle-waybar-empty-workspace.sh"

if [[ ! -S "$socket_path" ]]; then
  printf '%s watcher abort missing-socket
' "$(date '+%F %T')" >> "$log_file"
  exit 1
fi

socat -U - UNIX-CONNECT:"$socket_path" | while IFS= read -r event; do
  printf '%s watcher event=%q
' "$(date '+%F %T')" "$event" >> "$log_file"
  case "$event" in
    workspace*|focusedmon*|openwindow*|closewindow*|movewindow*|changefloatingmode*|pin*)
      "$script_dir/toggle-waybar-empty-workspace.sh"
      ;;
  esac
done
