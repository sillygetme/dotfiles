#!/usr/bin/env bash

set -euo pipefail

log_file="/tmp/waybar-empty-workspace.log"
state_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-empty-hidden"
workspace_text="$(hyprctl activeworkspace 2>/dev/null || true)"
workspace_id="$(printf '%s
' "$workspace_text" | sed -n 's/^workspace ID \([-0-9]\+\).*/\1/p' | head -n1)"

printf '%s toggle start workspace_text=%q workspace_id=%q
' "$(date '+%F %T')" "$workspace_text" "$workspace_id" >> "$log_file"

if [[ -z "$workspace_id" ]]; then
  printf '%s toggle abort no-workspace-id
' "$(date '+%F %T')" >> "$log_file"
  exit 0
fi

clients_json="$(hyprctl clients -j 2>/dev/null || printf '[]')"
visible_count="$(printf '%s' "$clients_json" | jq --argjson ws "$workspace_id" '[.[] | select(.workspace.id == $ws)] | length' 2>/dev/null || printf '0')"

hidden=0
if [[ -f "$state_file" ]]; then
  hidden=1
fi

printf '%s toggle counts visible=%q hidden=%q
' "$(date '+%F %T')" "$visible_count" "$hidden" >> "$log_file"

if [[ "$visible_count" -eq 0 && "$hidden" -eq 0 ]]; then
  pkill -STOP -x waybar || true
  : > "$state_file"
  printf '%s toggle action=hide
' "$(date '+%F %T')" >> "$log_file"
elif [[ "$visible_count" -gt 0 && "$hidden" -eq 1 ]]; then
  pkill -CONT -x waybar || true
  rm -f "$state_file"
  printf '%s toggle action=show
' "$(date '+%F %T')" >> "$log_file"
else
  printf '%s toggle action=noop
' "$(date '+%F %T')" >> "$log_file"
fi
